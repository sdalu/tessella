# frozen_string_literal: true

module Inkchart
    class Canvas
        # 2x2 sub-pixels per cell, packed into the Unicode quadrant
        # block characters (Block Elements / Symbols for Legacy
        # Computing): each of the four Unicode glyphs for a quadrant
        # combination is the only character that means that exact
        # combination, so this table is fixed by the Unicode names,
        # not by any library.
        class Block < Canvas
            TOP_LEFT = 8
            TOP_RIGHT = 4
            BOTTOM_LEFT = 2
            BOTTOM_RIGHT = 1

            BITS = [
                [TOP_LEFT, BOTTOM_LEFT],
                [TOP_RIGHT, BOTTOM_RIGHT]
            ].freeze

            GLYPHS = [
                " ", "▗", "▖", "▄", "▝", "▐", "▞", "▟",
                "▘", "▚", "▌", "▙", "▀", "▜", "▛", "█"
            ].freeze

            private

            def x_pixel_per_char = 2
            def y_pixel_per_char = 2

            def encode(code, sub_x, sub_y) = code | BITS[sub_x][sub_y]
            def decode(code) = GLYPHS[code]
        end

        register(:block, Block)
    end
end
