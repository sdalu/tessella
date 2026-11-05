# frozen_string_literal: true

module Tessella
    # The bar layouts besides unicode_plot's (DESIGN.md, "Chart and
    # kinds"): orientation: :vertical draws columns, and blocks:
    # :braille or :block packs several bars into one character --
    # braille four bars per text row (two columns per character when
    # vertical), block two. Values must be zero or more. Kept apart
    # from Bar so Bar's own class body stays under budget.
    module BarLayouts
        BLOCKS = %i[eighths braille block].freeze
        ORIENTATIONS = %i[horizontal vertical].freeze

        private

        # unicode_plot's own layout: horizontal bars of eighths.
        def classic? = @orientation == :horizontal && @blocks == :eighths

        def check_layout!(opts)
            @orientation = pick!(opts, :orientation, ORIENTATIONS)
            @blocks = pick!(opts, :blocks, BLOCKS)
            return if @blocks == :eighths

            if @ascii
                raise ArgumentError, "blocks: #{@blocks} conflicts with " \
                                     "ascii: true"
            end
            glyph_options!(opts)
        end

        def pick!(opts, key, allowed)
            value = opts.fetch(key, allowed.first)
            return value if allowed.include?(value)

            raise ArgumentError, "unknown #{key}: #{value.inspect}"
        end

        def glyph_options!(opts)
            given = %i[fill eighths track] & opts.keys
            return if given.empty?

            raise ArgumentError, "#{given.join(", ")} only with blocks: " \
                                 ":eighths, not :#{@blocks}"
        end

        # Each bar's value through xscale, refused below zero.
        def layout_values
            values = @bars.map { |_, value, _| @xscale.call(value) }
            return values if values.all? { it >= 0 }

            raise ArgumentError, "a #{@orientation} or #{@blocks} bar " \
                                 "chart needs values of 0 or more"
        end

        def layout_frame_options
            values = layout_values
            max = values.max.to_f
            common = { ascii: @ascii, color: @color_on, title: @opts[:title] }
            return common.merge(column_options(values, max)) if
                @orientation == :vertical

            common.merge(dot_row_options(values, max))
        end

        # The value axis's top: the largest bar's value, as given.
        def top_label
            transformed = @bars.map { |_, value, _| @xscale.call(value) }
            Axis.label(@bars[transformed.index(transformed.max)][1])
        end

        def share(value, max) = max.positive? ? value / max : 0.0

        def pixels(value, max, span) = (share(value, max) * span).round
    end

    # orientation: :vertical -- columns rising from a floor, value
    # axis on the left (0 to the largest value), names under the
    # columns when each fits its slot, else the first and the last.
    module ColumnBars
        RISE = " ▁▂▃▄▅▆▇".chars.freeze

        private

        def column_options(values, max)
            body, slot = column_body(values, max)
            { body: body, border: :box, xlabel: @opts[:xlabel],
              ylabel: @opts[:ylabel] || column_value_label,
              left: { (body.size - 1) => "0", 0 => top_label },
              **column_names(slot) }
        end

        def column_body(values, max)
            return rise_columns(values, max) if @blocks == :eighths

            dot_columns(values, max)
        end

        def column_height = @opts.fetch(:height, Chart::DEFAULT_HEIGHT)

        # One text column per bar, eighths of a cell: " ▁▂▃▄▅▆▇█".
        def rise_columns(values, max)
            gap, bw = rise_geometry(values.size)
            rows = Array.new(column_height) { [] }
            values.each_with_index do |v, i|
                blank_columns(rows, i.zero? ? 0 : gap)
                append_column(rows, rise_units(share(v, max)), bw, color_of(i))
            end
            [rows, bw + gap]
        end

        def blank_columns(rows, count)
            rows.each { it.concat(Array.new(count) { Cell.blank }) }
        end

        def color_of(index) = @bars[index][2]

        # [gap, column width]: a blank column between bars when they
        # fit with one, and the width shared out between them.
        def rise_geometry(n)
            gap = (2 * n) - 1 <= width ? 1 : 0
            [gap, [((width + gap) / n) - gap, 1].max]
        end

        def rise_units(fraction)
            return (fraction * column_height).round * 8 unless @eighths

            (fraction * column_height * 8).round
        end

        def append_column(rows, units, bw, color)
            rows.each_with_index do |row, r|
                level = (column_height - 1 - r) * 8
                row.concat(Array.new(bw) { rise_cell(units - level, color) })
            end
        end

        def rise_cell(eighths, color)
            return Cell.new(char: @fill, color: color) if eighths >= 8
            return Cell.blank unless eighths.positive?

            Cell.new(char: RISE[eighths], color: color)
        end

        # One pixel column per bar on a braille or block canvas, so a
        # character holds two columns; wider when the width allows,
        # with a one-pixel gap between bars then.
        def dot_columns(values, max)
            canvas = dot_canvas(column_chars(values.size), column_height)
            per = [canvas.pixel_width / values.size, 1].max
            values.each_with_index do |v, i|
                dot_column(canvas, i * per, per,
                           [pixels(v, max, canvas.pixel_height), color_of(i)])
            end
            [canvas.rows, slot_chars(per)]
        end

        # A bar per pixels wide at px, one pixel left as its gap.
        def dot_column(canvas, px, per, bar)
            height, color = bar
            (per > 1 ? per - 1 : 1).times do |k|
                canvas.column_bar(px + k, height, color: color)
            end
        end

        def column_chars(n) = [width, (n + 1) / 2].max

        # A name's room under a dot column, when bars fill whole cells.
        def slot_chars(per) = per.even? ? per / 2 : nil

        def dot_canvas(cols, rows)
            Canvas.build(@blocks, width: cols, height: rows, xlim: [0, 1],
                                  ylim: [0, 1])
        end

        # Names under the columns when each fits its slot (a column's
        # width and its gap), else the first and the last at the ends.
        def column_names(slot)
            names = column_labels
            if slot && names.all? { Width.of(it) <= slot }
                { under: names.map { Width.center(it, slot) }.join.rstrip }
            else
                { bottom: [names.first, names.last] }
            end
        end

        def column_labels = @bars.map { |label, *| label.to_s }
        def column_value_label = nil
    end

    # blocks: :braille or :block, horizontal: one pixel row per bar, so
    # a text row holds four bars (braille) or two (block), each row
    # named by the bars it holds; the value axis runs under the frame
    # from 0 to the largest value.
    module DotRowBars
        private

        def dot_row_options(values, max)
            canvas = dot_canvas(width, dot_row_count(values.size))
            values.each_with_index do |v, i|
                canvas.row_bar(i, pixels(v, max, canvas.pixel_width),
                               color: color_of(i))
            end
            { body: canvas.rows, border: :box, xlabel: xlabel,
              ylabel: @opts[:ylabel], left: dot_row_labels(canvas),
              bottom: ["0", top_label] }
        end

        def dot_row_count(n) = (n + per_row - 1) / per_row
        def per_row = @blocks == :braille ? 4 : 2

        def dot_row_labels(canvas)
            (0...canvas.height).to_h do |r|
                first = r * per_row
                last = [first + per_row, @bars.size].min - 1
                [r, group_label(first, last)]
            end
        end

        def group_label(first, last)
            names = column_labels
            first == last ? names[first] : "#{names[first]}..#{names[last]}"
        end
    end
end
