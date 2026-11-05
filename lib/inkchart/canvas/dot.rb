# frozen_string_literal: true

module Inkchart
    class Canvas
        # 1x2 sub-pixels per cell: the top pixel alone draws a raised
        # mark, the bottom alone a mark on the baseline, both a colon.
        class Dot < Canvas
            TOP = 2
            BOTTOM = 1

            GLYPHS = [" ", ".", "'", ":"].freeze

            private

            def x_pixel_per_char = 1
            def y_pixel_per_char = 2

            def encode(code, _sub_x, sub_y)
                code | (sub_y.zero? ? TOP : BOTTOM)
            end

            def decode(code) = GLYPHS[code]
        end

        register(:dot, Dot)
    end
end
