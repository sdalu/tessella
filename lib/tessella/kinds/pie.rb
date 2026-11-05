# frozen_string_literal: true

module Tessella
    # A pie, or with donut: true a ring (DESIGN.md, "Chart and kinds"):
    # labels and values as slices clockwise from the top, drawn on
    # character cells twice as wide as tall, so the disc reads round in
    # a terminal. Slices are told apart by fill -- █ ▓ ▒ ░ ╳ ╱ ╲ ∴ ● ○ ◆
    # ·, one width class, or # = + @ * : . o % & ~ x in ASCII, so at
    # most 12 slices -- and, under color: true, by colour. The legend
    # right of the disc gives each slice's share, or under it, wrapped
    # to 40 columns or the disc's width, when the slices outnumber the
    # rows. height: (12 by default) sets the size, so width: is
    # refused. Values must be 0 or more, and not all 0. rim: :smooth
    # draws the edge to the shape (PieRim).
    class Pie < Chart
        include PieRim

        OPTIONS = (Chart::OPTIONS - %i[width xlim ylim canvas xscale] +
                   %i[donut rim]).freeze
        HOLE = 0.5
        LEGEND = 40

        def add(labels, values)
            @labels = Array(labels).map(&:to_s)
            @values = Check.finite!(Array(values), "value")
            Check.same_size!(@labels, @values, %w[labels values])
            values!
            self
        end

        private

        def values!
            unless @values.all? { it >= 0 } && @values.sum.positive?
                raise ValueError, "pie values must be 0 or more, not all 0"
            end
            Legend.fills!(@values.size, "slices")
        end

        def default_border = :none
        def height = @opts.fetch(:height, 12)
        def fill(i) = (@ascii ? Legend::ASCII_FILLS : Legend::FILLS)[i]
        def slice_color(i) = Color::NAMES[i % Color::NAMES.size]

        # Where each slice ends, as a share of the turn.
        def ends
            total = @values.sum.to_f
            @values.each_index.map { @values[0..it].sum / total }
        end

        def body
            w = height * 2
            stops = ends
            (0...height).map do |y|
                (0...w).map { |x| disc_cell(x, y, w, stops) }
            end
        end

        def disc_cell(x, y, w, stops)
            dx = offset(x, w)
            dy = offset(y, height)
            i = slice_at(turn(dx, dy), stops)
            cell = rim? ? rim_cell(x, y, w, i) : whole_cell(dx, dy)
            cell || Cell.new(char: fill(i), color: slice_color(i))
        end

        # A cell in or out by its centre: blank, or nil for its fill.
        def whole_cell(dx, dy)
            r = Math.hypot(dx, dy)
            Cell.blank if r > 1 || (@opts[:donut] && r < HOLE)
        end

        # A cell's centre from the disc's, in radii.
        def offset(cell, cells) = (cell + 0.5 - (cells / 2.0)) / (cells / 2.0)

        # 0 at the top, clockwise, as a share of the turn.
        def turn(dx, dy) = (Math.atan2(dx, -dy) / (2 * Math::PI)) % 1.0

        def slice_at(share, stops)
            stops.index { share < it } || (stops.size - 1)
        end

        def frame
            Frame.new(body: body, border: @border, ascii: @ascii,
                      color: @color_on, title: @opts[:title],
                      xlabel: @opts[:xlabel], ylabel: @opts[:ylabel],
                      **legend)
        end

        # The legend beside the disc, centred, or under it, wrapped,
        # when there are more slices than rows.
        def legend
            rows = legend_entries
            return { under: Legend.wrap(rows, [height * 2, LEGEND].max) } if
                rows.size > height

            first = (height - rows.size) / 2
            { right: rows.each_with_index.to_h { |text, i| [first + i, text] } }
        end

        def legend_entries
            percents = shares
            @labels.each_with_index.map do |label, i|
                "#{fill(i)} #{label} #{percents[i]} %"
            end
        end

        # Whole percents summing to 100: floors, the rest handed out by
        # largest remainder.
        def shares
            exact = @values.map { it * 100.0 / @values.sum }
            whole = exact.map(&:floor)
            order = exact.each_index.sort_by { whole[it] - exact[it] }
            order.first(100 - whole.sum).each { whole[it] += 1 }
            whole
        end
    end

    # (labels, values, donut: false, **opts): a new Pie.
    def self.pie(labels, values, **)
        Pie.new(**).add(labels, values)
    end
end
