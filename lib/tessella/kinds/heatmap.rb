# frozen_string_literal: true

module Tessella
    # A heatmap (DESIGN.md, "Chart and kinds"): a matrix of values as a
    # grid of cells, each cell_width: columns wide (2 by default, near
    # square in a terminal), shaded by value -- along a ramp (" ░▒▓█",
    # ASCII " .:-=+*#%@") without colour, or as █ coloured along a
    # colormap under color: true (a viridis-like blend by default;
    # colormap: takes gradient stops as Color does). Rows are named by
    # ylabels: on the left, columns by xlabels: under the frame when
    # they fit, and a key right of the frame gives the range. min: and
    # max: fix the range, so maps drawn apart share one scale. The
    # matrix sets the size, so width: and height: are refused.
    class Heatmap < Chart
        OPTIONS = (Chart::OPTIONS - %i[width height xlim ylim canvas xscale] +
                   %i[xlabels ylabels cell_width colormap min max]).freeze
        RAMP = " ░▒▓█"
        ASCII_RAMP = " .:-=+*#%@"
        VIRIDIS = %w[#440154 #3b528b #21918c #5ec962 #fde725].freeze

        def add(matrix)
            rows = Array(matrix).map { Check.finite!(Array(it), "value") }
            if rows.empty? || rows.map(&:size).uniq.size != 1 || rows[0].empty?
                raise ArgumentError, "a heatmap needs rows of one length"
            end
            @matrix = rows
            check_colormap!
            self
        end

        private

        def default_border = :box

        def cell_width
            Check.positive_integer!(@opts.fetch(:cell_width, 2), "cell_width")
        end

        def ramp = @ascii ? ASCII_RAMP : RAMP
        def colormap = @opts.fetch(:colormap, VIRIDIS)

        def check_colormap!
            Color::Gradient.check!(colormap) if @opts.key?(:colormap)
        end

        def range
            values = @matrix.flatten
            lo = @opts.fetch(:min, values.min)
            hi = @opts.fetch(:max, values.max)
            Check.finite!([lo, hi], "min/max")
            raise ArgumentError, "min #{lo} is above max #{hi}" if lo > hi

            [lo, hi]
        end

        # 0..1 for v within the range; the middle when it is flat.
        def share(v, lo, hi)
            hi == lo ? 0.5 : (v.clamp(lo, hi) - lo).fdiv(hi - lo)
        end

        def heat_cell(v, lo, hi)
            s = share(v, lo, hi)
            if @color_on
                color = Color::Gradient.at(colormap, (s * 255).round, 256)
                return Cell.new(char: @ascii ? "#" : "█", color: color)
            end
            Cell.new(char: ramp[(s * (ramp.length - 1)).round], color: nil)
        end

        def body
            lo, hi = range
            @matrix.map do |row|
                row.flat_map do |v|
                    Array.new(cell_width) { heat_cell(v, lo, hi) }
                end
            end
        end

        def frame
            Frame.new(**heat_options)
        end

        def heat_options
            { body: body, border: @border, ascii: @ascii, color: @color_on,
              title: @opts[:title], xlabel: @opts[:xlabel],
              ylabel: @opts[:ylabel], left: row_names, right: key,
              **column_names }
        end

        def row_names
            Array(@opts[:ylabels]).each_with_index.to_h { |n, i| [i, n.to_s] }
        end

        # The key: the top of the range beside the first row, the bottom
        # beside the last, each after its own shade.
        # A one-row map shows the range as lo..hi instead.
        def key
            lo, hi = range
            last = @matrix.size - 1
            return { 0 => "#{Axis.label(lo)}..#{Axis.label(hi)}" } if
                last.zero?

            { 0 => "#{key_glyph(hi, lo, hi)} #{Axis.label(hi)}",
              last => "#{key_glyph(lo, lo, hi)} #{Axis.label(lo)}" }
        end

        # The key's shade; words under colour, as the key itself is not
        # coloured.
        def key_glyph(v, lo, hi)
            return v == hi ? "max" : "min" if @color_on

            heat_cell(v, lo, hi).char
        end

        def column_names
            names = Array(@opts[:xlabels]).map(&:to_s)
            return {} if names.empty?
            return { bottom: [names.first, names.last] } unless
                names.all? { Width.of(it) < cell_width }

            { under: names.map { Width.center(it, cell_width) }.join.rstrip }
        end
    end

    # (matrix, xlabels: nil, ylabels: nil, cell_width: 2, colormap: nil,
    # min: nil, max: nil, **opts): a new Heatmap.
    def self.heatmap(matrix, **)
        Heatmap.new(**).add(matrix)
    end
end
