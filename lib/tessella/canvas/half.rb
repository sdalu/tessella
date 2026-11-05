# frozen_string_literal: true

module Tessella
    class Canvas
        # Half blocks, 1x2 sub-pixels per cell: the upper half, the
        # lower, or both -- "▀", "▄", "█" -- one pixel column per
        # character, two rows. A column chart's columns rise by half a
        # cell; an area fills by halves.
        class Half < Canvas
            TOP = 1
            BOTTOM = 2

            GLYPHS = [" ", "▀", "▄", "█"].freeze

            private

            def x_pixel_per_char = 1
            def y_pixel_per_char = 2

            def encode(code, _sub_x, sub_y)
                code | (sub_y.zero? ? TOP : BOTTOM)
            end

            def decode(code) = GLYPHS[code]
        end

        # Half blocks across, 2x1 sub-pixels per cell: the left half,
        # the right, or both -- "▌", "▐", "█" -- so a horizontal bar
        # grows by half a cell, one bar per text row.
        class HalfWide < Canvas
            LEFT = 1
            RIGHT = 2

            GLYPHS = [" ", "▌", "▐", "█"].freeze

            private

            def x_pixel_per_char = 2
            def y_pixel_per_char = 1

            def encode(code, sub_x, _sub_y)
                code | (sub_x.zero? ? LEFT : RIGHT)
            end

            def decode(code) = GLYPHS[code]
        end

        register(:half, Half)
        register(:half_wide, HalfWide)
    end
end
