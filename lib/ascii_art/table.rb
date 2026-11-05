# frozen_string_literal: true

module AsciiArt
    # `AsciiArt.table` (ported from the ascii-art skill's
    # scripts/table.rb): rows of Strings framed as a monospace table,
    # in any of the script's glyph sets, or as a native GFM pipe
    # table under style: :markdown. A column is right-aligned when
    # every non-blank body cell reads as a number (Integer() or
    # Float() with exception: false); align: overrides that per
    # column. Width is columns (Width), not bytes, so CJK cells still
    # line up.
    module Table
        # Table-only glyphs: the tees and crosses a framed table needs
        # beyond the corners and runs Borders already has (DESIGN.md
        # names Borders as shared); minimal's whole set is its own,
        # since every one of its slots differs from a box style's.
        module Glyphs
            TEES = {
                ascii: { top_t: "+", bot_t: "+", sep_l: "+", sep_t: "+",
                         sep_r: "+" },
                light: { top_t: "┬", bot_t: "┴", sep_l: "├", sep_t: "┼",
                         sep_r: "┤" },
                heavy: { top_t: "┳", bot_t: "┻", sep_l: "┣", sep_t: "╋",
                         sep_r: "┫" },
                double: { top_t: "╦", bot_t: "╩", sep_l: "╠", sep_t: "╬",
                          sep_r: "╣" },
                rounded: { top_t: "┬", bot_t: "┴", sep_l: "├", sep_t: "┼",
                           sep_r: "┤" }
            }.freeze

            MINIMAL = { tl: " ", tr: " ", bl: " ", br: " ", h: " ",
                        top_t: "╷", bot_t: "╵", sep_l: "╶", sep_t: "┼",
                        sep_r: "╴", sep_h: "─", cl: " ", cs: "│", cr: " " }
                      .freeze

            def self.fetch(style)
                return MINIMAL if style == :minimal

                b = Borders.fetch(style)
                TEES.fetch(style).merge(tl: b.tl, tr: b.tr, bl: b.bl,
                                        br: b.br, h: b.h, sep_h: b.h,
                                        cl: b.v, cs: b.v, cr: b.v)
            end
        end

        # Numeric detection (Ruby's own Integer()/Float() reading) and
        # the alignment it drives, overridden column by column by
        # align:.
        module Detect
            def self.numeric?(value)
                s = value.strip
                !Integer(s, exception: false).nil? ||
                    !Float(s, exception: false).nil?
            end

            def self.column_numeric?(body, i)
                cells = body.map { |row| row[i] }.reject { |c| c.strip.empty? }
                return false if cells.empty?

                cells.all? { |c| numeric?(c) }
            end

            def self.auto_align(body, i)
                column_numeric?(body, i) ? :right : :left
            end

            def self.resolve_aligns(body, align, ncols)
                return parse_align(align) if align

                Array.new(ncols) { |i| auto_align(body, i) }
            end

            def self.parse_align(align)
                check_chars!(align)
                align.chars.map { |c| Table::ALIGN_LETTERS.fetch(c.downcase) }
            end

            def self.check_chars!(align)
                return if /\A[lrc]+\z/i.match?(align)

                raise ArgumentError,
                      "align must be letters l, r or c: #{align.inspect}"
            end
        end

        # The framed (box) styles: ascii, light, heavy, double,
        # rounded, minimal -- a title row, a header separator, body
        # rows and the outer frame, from one glyph Hash (Glyphs).
        module Render
            def self.pad_cell(text, width, align)
                case align
                when :right  then Width.rjust("#{text} ", width)
                when :center then Width.center(text, width)
                else              Width.ljust(" #{text}", width)
                end
            end

            def self.build_row(row, widths, aligns)
                row.each_index.map do |i|
                    pad_cell(Table.sanitize(row[i]), widths[i], aligns[i])
                end
            end

            def self.span_width(widths) = widths.sum + widths.size - 1

            def self.span_row(left, fill, right, widths)
                left + (fill * span_width(widths)) + right
            end

            def self.border_row(left, fill, sep, right, widths)
                left + widths.map { |w| fill * w }.join(sep) + right
            end

            def self.content_row(left, sep, right, cells)
                left + cells.join(sep) + right
            end

            def self.title_lines(g, title, widths)
                [span_row(g[:tl], g[:h], g[:tr], widths),
                 content_row(g[:cl], g[:cl], g[:cr],
                             [Width.center(title, span_width(widths))]),
                 border_row(g[:sep_l], g[:sep_h], g[:top_t], g[:sep_r],
                            widths)]
            end

            def self.header_lines(g, header_cells, widths)
                return [] unless header_cells

                [content_row(g[:cl], g[:cs], g[:cr], header_cells),
                 border_row(g[:sep_l], g[:sep_h], g[:sep_t], g[:sep_r],
                            widths)]
            end

            def self.top_border(g, title, widths)
                return title_lines(g, title, widths) if title

                [border_row(g[:tl], g[:h], g[:top_t], g[:tr], widths)]
            end

            def self.bottom_border(g, widths)
                border_row(g[:bl], g[:h], g[:bot_t], g[:br], widths)
            end

            def self.body_lines(g, body_cells)
                body_cells.map do |row|
                    content_row(g[:cl], g[:cs], g[:cr], row)
                end
            end

            def self.render_box(g, header_cells, body_cells, widths, title)
                top_border(g, title, widths) +
                    header_lines(g, header_cells, widths) +
                    body_lines(g, body_cells) + [bottom_border(g, widths)]
            end
        end

        # The markdown style: a native GFM pipe table, --- marking a
        # right-aligned column and :---: a centred one; a title is a
        # plain line above it, blank-line separated.
        module Markdown
            FLOORS = { left: 1, right: 2, center: 3 }.freeze

            def self.md_min_width(width, align)
                [width, FLOORS.fetch(align)].max
            end

            def self.md_delim_cell(width, align)
                case align
                when :right  then "#{"-" * (width - 1)}:"
                when :center then ":#{"-" * (width - 2)}:"
                else              "-" * width
                end
            end

            def self.md_row(cells) = "|#{cells.join("|")}|"

            def self.md_padded_row(cells, widths, aligns)
                cells.each_index.map do |i|
                    Render.pad_cell(Table.sanitize(cells[i]), widths[i],
                                    aligns[i])
                end
            end

            def self.md_widths(widths, aligns)
                widths.each_index.map { |i| md_min_width(widths[i], aligns[i]) }
            end

            def self.md_delim_row(mw, aligns)
                cells = mw.each_index.map do |i|
                    md_delim_cell(mw[i], aligns[i])
                end
                md_row(cells)
            end

            def self.render(header, body, layout)
                aligns = layout.aligns
                mw = md_widths(layout.widths, aligns)
                head = header || Array.new(layout.widths.size, "")
                rows = [md_row(md_padded_row(head, mw, aligns)),
                        md_delim_row(mw, aligns)]
                rows += body.map { |r| md_row(md_padded_row(r, mw, aligns)) }
                layout.title ? [layout.title, "", *rows] : rows
            end
        end

        ALIGN_LETTERS = { "l" => :left, "r" => :right, "c" => :center }
                        .freeze
        STYLE_NAMES = (Glyphs::TEES.keys + %i[minimal markdown]).freeze

        # The three things a render needs beyond the header and body
        # cells themselves, bundled so render and Markdown.render stay
        # under the house parameter-count budget.
        Layout = Data.define(:widths, :aligns, :title)

        def self.sanitize(text) = text.tr("\t", " ")

        # rows: Array of Arrays of String; the first is the header
        # unless header: false. Raises ArgumentError naming a ragged
        # row, an empty table, an align: of the wrong length, or an
        # unknown style.
        # rubocop:disable-next Metrics/ParameterLists
        def self.build(rows, header:, style:, ascii:, align:, title:)
            head, body = split(rows, header)
            ncols = (head || body.first).size
            check_align_length!(align, ncols)
            aligns = Detect.resolve_aligns(body, align, ncols)
            widths = compute_widths(head, body, ncols)
            layout = Layout.new(widths, aligns, title_text(title))
            Block.new(render(resolve_style!(style, ascii), head, body, layout))
        end

        def self.title_text(title) = title && sanitize(title)

        def self.split(rows, header)
            check_rows!(rows)
            header ? [rows[0], rows[1..]] : [nil, rows]
        end

        def self.check_rows!(rows)
            check_ragged!(rows)
            raise ArgumentError, "no rows to tabulate" if rows.empty?
        end

        def self.check_ragged!(rows)
            return if rows.empty?

            ncols = rows.first.size
            rows.each_with_index do |row, i|
                next if row.size == ncols

                raise ArgumentError, "line #{i + 1}: expected #{ncols} " \
                                     "fields, got #{row.size}"
            end
        end

        def self.check_align_length!(align, ncols)
            return unless align && align.length != ncols

            raise ArgumentError,
                  "align has #{align.length} letters, #{ncols} columns"
        end

        def self.compute_widths(head, body, ncols)
            Array.new(ncols) { |i| column_width(head, body, i) }
        end

        def self.column_width(head, body, i)
            cells = body.map { |row| sanitize(row[i]) }
            cells << sanitize(head[i]) if head
            cells.map { |c| Width.of(c) }.max + 2
        end

        def self.resolve_style!(style, ascii)
            sym = style.nil? ? :light : normalize_style!(style)
            ascii ? :ascii : sym
        end

        def self.normalize_style!(style)
            sym = style.to_s.to_sym
            return sym if STYLE_NAMES.include?(sym)

            raise ArgumentError, "unknown style: #{style.inspect}"
        end

        def self.render(style, head, body, layout)
            return Markdown.render(head, body, layout) if style == :markdown

            widths = layout.widths
            aligns = layout.aligns
            g = Glyphs.fetch(style)
            padded_head = head && Render.build_row(head, widths, aligns)
            padded_body = body.map { |r| Render.build_row(r, widths, aligns) }
            Render.render_box(g, padded_head, padded_body, widths,
                              layout.title)
        end

        # A small RFC 4180 reader: no runtime dependency, so a
        # hand-written one rather than Ruby's "csv", a bundled gem
        # under Ruby 3.4 and not the standard library (CLAUDE.md,
        # DESIGN.md's "no runtime dependency"). Quoted fields, ""
        # escapes, a separator or newline inside quotes, and \n, \r\n
        # or \r row endings; checked against CSV.parse on the same
        # text in the port's parity script, not here.
        class CSVReader
            def self.parse(text, sep)
                new(text, sep).run
            end

            def initialize(text, sep)
                @text = text
                @sep = sep
                @len = text.length
                @pos = 0
                @rows = []
                @row = []
                @field = +""
                @state = :empty # :empty, :unquoted, :quoted, :closed
            end

            def run
                step until @pos >= @len
                bad!("unterminated quoted field") if @state == :quoted
                terminate_record! unless blank_record?
                @rows
            end

            private

            def bad!(msg)
                raise ArgumentError, "#{msg} in line #{@rows.size + 1}"
            end

            def step
                c = @text[@pos]
                case @state
                when :quoted then quoted_char(c)
                when :closed then closed_char(c)
                else open_char(c)
                end
            end

            def open_char(c)
                return start_quote if c == '"' && @state == :empty
                return bad!("illegal quoting") if c == '"'
                return advance_field if c == @sep
                return end_of_line if newline?(c)

                @field << c
                @state = :unquoted
                @pos += 1
            end

            def closed_char(c)
                return advance_field if c == @sep
                return end_of_line if newline?(c)

                bad!("a value found after a closed quoted field")
            end

            def quoted_char(c)
                return peek_quote if c == '"'

                @field << c
                @pos += 1
            end

            def peek_quote
                if @text[@pos + 1] == '"'
                    @field << '"'
                    @pos += 2
                else
                    @state = :closed
                    @pos += 1
                end
            end

            def start_quote
                @state = :quoted
                @pos += 1
            end

            def newline?(c) = %W[\n \r].include?(c)

            def crlf? = @text[@pos] == "\r" && @text[@pos + 1] == "\n"

            def advance_field
                push_field
                @pos += 1
            end

            def end_of_line
                terminate_record!
                @pos += crlf? ? 2 : 1
            end

            def terminate_record!
                push_field unless blank_record?
                push_row
            end

            def blank_record?
                @row.empty? && @field.empty? && @state == :empty
            end

            def push_field
                @row << @field
                @field = +""
                @state = :empty
            end

            def push_row
                @rows << @row
                @row = []
            end
        end

        # Parses CSV (or, tsv: true, tab-separated) text into rows of
        # Strings with CSVReader; raises ArgumentError on malformed
        # input (an unterminated quote, a stray quote outside one).
        def self.parse(text, tsv: false)
            CSVReader.parse(text, tsv ? "\t" : ",")
        end
    end

    # rubocop:disable-next Metrics/ParameterLists
    def self.table(rows, header: true, style: nil, ascii: false, align: nil,
                   title: nil)
        Table.build(rows, header: header, style: style, ascii: ascii,
                          align: align, title: title)
    end
end
