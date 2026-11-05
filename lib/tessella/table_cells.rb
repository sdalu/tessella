# frozen_string_literal: true

module Tessella
    module Table
        # Cells as lines (DESIGN.md, "Diagram modules"): a cell's "\n"
        # splits it into lines within its row, and every cell of a row
        # is padded with empty lines to the row's tallest, top-aligned.
        module Cells
            def self.lines(cell)
                lines = Table.sanitize(cell.to_s).split("\n", -1)
                lines.empty? ? [""] : lines
            end

            def self.grid(rows) = rows.map { |row| row.map { lines(it) } }

            def self.multiline?(grid) = grid.any? { |r| r.any? { it.size > 1 } }

            def self.width(cell_lines) = cell_lines.map { Width.of(it) }.max

            # One row of cells (each an Array of lines) as Arrays of
            # line strings, one Array per output line.
            def self.rows_of(row)
                height = row.map(&:size).max
                (0...height).map { |i| row.map { it[i] || "" } }
            end

            BOLD = "\e[1m"
            RESET = "\e[0m"

            def self.bold(cell_lines)
                cell_lines.map { it.empty? ? it : "#{BOLD}#{it}#{RESET}" }
            end

            # The header row in bold when colour is on.
            def self.header(row, color)
                color && row ? row.map { bold(it) } : row
            end

            def self.column_widths(grid)
                grid.transpose.map { |col| col.map { width(it) }.max + 2 }
            end

            def self.check_markdown!(head, body, fit)
                return unless fit[:width] ||
                              multiline?(grid([head, *body].compact))

                raise ArgumentError,
                      "markdown has no multi-line cells and no width: fitting"
            end
        end

        # Fitting a width (width:, min_width:): when the framed table is
        # wider than width, the widest column narrows by the overflow
        # and its cells wrap to it; below min_width columns of text it
        # is refused, naming the width the table needs at the least.
        module Fit
            def self.apply(grid, widths, width, min_width)
                total = Render.span_width(widths) + 2
                return [grid, widths] if width.nil? || total <= width

                narrow(grid, widths, total - width, min_width)
            end

            # Over columns come off the widest column still above its
            # floor, one at a time, so widths converge downwards and a
            # narrow column is never narrowed first. A column's floor is
            # min_width, or its natural width when that is smaller; the
            # table is refused only when every column is at its floor.
            def self.narrow(grid, widths, over, min_width)
                texts = widths.map { it - 2 }
                floors = texts.map { [it, min_width].min }
                target = texts.sum - over
                check_room!(floors, target, min_width)
                fitted = level(texts, floors, target)
                [grid.map { wrap_columns(it, texts, fitted) },
                 fitted.map { it + 2 }]
            end

            def self.level(texts, floors, target)
                fitted = texts.dup
                while fitted.sum > target
                    i = fitted.each_index.select { fitted[it] > floors[it] }
                              .max_by { fitted[it] }
                    fitted[i] -= 1
                end
                fitted
            end

            def self.check_room!(floors, target, min_width)
                return if floors.sum <= target

                least = Render.span_width(floors.map { it + 2 }) + 2
                raise ArgumentError, "table needs #{least} columns at the " \
                                     "least (min_width #{min_width})"
            end

            # Every narrowed column's cells wrapped to its new width.
            def self.wrap_columns(row, texts, fitted)
                row.each_with_index.map do |cell, i|
                    next cell if fitted[i] == texts[i]

                    cell.flat_map { Wrap.line(it, fitted[i]) }
                end
            end
        end

        # Word wrap by display width, ANSI colour kept intact: a word
        # longer than the column breaks inside, and a colour still open
        # at a line's end is closed there and reopened on the next line,
        # so every line stands alone.
        module Wrap
            SGR = /\e\[[0-9;]*m/
            RESETS = ["\e[0m", "\e[m"].freeze

            def self.line(text, cols)
                return [text] if Width.of(text) <= cols

                recolour(pack(words(text, cols), cols))
            end

            def self.words(text, cols)
                text.split.flat_map do |word|
                    Width.of(word) > cols ? chop(word, cols) : [word]
                end
            end

            # A word too long for the column, in pieces of cols columns;
            # an SGR sequence stays whole, attached to the next glyph.
            def self.chop(word, cols)
                glyphs = word.scan(/(?:#{SGR})*(?:.(?:#{SGR})*)/o)
                glyphs.each_with_object([+""]) do |g, out|
                    Width.of(out.last + g) > cols ? out << g.dup : out.last << g
                end
            end

            def self.pack(words, cols)
                words.each_with_object([]) do |w, out|
                    if out.any? && Width.of("#{out.last} #{w}") <= cols
                        out.last << " " << w
                    else
                        out << w.dup
                    end
                end
            end

            def self.recolour(lines)
                open = []
                lines.map do |l|
                    text = open.join + l
                    open = active(text)
                    open.empty? ? text : text + Cells::RESET
                end
            end

            # The SGR sequences still in effect at the end of text.
            def self.active(text)
                text.scan(SGR).each_with_object([]) do |seq, on|
                    RESETS.include?(seq) ? on.clear : on << seq
                end
            end
        end
    end
end
