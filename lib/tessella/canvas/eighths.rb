# frozen_string_literal: true

module Tessella
    class Canvas
        # Eighth blocks, 1x8 sub-pixels per cell, for fills only (an
        # area): a cell reads as filled from its bottom up to its
        # highest pixel -- " ▁▂▃▄▅▆▇█" -- one pixel column per
        # character, eight height steps. A pixel alone in a cell (a
        # line, a dot) would read as a bar under it, so the charts take
        # this canvas only where they fill.
        class Eighths < Canvas
            GLYPHS = " ▁▂▃▄▅▆▇█".chars.freeze

            private

            def x_pixel_per_char = 1
            def y_pixel_per_char = 8

            def encode(code, _sub_x, sub_y) = code | (1 << (7 - sub_y))

            # The highest pixel set, as a height in eighths.
            def decode(code) = GLYPHS[code.bit_length]
        end

        # Eighth blocks across, 8x1: a cell reads as filled from its
        # left edge out to its rightmost pixel -- " ▏▎▍▌▋▊▉█" -- for an
        # area filled sideways.
        class EighthsWide < Canvas
            GLYPHS = " ▏▎▍▌▋▊▉█".chars.freeze

            private

            def x_pixel_per_char = 8
            def y_pixel_per_char = 1

            def encode(code, sub_x, _sub_y) = code | (1 << sub_x)
            def decode(code) = GLYPHS[code.bit_length]
        end

        register(:eighths, Eighths)
        register(:eighths_wide, EighthsWide)
    end
end
