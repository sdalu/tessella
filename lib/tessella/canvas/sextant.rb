# frozen_string_literal: true

module Tessella
    class Canvas
        # Teletext sextants, 2x3 sub-pixels per cell, solid where
        # braille is dotted: Unicode 13's Symbols for Legacy Computing
        # (U+1FB00..1FB3B, with ▌ ▐ █ for the halves and the whole),
        # Image::SEXTANT's table. Bit (row * 2 + column), top left 1.
        class Sextant < Canvas
            private

            def x_pixel_per_char = 2
            def y_pixel_per_char = 3

            def encode(code, sub_x, sub_y) = code | (1 << ((sub_y * 2) + sub_x))
            def decode(code) = Image::SEXTANT[code]
        end

        # Octants, 2x4 sub-pixels per cell: braille's resolution,
        # solid -- Unicode 16 (U+1CD00..1CDE5 and older glyphs for the
        # patterns that had one), Image::OCTANT's table, so only the
        # newest terminals draw them.
        class Octant < Canvas
            private

            def x_pixel_per_char = 2
            def y_pixel_per_char = 4

            def encode(code, sub_x, sub_y) = code | (1 << ((sub_y * 2) + sub_x))
            def decode(code) = Image::OCTANT[code]
        end

        register(:sextant, Sextant)
        register(:octant, Octant)
    end
end
