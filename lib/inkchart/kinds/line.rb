# frozen_string_literal: true

module Inkchart
    # A connected path through (x, y) points (DESIGN.md, "Chart and
    # kinds"): the x = 0 / y = 0 axis lines draw when in range, as
    # unicode_plot's lineplot does.
    class Line < Chart
        private

        def draw_series(canvas, series)
            canvas.lines(series.x, series.y, color: series.color)
        end
    end

    # Unconnected points (DESIGN.md): the same axis lines as Line, with
    # no path drawn between points.
    class Scatter < Chart
        private

        def draw_series(canvas, series)
            canvas.points(series.x, series.y, color: series.color)
        end
    end

    # A step path through (x, y): style :post holds the previous y
    # until the new x, then steps to the new y; :pre steps to the new y
    # first, at the previous x -- as unicode_plot's stairs does.
    class Stairs < Line
        STYLES = %i[post pre].freeze

        def initialize(style: :post, **)
            raise ArgumentError, "unknown style: #{style.inspect}" unless
                STYLES.include?(style)

            @style = style
            super(**)
        end

        # A marked series marks the points given, not the step corners.
        def add(*args, name: nil, color: nil, mark: nil)
            return super if mark

            x, y = args.length == 1 ? [nil, *args] : args
            xs = Array(x || (1..y.length))
            sx, sy = step_coords(xs, Array(y))
            super(sx, sy, name: name, color: color)
        end

        private

        def step_coords(x, y)
            @style == :post ? post_steps(x, y) : pre_steps(x, y)
        end

        def post_steps(x, y)
            xs = [x.first]
            ys = [y.first]
            (1...x.size).each do |i|
                xs << x[i] << x[i]
                ys << y[i - 1] << y[i]
            end
            [xs, ys]
        end

        def pre_steps(x, y)
            xs = [x.first]
            ys = [y.first]
            (1...x.size).each do |i|
                xs << x[i - 1] << x[i]
                ys << y[i] << y[i]
            end
            [xs, ys]
        end
    end

    # Hit-count shading over (x, y) points (DESIGN.md): always the
    # :density canvas -- matching unicode_plot's own densityplot
    # default, no axis lines.
    class Density < Scatter
        private

        def canvas_type = :density
        def draw_grid? = false
    end

    # (x = nil, y, **opts): a new Line chart with one series.
    def self.line(*, name: nil, mark: nil, **)
        add_series(Line.new(**), *, name: name, mark: mark)
    end

    # (x = nil, y, **opts): a new Scatter chart with one series.
    def self.scatter(*, name: nil, mark: nil, **)
        add_series(Scatter.new(**), *, name: name, mark: mark)
    end

    # (x = nil, y, style: :post, **opts): a new Stairs chart, style:
    # :pre or :post.
    def self.stairs(*, style: :post, name: nil, mark: nil, **)
        add_series(Stairs.new(style: style, **), *, name: name,
                                                    mark: mark)
    end

    # (x = nil, y, **opts): a new Density chart with one series.
    def self.density(*, name: nil, mark: nil, **)
        add_series(Density.new(**), *, name: name, mark: mark)
    end

    # name: and mark: apply to the first series, as add's do to the
    # others
    def self.add_series(chart, *, name: nil, mark: nil)
        chart.add(*, name: name, mark: mark)
        chart
    end
    private_class_method :add_series
end
