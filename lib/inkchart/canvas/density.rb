# frozen_string_literal: true

module Inkchart
    class Canvas
        # 1x2 sub-pixels per cell; the glyph is chosen by hit count
        # relative to the densest cell on the canvas, not by position
        # (DESIGN.md, Canvas). ascii: true swaps the default shade
        # ramp for an ASCII one (brief rules).
        class Density < Canvas
            SIGNS = [" ", "░", "▒", "▓", "█"].freeze
            ASCII_SIGNS = [" ", ".", ":", "+", "#"].freeze

            def initialize(width, height, xlim:, ylim:, ascii: false)
                @signs = ascii ? ASCII_SIGNS : SIGNS
                @max_density = 1
                super(width, height, xlim: xlim, ylim: ylim)
            end

            private

            def x_pixel_per_char = 1
            def y_pixel_per_char = 2

            # The oracle maps a pixel to its cell by floor(float
            # round-trip), not exact integer division, and this can
            # round a whole pixel short at some widths/heights (e.g.
            # 13.fdiv(23) * 23 == 12.999999999999998, D1). Matched
            # here verbatim for byte parity rather than "fixed", since
            # the oracle's own output is what rendering must match.
            def cell_index(px, py)
                cx = (px.fdiv(pixel_width) * width).floor
                cy = (py.fdiv(pixel_height) * height).floor
                (cy * width) + cx
            end

            def encode(code, _sub_x, _sub_y)
                count = code + 1
                @max_density = count if count > @max_density
                count
            end

            def decode(code)
                return " " if code.zero?
                scale = (@signs.size - 1).fdiv(@max_density)
                @signs[(code * scale).round]
            end
        end

        register(:density, Density)
    end
end
