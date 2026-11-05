# frozen_string_literal: true

module Tessella
    # A date axis for the plotted kinds (DESIGN.md, "Chart and kinds"):
    # x values that are times -- a Time, or anything with to_time (a
    # Date, a DateTime) -- are plotted as seconds and labelled as dates,
    # in UTC so the output does not depend on the machine. xdate: names
    # the strftime format; by default it follows the span: a day or more
    # "%Y-%m-%d", an hour or more "%m-%d %H:%M", less "%H:%M:%S". xlim:
    # may be times too; without it the axis spans the data exactly, as
    # a rounded number of seconds means nothing. A Date counts from
    # midnight UTC. A date axis takes no xscale:. Sideways (an
    # orientation: :horizontal chart) the dates label the vertical axis.
    module DateAxis
        DAY = 86_400

        # One time, or one repeated, spans a day either side: a zero
        # span has no scale.
        SPANS = [[86_400, "%Y-%m-%d"], [3600, "%m-%d %H:%M"],
                 [0, "%H:%M:%S"]].freeze

        # A Time, or a Date/DateTime (whose to_time the date library adds).
        def self.time?(value)
            value.is_a?(Time) || value.respond_to?(:to_time)
        end

        def self.seconds(value)
            return value unless time?(value)
            return value.to_f if value.is_a?(Time)
            return value.to_time.to_f if value.respond_to?(:hour)

            Time.utc(value.year, value.month, value.day).to_f
        end

        def initialize(**opts)
            limit = opts[:xlim]
            if limit&.any? { DateAxis.time?(it) }
                opts = opts.merge(xlim: limit.map { DateAxis.seconds(it) })
                @xdate = true
            end
            super
        end

        def add(*args, **)
            return super unless args.length == 2 && dated?(args[0])

            date_axis!
            super(args[0].map { DateAxis.seconds(it) }, args[1], **)
        end

        private

        def dated?(xs) = xs&.any? { DateAxis.time?(it) }

        # The date axis spans the data exactly unless xlim: is given.
        def xlim = date_limits(:x, !@sideways) || super
        def ylim = date_limits(:y, @sideways) || super

        def date_limits(axis, dated)
            return nil unless dated && date_axis? && !@opts[:xlim]

            lo, hi = @series.flat_map(&axis).minmax
            lo == hi ? [lo - DAY, hi + DAY] : [lo, hi]
        end

        def date_axis? = @xdate || @opts[:xdate]

        def date_axis!
            raise ArgumentError, "a date axis takes no xscale:" if
                @opts[:xscale]

            @xdate = true
        end

        def frame_options(canvas, xl, yl)
            options = super
            return options unless date_axis?

            return options.merge(left: date_left(yl)) if @sideways

            options.merge(bottom: [date_label(xl.first, xl),
                                   date_label(xl.last, xl)])
        end

        def date_left(yl)
            { 0 => date_label(yl.last, yl),
              (height - 1) => date_label(yl.first, yl) }
        end

        def date_label(seconds, limits)
            Time.at(seconds).utc.strftime(date_format(limits))
        end

        def date_format(limits)
            format = @opts[:xdate]
            return format if format.is_a?(String)

            span = (limits.last - limits.first).abs
            SPANS.find { |least, _| span >= least }.last
        end
    end
end
