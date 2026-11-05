# frozen_string_literal: true

module Tessella
    # Turns a ready-made body of cells into text: border, title, axis
    # labels and legend (DESIGN.md, "Frame and Color"). Frame knows
    # nothing of data; the body and every label arrive as given. Labels
    # are measured in display columns (Width), not characters, so a
    # wide-character label keeps the frame aligned.
    # The lines a Frame draws under its bottom border: a row of text
    # aligned with the body (under:), and the x-axis extremes at its two
    # ends (bottom:). Kept apart so Frame's own class body stays under
    # budget.
    module FrameBelow
        private

        # Rows of text under the body, column for column (a column
        # chart's names, a legend wrapped by Legend).
        def under_line
            return nil if @under.to_s.empty?

            indent = lead + (" " * Width.of(border_part(:l)))
            @under.lines(chomp: true).map { indent + it }.join("\n")
        end

        def bottom_extremes_line
            left_text, right_text = Array(@bottom)
            return nil unless left_text || right_text

            extremes_line(left_text.to_s, right_text.to_s)
        end

        # The two ends of the x axis, a space between them at least,
        # even when they are wider than the body.
        def extremes_line(left_text, right_text)
            gap = extremes_gap(left_text, right_text)
            gap = " " if gap.empty? && !left_text.empty? && !right_text.empty?
            lead + left_text + gap + right_text
        end

        def extremes_gap(left_text, right_text)
            lw = Width.of(left_text)
            cnt1 = ((width / 2.0) - lw).round
            cnt2 = width - Width.of(right_text) - lw + 2 - cnt1
            pad(cnt1) + pad(cnt2)
        end

        def pad(count) = count.positive? ? " " * count : ""
    end

    class Frame
        include FrameBelow

        MARGIN = 3
        GUTTER = 1

        UNICODE_BORDERS = {
            box: { tl: "┌", tr: "┐", bl: "└", br: "┘",
                   t: "─", b: "─", l: "│", r: "│" },
            bar: { tl: "┌", tr: "┐", bl: "└", br: "┘",
                   t: " ", b: " ", l: "┤", r: nil }
        }.freeze

        ASCII_BORDERS = {
            box: { tl: "+", tr: "+", bl: "+", br: "+",
                   t: "-", b: "-", l: "|", r: "|" },
            bar: { tl: "+", tr: "+", bl: "+", br: "+",
                   t: " ", b: " ", l: "|", r: nil }
        }.freeze

        # DESIGN.md fixes this exact keyword interface: eleven named
        # options.
        # rubocop:disable-next Metrics/ParameterLists
        def initialize(body:, border: :box, ascii: false, color: false,
                       title: nil, xlabel: nil, ylabel: nil,
                       left: {}, right: {}, bottom: nil, under: nil)
            @body = body
            @border = border == :none ? nil : borders(ascii).fetch(border)
            @color = color
            @title = title
            @xlabel = xlabel
            @ylabel = ylabel
            @left = left
            @right = right
            @bottom = bottom
            @under = under
        end

        # Under target :web, emoji-capable glyphs kept as text (Target).
        def to_s
            Target.adapt("#{lines.map(&:rstrip).join("\n")}\n")
        end

        private

        def borders(ascii) = ascii ? ASCII_BORDERS : UNICODE_BORDERS
        def width = @body.first&.length || 0
        def height = @body.length
        def ylabel = @ylabel.to_s.empty? ? nil : @ylabel

        def max_left = @max_left ||= left_column_width

        def lines
            [title_line, top_line, *row_lines, bottom_line, under_line,
             bottom_extremes_line, xlabel_line].compact
        end

        def left_column_width
            base = @left.values.map { Width.of(it) }.max || 0
            ylabel ? base + Width.of(ylabel) + 1 : base
        end

        def lead
            " " * (MARGIN + max_left + GUTTER)
        end

        def title_line = label_line(@title, width)
        def xlabel_line = label_line(@xlabel, width)

        # Each line of text centred under the body.
        def label_line(text, width)
            return nil if text.to_s.empty?

            text.to_s.lines(chomp: true).map do |line|
                offset = [((width / 2.0) - (Width.of(line) / 2.0)).round, 0].max
                lead + (" " * offset) + line
            end.join("\n")
        end

        def top_line
            return nil unless @border

            lead + @border[:tl] + (@border[:t] * width) + @border[:tr]
        end

        def bottom_line
            return nil unless @border

            lead + @border[:bl] + (@border[:b] * width) + @border[:br]
        end

        def row_lines = (0...height).map { row_line(it) }

        def row_line(row)
            left_str = @left.fetch(row, "")
            right_str = @right.fetch(row, "")
            left_part(row, left_str) + (" " * GUTTER) + border_part(:l) +
                body_row(row) + border_part(:r) + (" " * GUTTER) + right_str
        end

        def left_part(row, left_str)
            prefix = ylabel_row?(row) ? ylabel : ""
            fill = max_left - Width.of(prefix) - Width.of(left_str)
            (" " * MARGIN) + prefix + (" " * fill) + left_str
        end

        def ylabel_row?(row) = ylabel && row == ylabel_row
        def ylabel_row = (height / 2.0).round - 1

        def border_part(side) = @border&.fetch(side, nil) || ""

        def body_row(row)
            cells = @body[row]
            return cells.map(&:char).join unless @color

            cells.chunk_while { |a, b| a.color == b.color }.map do |run|
                Color.wrap(run.map(&:char).join, run.first.color)
            end.join
        end
    end
end
