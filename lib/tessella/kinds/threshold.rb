# frozen_string_literal: true

module Tessella
    # A threshold for the plotted kinds (DESIGN.md, "Chart and kinds"):
    # threshold: N draws a dashed reference line at N across the plot
    # -- down it, sideways -- visible without colour; under color:
    # true the cells beyond it take above: (red by default) and the
    # rest below: (the series' own colour unless given), as asciigraph
    # colours above and below a limit. The value axis takes N in.
    module Threshold
        def initialize(**opts)
            super
            limit = opts[:threshold]
            return if limit.nil?

            Check.finite!([limit], "threshold")
            %i[above below].each do |key|
                next unless opts.key?(key)
                next if Color.valid?(opts[key])

                raise ArgumentError, "unknown colour: #{opts[key].inspect}"
            end
        end

        private

        def threshold = @opts[:threshold]

        def build_canvas(xl, yl)
            canvas = super
            threshold_line(canvas, xl, yl) if threshold
            canvas
        end

        # A dot a two pixels along the line, so it reads as a rule.
        def threshold_line(canvas, xl, yl)
            if @sideways
                canvas.dashed(threshold, yl.first, threshold, yl.last)
            else
                canvas.dashed(xl.first, threshold, xl.last, threshold)
            end
        end

        def draw_or_mark(canvas, series)
            return super unless threshold

            super(canvas, series.with(color: split_color(series.color, canvas)))
        end

        # The colour of a cell: above: beyond the threshold, below:
        # (or the series' colour) before it.
        def split_color(own, canvas)
            above = @opts.fetch(:above, :red)
            below = @opts.fetch(:below, own)
            lambda do |row, col|
                beyond?(canvas, row, col) ? above : below
            end
        end

        def beyond?(canvas, row, col)
            return canvas.cell_column_value(col) > threshold if @sideways

            canvas.cell_row_value(row) > threshold
        end

        def axis_values(axis)
            values = super
            return values unless threshold && axis == (@sideways ? :x : :y)

            values + [threshold]
        end
    end
end
