# frozen_string_literal: true

module Tessella
    # orientation: :vertical for Box: each box three columns wide, the
    # whiskers running up and down, the value axis on the left (top,
    # middle and bottom ticks), the names under the boxes. Rows from
    # the top: a cap at the maximum, the whisker, the box from Q3 to
    # Q1 with the median across it, the whisker, a cap at the minimum.
    # When two of them land on one row, the later in that order wins,
    # so the median always shows. Kept apart from Box so Box's own
    # class body stays under budget.
    module UprightBoxes
        UPRIGHT = {
            cap_top: "╶┬╴", cap_bottom: "╶┴╴", whisker: " │ ",
            side: "│ │", q3: "┌┴┐", q1: "└┬┘", median: "├─┤"
        }.freeze

        UPRIGHT_ASCII = {
            cap_top: "-+-", cap_bottom: "-+-", whisker: " | ",
            side: "| |", q3: "+-+", q1: "+-+", median: "|-|"
        }.freeze

        private

        def upright? = @orientation == :vertical

        def upright_options
            lo, hi = upright_limits
            slot = upright_slot
            { body: upright_body(lo, hi, slot), border: :box, ascii: @ascii,
              color: @color_on, title: @opts[:title], xlabel: @opts[:xlabel],
              ylabel: @opts[:ylabel], left: upright_ticks(lo, hi),
              under: upright_names(slot) }
        end

        def upright_limits
            values = @boxes.flat_map { |_, sample, _| sample }
            Axis.limits(values, @opts[:ylim])
        end

        def upright_height = @opts.fetch(:height, Chart::DEFAULT_HEIGHT)

        # Three columns and a gap, wider when a name needs it.
        def upright_slot
            names = @boxes.map { |name, *| Width.of(name) }
            [names.max.to_i + 1, 4].max
        end

        def upright_body(lo, hi, slot)
            rows = Array.new(upright_height) { [] }
            @boxes.each do |_, sample, color|
                glyphs = upright_column(sample, lo, hi)
                pad = (slot - 3) / 2
                rows.each_with_index do |row, r|
                    row.concat(upright_cells(glyphs[r], pad, slot, color))
                end
            end
            rows
        end

        def upright_cells(glyphs, pad, slot, color)
            text = (" " * pad) + glyphs + (" " * (slot - pad - 3))
            text.chars.map do |ch|
                ch == " " ? Cell.blank : Cell.new(char: ch, color: color)
            end
        end

        # One three-character string per row, top first.
        def upright_column(sample, lo, hi)
            at = Stats.percentiles(sample, [100, 75, 50, 25, 0])
                      .map { upright_row(it, lo, hi) }
            column = Array.new(upright_height, "   ")
            upright_marks(at).each do |(from, to), part|
                (from..to).each { column[it] = upright_glyphs[part] }
            end
            column
        end

        # Row spans in paint order: whiskers, caps, box sides, the box
        # edges, the median last.
        def upright_marks(at)
            max, q3, med, q1, min = at
            [[[max, q3], :whisker], [[q1, min], :whisker],
             [[max, max], :cap_top], [[min, min], :cap_bottom],
             [[q3, q1], :side], [[q3, q3], :q3], [[q1, q1], :q1],
             [[med, med], :median]]
        end

        def upright_glyphs = @ascii ? UPRIGHT_ASCII : UPRIGHT

        def upright_row(value, lo, hi)
            share = (hi - value).fdiv(hi - lo)
            (share * (upright_height - 1)).round.clamp(0, upright_height - 1)
        end

        def upright_ticks(lo, hi)
            last = upright_height - 1
            { 0 => Axis.tick(hi), (last / 2) => Axis.tick((lo + hi) / 2.0),
              last => Axis.tick(lo) }
        end

        def upright_names(slot)
            @boxes.map { |name, *| Width.center(name, slot) }.join.rstrip
        end
    end

    class Box
        include UprightBoxes
    end
end
