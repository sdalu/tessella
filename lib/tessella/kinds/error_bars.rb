# frozen_string_literal: true

module Tessella
    # Error bars for the plotted kinds (DESIGN.md, "Chart and kinds"):
    # add's yerr: is an error a point -- the bar runs y - e .. y + e --
    # or [lows, highs] for asymmetric ones. Bounds are taken in data
    # units, then through yscale:. Each point gets a segment along the
    # value axis (across, sideways), drawn after the series or its
    # marks, and the axis limits take the bars in.
    module ErrorBars
        def add(*args, yerr: nil, **)
            super(*args, **)
            return self unless yerr

            ys = Array(args.last)
            (@errors ||= {})[@series.size - 1] = error_bounds(ys, yerr)
            self
        end

        private

        # [lows, highs] in plotted units.
        def error_bounds(ys, yerr)
            lo, hi = yerr.first.is_a?(Array) ? yerr : [yerr, yerr]
            [lo, hi].each { error_size!(it, ys) }
            lows = ys.zip(lo).map { |y, e| @yscale.call(y - e) }
            highs = ys.zip(hi).map { |y, e| @yscale.call(y + e) }
            [Check.finite!(lows, "y - yerr"), Check.finite!(highs, "y + yerr")]
        end

        def error_size!(errors, ys)
            Check.finite!(Array(errors), "yerr")
            Check.same_size!(Array(errors), ys, %w[yerr y])
            return if errors.all? { !it.negative? }

            raise ArgumentError, "yerr must be 0 or more"
        end

        def draw_or_mark(canvas, series)
            super
            bounds = @errors&.[](@series.index { it.equal?(series) })
            draw_errors(canvas, series, bounds) if bounds
        end

        def draw_errors(canvas, series, bounds)
            positions = @sideways ? series.y : series.x
            positions.each_with_index do |pos, i|
                lo = bounds[0][i]
                hi = bounds[1][i]
                if @sideways
                    canvas.line(lo, pos, hi, pos, color: series.color)
                else
                    canvas.line(pos, lo, pos, hi, color: series.color)
                end
            end
        end

        def axis_values(axis)
            values = super
            return values unless @errors && axis == (@sideways ? :x : :y)

            values + @errors.values.flatten
        end
    end
end
