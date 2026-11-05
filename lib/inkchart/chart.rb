# frozen_string_literal: true

module Inkchart
    # Shared machinery behind every chart kind (DESIGN.md, "Chart and
    # kinds"): option handling and defaults, series bookkeeping, colour
    # cycling over Color::NAMES, canvas and frame assembly, and
    # to_s / render. A subclass implements draw_series(canvas, series)
    # and may override default_canvas_type, canvas_type, default_border,
    # draw_grid? or add itself (Stairs reshapes its points there).
    class Chart
        DEFAULT_WIDTH = 40
        DEFAULT_HEIGHT = 15

        OPTIONS = %i[title xlabel ylabel width height xlim ylim canvas
                     ascii color border xscale].freeze

        Series = Data.define(:x, :y, :name, :color)

        def initialize(**opts)
            check_options!(opts)
            @opts = opts
            @ascii = opts.fetch(:ascii, false)
            @color_on = opts.fetch(:color, false)
            @border = opts[:border] || default_border
            @xscale = Stats.transform(opts[:xscale])
            @series = []
            @next_color = 0
        end

        def add(*args, name: nil, color: nil)
            x, y = args.length == 1 ? [nil, *args] : args
            xs = Array(x || (1..y.length)).map(&@xscale)
            @series << Series.new(x: xs, y: Array(y), name: name,
                                  color: color || auto_color)
            self
        end

        def to_s = frame.to_s
        def render(io = $stdout) = io.print(to_s)

        private

        def default_border = :box
        def draw_grid? = true
        def default_canvas_type = @ascii ? :ascii : :braille

        def auto_color
            name = Color::NAMES[@next_color % Color::NAMES.size]
            @next_color += 1
            name
        end

        def check_options!(opts)
            unknown = opts.keys - OPTIONS
            return if unknown.empty?

            raise ArgumentError,
                  "unknown option: #{unknown.map(&:inspect).join(", ")}"
        end

        def canvas_type
            type = @opts[:canvas] || default_canvas_type
            return type if Canvas.types.key?(type)

            raise ArgumentError, "unknown canvas: #{type.inspect}"
        end

        def width  = @opts.fetch(:width, DEFAULT_WIDTH)
        def height = @opts.fetch(:height, DEFAULT_HEIGHT)
        def xlim = Axis.limits(@series.flat_map(&:x), @opts[:xlim])
        def ylim = Axis.limits(@series.flat_map(&:y), @opts[:ylim])

        def canvas_extra
            canvas_type == :density ? { ascii: @ascii } : {}
        end

        def build_canvas(xl, yl)
            opts = { width: width, height: height, xlim: xl, ylim: yl,
                     **canvas_extra }
            canvas = Canvas.build(canvas_type, **opts)
            draw_axes(canvas, xl, yl)
            @series.each { draw_series(canvas, it) }
            canvas
        end

        def draw_axes(canvas, xl, yl)
            return unless draw_grid?

            canvas.line(xl.first, 0, xl.last, 0) if
                yl.first.negative? && yl.last.positive?
            canvas.line(0, yl.first, 0, yl.last) if
                xl.first.negative? && xl.last.positive?
        end

        def frame
            xl = xlim
            yl = ylim
            Frame.new(**frame_options(build_canvas(xl, yl), xl, yl))
        end

        def frame_options(canvas, xl, yl)
            { body: canvas.rows, border: @border, ascii: @ascii,
              color: @color_on, title: @opts[:title],
              xlabel: @opts[:xlabel], ylabel: @opts[:ylabel],
              left: left_labels(yl), right: right_labels,
              bottom: [Axis.tick(xl.first), Axis.tick(xl.last)] }
        end

        def left_labels(yl)
            { 0 => Axis.tick(yl.last), (height - 1) => Axis.tick(yl.first) }
        end

        def right_labels
            named = @series.reject { |s| s.name.to_s.empty? }
            named.each_with_index.to_h { |s, i| [i, s.name.to_s] }
        end
    end
end
