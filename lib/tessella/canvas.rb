# frozen_string_literal: true

module Tessella
    # Glyphs written over a canvas's cells, whatever those cells draw:
    # text (annotate) and point marks (mark). Kept apart from Canvas so
    # Canvas's own class body stays under budget.
    module Overlay
        # char in the cell holding (x, y), over whatever that cell
        # draws; outside the limits, nothing.
        def mark(x, y, char, color: nil)
            return unless x.between?(@xlo, @xhi) && y.between?(@ylo, @yhi)

            px, py = to_pixel(x, y).map(&:floor)
            px = clip(px, pixel_width)
            py = clip(py, pixel_height)
            @overlay[cell_index(px, py)] =
                Cell.new(char: char, color: cell_color(color, px, py))
        end

        def annotate(col, row, text, color: nil)
            text.each_char.with_index do |ch, i|
                next unless (col + i).between?(0, width - 1) &&
                            row.between?(0, height - 1)
                @overlay[(row * width) + col + i] =
                    Cell.new(char: ch, color: color)
            end
        end
    end

    # A grid of character cells a chart draws data into: data
    # coordinates map onto pixels, pixel (0, 0) is the bottom-left, and
    # sub-pixels pack into one Cell per character (DESIGN.md, Canvas).
    # Concrete sub-pixel layouts live in canvas/*.rb, each registering
    # itself under its type with Canvas.register.
    class Canvas
        include Overlay

        def self.types = (@types ||= {})
        def self.register(type, klass) = (types[type] = klass)

        # type, width:, height:, xlim:, ylim: and a type's own extras
        # (density's ascii:). A missing required keyword raises
        # ArgumentError naming it, as Ruby's own "missing keyword:
        # :width" does, rather than failing deeper in a subclass.
        def self.build(type, **opts)
            klass = types.fetch(type) do
                raise Error, "unknown canvas type: #{type.inspect}"
            end
            missing = %i[width height xlim ylim] - opts.keys
            unless missing.empty?
                s = missing.size > 1 ? "s" : ""
                names = missing.map { ":#{it}" }.join(", ")
                raise ArgumentError, "missing keyword#{s}: #{names}"
            end
            klass.new(opts.delete(:width), opts.delete(:height), **opts)
        end

        attr_reader :width, :height, :pixel_width, :pixel_height

        def initialize(width, height, xlim:, ylim:)
            @width = width
            @height = height
            @pixel_width = width * x_pixel_per_char
            @pixel_height = height * y_pixel_per_char
            @xlo, @xhi = xlim
            @ylo, @yhi = ylim
            @grid = Array.new(width * height, blank_code)
            @colors = Array.new(width * height)
            @overlay = Array.new(width * height)
        end

        def point(x, y, color: nil)
            return unless x.between?(@xlo, @xhi) && y.between?(@ylo, @yhi)
            draw_pixel(*to_pixel(x, y).map(&:floor), color)
        end

        def points(xs, ys, color: nil)
            xs.zip(ys).each { |x, y| point(x, y, color: color) }
        end

        def line(x0, y0, x1, y1, color: nil)
            return if out?(x0, x1, @xlo, @xhi) || out?(y0, y1, @ylo, @yhi)
            draw_line(x0, y0, x1, y1, color)
        end

        def lines(xs, ys, color: nil)
            (0...(xs.size - 1)).each do |i|
                line(xs[i], ys[i], xs[i + 1], ys[i + 1], color: color)
            end
        end

        def rows
            Array.new(height) { |r| Array.new(width) { |c| cell_at(r, c) } }
        end

        private

        def blank_code = 0

        def out?(a, b, lo, hi) = (a < lo && b < lo) || (a > hi && b > hi)

        def to_pixel(x, y)
            fx = (x - @xlo).fdiv(@xhi - @xlo) * pixel_width
            fy = pixel_height - ((y - @ylo).fdiv(@yhi - @ylo) * pixel_height)
            [fx, fy]
        end

        def draw_line(x0, y0, x1, y1, color)
            from = to_pixel(x0, y0)
            to = to_pixel(x1, y1)
            draw_pixel(from[0].floor, from[1].floor, color)
            dda(from, to, color)
        end

        def dda(from, to, color)
            dx = to[0] - from[0]
            dy = to[1] - from[1]
            steps = [dx.abs, dy.abs].max
            return if steps.zero?
            step_line(from, [dx.fdiv(steps), dy.fdiv(steps)], steps, color)
        end

        # A running sum, as unicode_plot (from + inc * i rounds apart).
        def step_line(from, inc, steps, color)
            x, y = from
            1.upto(steps) do
                draw_pixel((x += inc[0]).floor, (y += inc[1]).floor, color)
            end
        end

        # color: a name, or a callable of the cell's row and column.
        def draw_pixel(px, py, color)
            return unless px.between?(0, pixel_width) &&
                          py.between?(0, pixel_height)
            x = clip(px, pixel_width)
            y = clip(py, pixel_height)
            set_sub_pixel(x, y, cell_color(color, x, y))
        end

        def cell_color(color, px, py)
            return color unless color.respond_to?(:call) && color.arity == 2

            color.call(py / y_pixel_per_char, px / x_pixel_per_char)
        end

        def clip(v, max) = v == max ? v - 1 : v

        def set_sub_pixel(px, py, color)
            i = cell_index(px, py)
            @grid[i] = encode(@grid[i], px % x_pixel_per_char,
                              py % y_pixel_per_char)
            @colors[i] = color unless color.nil?
        end

        # Overridden by density.rb, D1.
        def cell_index(px, py)
            ((py / y_pixel_per_char) * width) + (px / x_pixel_per_char)
        end

        def cell_at(row, col)
            i = (row * width) + col
            @overlay[i] || Cell.new(char: decode(@grid[i]), color: @colors[i])
        end
    end
end
