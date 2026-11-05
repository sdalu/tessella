# frozen_string_literal: true

module AsciiArt
    class Canvas
        # 2x4 sub-pixels per cell, packed into the Unicode Braille
        # Patterns block: dot n sets bit 2**(n-1) of the base U+2800,
        # dots 1/2/3/7 in the left column (top to bottom), 4/5/6/8 in
        # the right -- the Unicode standard's own dot layout, so this
        # table is fixed by the codepoint scheme, not by any library.
        class Braille < Canvas
            BITS = [
                [0x01, 0x02, 0x04, 0x40],
                [0x08, 0x10, 0x20, 0x80]
            ].freeze

            private

            def x_pixel_per_char = 2
            def y_pixel_per_char = 4

            def encode(code, sub_x, sub_y) = code | BITS[sub_x][sub_y]

            def decode(code)
                code.zero? ? " " : [0x2800 | code].pack("U")
            end
        end

        register(:braille, Braille)
    end
end
