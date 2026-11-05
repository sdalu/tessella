# frozen_string_literal: true

module Tessella
    class Canvas
        # An area under a curve (a line chart's area: true), as btop
        # draws its graphs: every pixel column the series spans is set
        # from the canvas floor up to the curve, so a braille cell holds
        # two independent bars of 0..4 dots and a block cell two of
        # 0..2. A column's height is the curve's value at its centre,
        # or the highest point falling inside it, so a peak narrower
        # than a column is not lost.
        module Area
            # color: one colour name for every cell, or a callable
            # taking a cell row (0 at the top) and returning one.
            # across: true fills each pixel row instead, from the left
            # edge out to the curve (x the value, y the position), the
            # callable then taking a cell column.
            def area(xs, ys, color: nil, across: false)
                return area_across(xs, ys, color) if across

                (0...pixel_width).each do |px|
                    value = column_value(xs, ys, px)
                    fill_column(px, column_top(value), color) if value
                end
            end

            # The value at the middle of a cell row (0 the top) or column.
            def cell_row_value(row)
                @yhi - ((row + 0.5) * (@yhi - @ylo) / height)
            end

            def cell_column_value(col)
                @xlo + ((col + 0.5) * (@xhi - @xlo) / width)
            end

            # A dashed line in data coordinates: every other pixel set.
            def dashed(x0, y0, x1, y1, color: nil)
                from = to_pixel(x0, y0).map(&:floor)
                to = to_pixel(x1, y1).map(&:floor)
                steps = from.zip(to).map { |a, b| (b - a).abs }.max
                (0..steps).step(2) do |i|
                    t = steps.zero? ? 0 : i.fdiv(steps)
                    draw_pixel(*between(from, to, t), color)
                end
            end

            # The pixel t (0..1) of the way from one pixel to another.
            def between(from, to, t)
                from.zip(to).map { |a, b| (a + ((b - a) * t)).round }
            end

            # A bar along pixel row py (0 the top), length pixels from
            # the left edge: a horizontal bar chart's bar on a canvas.
            def row_bar(py, length, color: nil)
                length.clamp(0, pixel_width).times do |px|
                    set_sub_pixel(px, py, color)
                end
            end

            # A bar up pixel column px, height pixels from the floor: a
            # column chart's column on a canvas.
            def column_bar(px, height, color: nil)
                ((pixel_height - height.clamp(0, pixel_height))...pixel_height)
                    .each { set_sub_pixel(px, it, color) }
            end

            private

            def area_across(xs, ys, color)
                (0...pixel_height).each do |py|
                    value = row_value(xs, ys, py)
                    next unless value

                    share = (value - @xlo).fdiv(@xhi - @xlo).clamp(0.0, 1.0)
                    (share * pixel_width).round.times do |px|
                        set_sub_pixel(px, py, shade_across(color, px))
                    end
                end
            end

            # The value at a pixel row: the curve at its centre (x as a
            # function of y), or the highest x of a point inside it.
            def row_value(xs, ys, py)
                lo, hi = row_span(py)
                inside = ys.each_index.select { ys[it] > lo && ys[it] <= hi }
                [*inside.map { xs[it] }, curve_at(ys, xs, (lo + hi) / 2.0)]
                    .compact.max
            end

            def row_span(py)
                step = (@yhi - @ylo).fdiv(pixel_height)
                hi = @yhi - (py * step)
                [hi - step, hi]
            end

            def shade_across(color, px)
                return color unless color.respond_to?(:call)

                color.call(px / x_pixel_per_char)
            end

            def column_value(xs, ys, px)
                lo, hi = column_span(px)
                inside = xs.each_index.select { xs[it] >= lo && xs[it] < hi }
                [*inside.map { ys[it] }, curve_at(xs, ys, (lo + hi) / 2.0)]
                    .compact.max
            end

            def column_span(px)
                step = (@xhi - @xlo).fdiv(pixel_width)
                [@xlo + (px * step), @xlo + ((px + 1) * step)]
            end

            # The highest y any segment of the path takes at x, or nil
            # where the path does not reach.
            def curve_at(xs, ys, x)
                (0...(xs.size - 1)).filter_map do |i|
                    segment_at(xs[i], ys[i], xs[i + 1], ys[i + 1], x)
                end.max
            end

            def segment_at(x0, y0, x1, y1, x)
                return nil unless x.between?(*[x0, x1].minmax)
                return [y0, y1].max if x0 == x1

                y0 + ((y1 - y0) * (x - x0).fdiv(x1 - x0))
            end

            # The first pixel row filled: the column's height in pixels,
            # rounded, counted down from the top.
            def column_top(value)
                share = (value - @ylo).fdiv(@yhi - @ylo).clamp(0.0, 1.0)
                pixel_height - (share * pixel_height).round
            end

            def fill_column(px, top, color)
                (top...pixel_height).each do |py|
                    set_sub_pixel(px, py, shade(color, py))
                end
            end

            def shade(color, py)
                return color unless color.respond_to?(:call)

                color.call(py / y_pixel_per_char)
            end
        end

        include Area
    end
end
