# frozen_string_literal: true

module Tessella
    # fill: a pattern in a figure's enclosed blank cells (DESIGN.md,
    # "Blocks and composition"). A blank cell reachable from the
    # figure's edge through blank cells is outside and stays blank;
    # every other blank cell -- inside a frame, a box, any closed
    # region -- takes the pattern, its glyphs tiled diagonally. Text
    # and lines are never touched, and a halo of blank cells keeps the
    # pattern off text (a glyph that is neither box drawing nor + - |):
    # halo: true leaves the cell each side blank, :around the cells
    # above and below too, false none. The pattern is a name from
    # Glyphs::PATTERNS (light, hatch, stipple, ...) or glyphs of one's
    # own, each one visible column and all of one width class; under
    # ascii: true it must be ASCII (colons by default). frame(fill:)
    # fills only the background the frame adds: what floods in from
    # just inside its border, never a region the content encloses.
    module Compose
        FILL = :light
        ASCII_FILL = :colons

        HALOS = [true, false, :around].freeze
        STRUCTURE = /[\u2500-\u257F+|-]/

        def self.fill(figure, pattern: nil, ascii: Target.ascii?, halo: true)
            block, = blocks([figure], ascii)
            glyphs = pattern_glyphs!(pattern, ascii)
            grid, codes = cell_grid(block)
            inside = haloed(grid, enclosed(grid), halo)
            Block.new(paint(grid, codes, inside, glyphs))
        end

        # The background a frame adds to a block it has just framed.
        def self.fill_frame(framed, pattern, ascii, halo)
            glyphs = pattern_glyphs!(pattern, ascii)
            grid, codes = cell_grid(framed)
            region = flood(grid, inner_ring(grid))
            Block.new(paint(grid, codes, haloed(grid, region, halo), glyphs))
        end

        # The blank cells just inside a frame's border.
        def self.inner_ring(grid)
            last_r = grid.size - 2
            last_c = grid.first.size - 2
            ring = (1..last_r).flat_map { |r| [[r, 1], [r, last_c]] } +
                   (1..last_c).flat_map { |c| [[1, c], [last_r, c]] }
            ring.select { |r, c| grid[r][c] == " " }
        end

        def self.pattern_glyphs!(pattern, ascii)
            name = pattern || (ascii ? ASCII_FILL : FILL)
            glyphs = pattern_text(name).chars
            glyphs.each { glyph!(it, "pattern glyph", ascii) }
            classes = Width.classes(glyphs.join)
            return glyphs if classes.size <= 1

            raise ArgumentError, "pattern #{name.inspect} mixes width " \
                                 "classes: #{classes.join(", ")}"
        end

        # A name in Glyphs::PATTERNS, else the glyphs themselves.
        def self.pattern_text(name)
            key = Borders.name(name)
            return Glyphs::PATTERNS[key] if Glyphs::PATTERNS.key?(key)
            raise ArgumentError, "empty pattern" if name.to_s.empty?

            name.to_s
        end

        SGR = /\e\[[0-9;]*m/
        TOKEN = /(?:#{SGR})*(?:\X|\z)/o

        # The block as rows of one-column cells, a wide glyph (a grapheme
        # cluster, an emoji sequence or an accented letter whole) and an
        # empty tail cell after it, every row the block's width; and
        # the colour codes before each cell ({ [r, c] => codes }, a
        # row's trailing ones at [r, :end]), set aside so a coloured
        # block is measured and filled by what it shows.
        def self.cell_grid(block)
            codes = {}
            grid = block.lines.each_with_index.map do |line, r|
                cells = row_cells(line, r, codes)
                cells + Array.new(block.width - cells.size, " ")
            end
            [grid, codes]
        end

        def self.row_cells(line, r, codes)
            line.scan(TOKEN).each_with_object([]) do |token, cells|
                lead = token[/\A(?:#{SGR})*/o]
                glyph = token.delete_prefix(lead)
                next codes[[r, :end]] = lead if glyph.empty?

                codes[[r, cells.size]] = lead unless lead.empty?
                cells << glyph
                cells.concat(Array.new([Width.cluster(glyph) - 1, 0].max, ""))
            end
        end

        # The blank cells not reachable from the edge: { [r, c] => true }.
        def self.enclosed(grid)
            outside = flood(grid)
            grid.each_with_index.with_object({}) do |(row, r), inside|
                row.each_index do |c|
                    inside[[r, c]] = true if row[c] == " " && !outside[[r, c]]
                end
            end
        end

        def self.flood(grid, starts = edge_blanks(grid))
            seen = {}
            todo = starts.dup
            until todo.empty?
                r, c = todo.pop
                next if seen[[r, c]]

                seen[[r, c]] = true
                todo.concat(blank_neighbours(grid, r, c))
            end
            seen
        end

        def self.edge_blanks(grid)
            last_r = grid.size - 1
            last_c = (grid.first&.size || 0) - 1
            cells = grid.each_index.flat_map { |r| [[r, 0], [r, last_c]] } +
                    (0..last_c).flat_map { |c| [[0, c], [last_r, c]] }
            cells.select { |r, c| grid[r][c] == " " }
        end

        def self.blank_neighbours(grid, r, c)
            [[r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]].select do |y, x|
                y.between?(0, grid.size - 1) &&
                    x.between?(0, grid[y].size - 1) && grid[y][x] == " "
            end
        end
    end

    # The halo: blank cells fill keeps beside text, so a label keeps
    # its word shape. Text is any glyph but box drawing and + - |.
    module Compose
        # The region less the cells a halo keeps blank around text.
        def self.haloed(grid, region, halo)
            unless HALOS.include?(halo)
                raise ArgumentError, "halo must be true, false or :around: " \
                                     "#{halo.inspect}"
            end
            return region unless halo

            region.reject { |(r, c), _| near_text?(grid, r, c, halo) }
        end

        def self.near_text?(grid, r, c, halo)
            near = [[r, c - 1], [r, c + 1]]
            near += [[r - 1, c], [r + 1, c]] if halo == :around
            near.any? { |y, x| text_cell?(grid, y, x) }
        end

        def self.text_cell?(grid, r, c)
            cell = r.between?(0, grid.size - 1) && c >= 0 && grid[r][c]
            cell && !["", " "].include?(cell) && !cell.match?(STRUCTURE)
        end

        def self.paint(grid, codes, inside, glyphs)
            grid.each_with_index.map do |row, r|
                painted = row.each_with_index.map do |cell, c|
                    fill = glyphs[(r + c) % glyphs.size]
                    "#{codes[[r, c]]}#{inside[[r, c]] ? fill : cell}"
                end
                painted.join + codes[[r, :end]].to_s
            end
        end
    end

    def self.fill(...) = Compose.fill(...)
end
