# frozen_string_literal: true

module Tessella
    # Marked series (add's mark:): one glyph in the cell of each point,
    # in place of the kind's own drawing. Kept apart from Chart so
    # Chart's own class body stays under budget.
    module Marks
        private

        def check_mark!(mark)
            return if mark.nil?
            unless mark.is_a?(String) && mark.length == 1
                raise ArgumentError,
                      "mark must be one character: #{mark.inspect}"
            end
            return unless @ascii && !mark.ascii_only?

            raise ArgumentError,
                  "mark must be ASCII under ascii: true: #{mark.inspect}"
        end

        def draw_or_mark(canvas, series)
            return draw_series(canvas, series) unless series.mark

            series.x.zip(series.y).each do |x, y|
                canvas.mark(x, y, series.mark, color: series.color)
            end
        end

        # A marked series shows its glyph before its name.
        def legend(series) = [series.mark, series.name].compact.join(" ")
    end

    # What a chart refuses before it draws (DESIGN.md, "Chart and
    # kinds"): unknown options, a width or height that is not a
    # positive Integer, and a series whose x and y differ in length or
    # hold a value an axis cannot place. Kept apart from Chart so
    # Chart's own class body stays under budget.
    module ChartChecks
        private

        def check_options!(opts)
            unknown = opts.keys - self.class::OPTIONS
            return check_sizes!(opts) if unknown.empty?

            raise ArgumentError,
                  "unknown option: #{unknown.map(&:inspect).join(", ")}"
        end

        def check_sizes!(opts)
            %i[width height].each do |key|
                Check.positive_integer!(opts[key], key.to_s) if opts.key?(key)
            end
        end

        # x (nil for 1..n) and y as stored: each through its scale,
        # both finite, and the same length.
        def series_values(x, y)
            ys = Check.finite!(Array(y), "y")
            xs = Array(x || (1..ys.length))
            Check.same_size!(xs, ys, %w[x y])
            [Check.finite!(xs.map(&@xscale), scaled_name(:x)),
             Check.finite!(ys.map(&@yscale), scaled_name(:y))]
        end

        def scaled_name(axis)
            scale = @opts[:"#{axis}scale"]
            scale ? "#{axis} under #{axis}scale #{scale}" : axis.to_s
        end
    end

    # Shared machinery behind every chart kind (DESIGN.md, "Chart and
    # kinds"): option handling and defaults, series bookkeeping, colour
    # cycling over Color::NAMES, canvas and frame assembly, and
    # to_s / render. A subclass implements draw_series(canvas, series)
    # and may override default_canvas_type, canvas_type, default_border,
    # draw_grid? or add itself (Stairs reshapes its points there).
    class Chart
        include ChartChecks
        include Marks

        DEFAULT_WIDTH = 40
        DEFAULT_HEIGHT = 15

        # Canvases a chart reaches only through another's name.
        WIDE = %i[half_wide eighths_wide].freeze
        OPTIONS = %i[title xlabel ylabel width height xlim ylim canvas
                     ascii color border xscale].freeze

        Series = Data.define(:x, :y, :name, :color, :mark)

        def initialize(**opts)
            check_options!(opts)
            @opts = opts
            @ascii = opts.fetch(:ascii) { Target.ascii? }
            @color_on = opts.fetch(:color, false)
            @border = opts[:border] || default_border
            @xscale = Stats.transform(opts[:xscale])
            @yscale = Stats.transform(opts[:yscale])
            @series = []
            @next_color = 0
        end

        # mark: a one-character glyph drawn in the cell of each point,
        # instead of the kind's own drawing of the series.
        def add(*args, name: nil, color: nil, mark: nil)
            check_mark!(mark)
            x, y = args.length == 1 ? [nil, *args] : args
            xs, ys = series_values(x, y)
            @series << Series.new(x: xs, y: ys, name: name,
                                  color: color || auto_color, mark: mark)
            self
        end

        def to_s
            text = frame.to_s
            return text unless @ascii

            text.each_line.with_index(1) do |line, n|
                Check.ascii!(line.chomp, "chart line #{n}")
            end
            text
        end

        def render(io = $stdout) = io.print(to_s)

        private

        def default_border = :box
        def draw_grid? = true
        def default_canvas_type = @ascii ? :ascii : Target.canvas

        def auto_color
            name = Color::NAMES[@next_color % Color::NAMES.size]
            @next_color += 1
            name
        end

        def canvas_type
            type = @opts[:canvas] || default_canvas_type
            return eighths_type if type == :eighths
            return type if Canvas.types.key?(type) && !WIDE.include?(type)

            raise ArgumentError, "unknown canvas: #{type.inspect}"
        end

        # The eighths canvas only fills (Canvas::Eighths): an area, up
        # its columns or, sideways, along its rows -- not a threshold's
        # dashes, which would read as bars.
        def eighths_type
            raise ArgumentError, "canvas: :eighths needs area: true" unless
                fills?
            raise ArgumentError, "canvas: :eighths takes no threshold:" if
                @opts[:threshold]

            @sideways ? :eighths_wide : :eighths
        end

        def fills? = false

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
            @series.each { draw_or_mark(canvas, it) }
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
            named.each_with_index.to_h { |s, i| [i, legend(s)] }
        end
    end
end
