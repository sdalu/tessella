# frozen_string_literal: true

module Tessella
    class Canvas
        # A segment far longer than the canvas (a spike past ylim:)
        # steps only where it crosses the canvas: stepping it all, one
        # rejected pixel at a time, took minutes for a value a million
        # times the limits. Shorter segments keep the running sum, and
        # so unicode_plot's exact pixels.
        module Clip
            private

            def long?(steps) = steps > 2 * (pixel_width + pixel_height)

            def clipped_line(from, inc, steps, color)
                first, last = on_canvas(from, inc, steps)
                first.upto(last) do |i|
                    draw_pixel((from[0] + (inc[0] * i)).floor,
                               (from[1] + (inc[1] * i)).floor, color)
                end
            end

            # The steps [first, last] at which both coordinates are on
            # the canvas, a pixel of margin either side.
            def on_canvas(from, inc, steps)
                x = span(from[0], inc[0], pixel_width)
                y = span(from[1], inc[1], pixel_height)
                within([x[0], y[0]].max, [x[1], y[1]].min, steps)
            end

            def within(first, last, steps)
                [first.clamp(1, steps.ceil), last.clamp(0, steps.floor)]
            end

            def span(start, inc, size)
                return flat_span(start, size) if inc.zero?

                a, b = [(-1 - start) / inc, (size + 1 - start) / inc].minmax
                [a.floor, b.ceil]
            end

            def flat_span(start, size)
                start.between?(-1, size + 1) ? [0, Float::INFINITY] : [1, 0]
            end
        end

        include Clip
    end
end
