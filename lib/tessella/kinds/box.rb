# frozen_string_literal: true

module Tessella
    # The five-glyph shapes for one box-and-whisker row, unicode and
    # ascii, by its position within the three rows a box takes
    # (DESIGN.md's box, as unicode_plot's boxplot draws it: a corner
    # border with blank sides, found only here -- Frame has no such
    # border type, so Box builds it into the body cells instead of
    # asking Frame for one).
    module BoxShapes
        UNICODE_SHAPES = [
            { min: "╷", line: " ", fill: "─", lbox: "┌",
              median: "┬", rbox: "┐", max: "╷" },
            { min: "├", line: "─", fill: " ", lbox: "┤",
              median: "│", rbox: "├", max: "┤" },
            { min: "╵", line: " ", fill: "─", lbox: "└",
              median: "┴", rbox: "┘", max: "╵" }
        ].freeze

        # One glyph, one ASCII byte: a whisker meeting the box (├ ┤)
        # and a whisker end cap (╷ ╵) or a vertical box side (│) all
        # become "|" rather than colliding into each other's corner or
        # line glyph; a corner or median end (┌ ┐ └ ┘ ┬ ┴) becomes "+";
        # a horizontal line (─) becomes "-".
        GLYPH_MAP = {
            "┌" => "+", "┐" => "+", "└" => "+", "┘" => "+",
            "┬" => "+", "┴" => "+",
            "├" => "|", "┤" => "|",
            "─" => "-", "│" => "|",
            "╷" => "|", "╵" => "|"
        }.freeze

        ASCII_SHAPES = UNICODE_SHAPES.map do |shape|
            shape.transform_values { |ch| GLYPH_MAP.fetch(ch, ch) }
        end.freeze

        UNICODE_CORNERS = ["┌", "┐", "└", "┘"].freeze
        ASCII_CORNERS = UNICODE_CORNERS.map { |ch| GLYPH_MAP.fetch(ch, ch) }
                                       .freeze

        CORNERS = { unicode: UNICODE_CORNERS, ascii: ASCII_CORNERS }.freeze

        private

        def cell(char, color = nil) = Cell.new(char: char, color: color)

        def corners = CORNERS[@ascii ? :ascii : :unicode]

        def shapes = @ascii ? ASCII_SHAPES : UNICODE_SHAPES

        def border_row(top, ew)
            tl, tr, bl, br = corners
            left, right = top ? [tl, tr] : [bl, br]
            [cell(left)] + Array.new(ew) { cell(" ") } + [cell(right)]
        end

        def shape_row(cols, row, ew, color)
            chars = Array.new(ew, " ")
            paint_shape!(chars, cols, shapes[row])
            [cell(" ")] + chars.map { |ch| cell(ch, color) } + [cell(" ")]
        end

        def paint_shape!(chars, cols, shape)
            spans(cols, shape).each do |lo, hi, ch|
                fill_span!(chars, lo, hi, ch)
            end
            place_marks!(chars, cols, shape)
        end

        def spans(cols, shape)
            [[cols[0], cols[1] - 1, shape[:line]],
             [cols[1], cols[2] - 1, shape[:fill]],
             [cols[2], cols[3] - 1, shape[:fill]],
             [cols[3], cols[4] - 1, shape[:line]]]
        end

        def fill_span!(chars, lo, hi, ch)
            (lo...hi).each { |i| chars[i] = ch }
        end

        def place_marks!(chars, cols, shape)
            marks(shape).each_with_index { |ch, i| chars[cols[i] - 1] = ch }
        end

        def marks(shape)
            [shape[:min], shape[:lbox], shape[:median], shape[:rbox],
             shape[:max]]
        end
    end

    # One or several box-and-whisker plots over samples (DESIGN.md,
    # "Chart and kinds"): three rows of cells per box, laid out
    # directly -- no pixel canvas, no Frame border (see BoxShapes) --
    # from Stats.percentiles. Chart lends option checking and
    # ascii/colour handling; its canvas and draw_series go unused.
    class Box < Chart
        include BoxShapes

        MIN_WIDTH = 10

        def initialize(**opts)
            super
            @boxes = []
        end

        def add(names, samples, color: nil)
            box_color = color || auto_color
            names = Array(names)
            Check.same_size!(names, Array(samples), %w[names samples])
            names.zip(samples).each do |name, sample|
                values = Array(sample).map(&@xscale)
                @boxes << [name.to_s, Check.finite!(values, "sample"),
                           box_color]
            end
            self
        end

        private

        def frame
            Frame.new(**frame_options)
        end

        def frame_options
            { body: rows, border: :none, ascii: @ascii, color: @color_on,
              title: @opts[:title], xlabel: @opts[:xlabel],
              ylabel: @opts[:ylabel], left: left_labels }
        end

        def left_labels
            @boxes.each_with_index.to_h { |(name, *), i| [(i * 3) + 2, name] }
                  .reject { |_, v| v.to_s.empty? }
        end

        def effective_width = [width, MIN_WIDTH].max

        def box_limits
            values = @boxes.flat_map { |_, sample, _| sample }
            Axis.limits(values, @opts[:xlim])
        end

        def rows
            lo, hi = box_limits
            ew = effective_width
            [border_row(true, ew), *box_rows(lo, hi, ew),
             border_row(false, ew), bottom_row(lo, hi, ew)]
        end

        def box_rows(lo, hi, ew)
            @boxes.flat_map do |_, sample, color|
                box_shape(sample, lo, hi, ew, color)
            end
        end

        def box_shape(sample, lo, hi, ew, color)
            cols = columns(Stats.percentiles(sample, [0, 25, 50, 75, 100]),
                           lo, hi, ew)
            (0..2).map { |row| shape_row(cols, row, ew, color) }
        end

        def columns(values, lo, hi, ew)
            values.map { |v| scale_column(v, lo, hi, ew) }
        end

        def scale_column(v, lo, hi, ew)
            pos = (v - lo).fdiv(hi - lo) * ew
            pos.round(half: :even).clamp(1, ew).to_i
        end

        def bottom_row(lo, hi, ew)
            min_s = Axis.tick(lo)
            max_s = Axis.tick(hi)
            mid_s = Axis.tick((lo + hi) / 2.0)
            bottom_text(min_s, mid_s, max_s, ew).each_char.map { |c| cell(c) }
        end

        def bottom_text(min_s, mid_s, max_s, ew)
            cnt1 = left_gap(ew, mid_s, min_s)
            cnt2 = right_gap(ew, min_s, mid_s, max_s, cnt1)
            text = min_s + pad(cnt1) + mid_s + pad(cnt2) + max_s
            pad_to(text, ew + 2)
        end

        def left_gap(ew, mid_s, min_s)
            ((ew / 2.0) - (mid_s.length / 2.0) - min_s.length).round
        end

        def right_gap(ew, min_s, mid_s, max_s, cnt1)
            ew - max_s.length - min_s.length - mid_s.length + 2 - cnt1
        end

        def pad(count) = count.positive? ? " " * count : ""

        def pad_to(text, len)
            return text[0, len] if text.length >= len

            text + (" " * (len - text.length))
        end
    end

    # (names, samples, **opts): a new Box chart; samples is an Array
    # of Arrays, one per name.
    def self.box(*, **)
        Box.new(**).add(*)
    end
end
