# frozen_string_literal: true

module Tessella
    # orientation: for the plotted kinds (line, scatter, stairs,
    # density): :vertical, the default, puts values up the vertical
    # axis; :horizontal swaps the axes, values along the horizontal one
    # and x running up. Each series is stored swapped, so everything
    # drawing it works unchanged; xlim:, ylim:, xlabel: and ylabel:
    # keep their meaning and follow their axis. A kind with a floor at
    # zero (an area) names it with zero_floor?, and the value axis
    # takes in 0 whichever way it runs.
    module Sideways
        ORIENTATIONS = %i[vertical horizontal].freeze

        def initialize(**opts)
            super
            orientation = opts.fetch(:orientation, :vertical)
            unless ORIENTATIONS.include?(orientation)
                raise ArgumentError,
                      "unknown orientation: #{orientation.inspect}"
            end
            @sideways = orientation == :horizontal
        end

        def add(*, **)
            super
            return self unless @sideways

            last = @series.pop
            @series << last.with(x: last.y, y: last.x)
            self
        end

        private

        def zero_floor? = false

        def xlim = Axis.limits(axis_values(:x), @opts[limit_key(:x)])
        def ylim = Axis.limits(axis_values(:y), @opts[limit_key(:y)])

        # The option limiting a canvas axis: its own, or the other's
        # when the axes are swapped.
        def limit_key(axis)
            return :"#{axis}lim" unless @sideways

            axis == :x ? :ylim : :xlim
        end

        def axis_values(axis)
            values = @series.flat_map(&axis)
            value_axis = @sideways ? :x : :y
            zero_floor? && axis == value_axis ? [0, *values] : values
        end

        def frame_options(*)
            options = super
            return options unless @sideways

            options.merge(xlabel: @opts[:ylabel], ylabel: @opts[:xlabel])
        end
    end
end
