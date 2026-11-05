# frozen_string_literal: true

module Tessella
    # Octants for Tessella.image (style: :octant): 2x4 pixels per cell,
    # as braille, but solid -- Unicode 16's Symbols for Legacy
    # Computing Supplement, U+1CD00..1CDE5, so only the newest
    # terminals (Ghostty-class) draw them yet. A pattern's bits are its
    # cells row by row, left then right, top first. The block holds 230
    # patterns in that bit order; the other 26 are glyphs that already
    # existed, listed in EXISTING.
    module Image
        OCTANT_EXISTING = {
            0 => " ", 1 => "\u{1CEA8}", 2 => "\u{1CEAB}", 3 => "\u{1FB82}",
            5 => "▘", 10 => "▝", 15 => "▀", 20 => "\u{1FBE6}",
            40 => "\u{1FBE7}", 63 => "\u{1FB85}", 64 => "\u{1CEA3}",
            80 => "▖", 85 => "▌", 90 => "▞", 95 => "▛", 128 => "\u{1CEA0}",
            160 => "▗", 165 => "▚", 170 => "▐", 175 => "▜", 192 => "▂",
            240 => "▄", 245 => "▙", 250 => "▟", 252 => "▆", 255 => "█"
        }.freeze

        OCTANT = begin
            code = 0x1CD00
            (0..255).map do |bits|
                OCTANT_EXISTING.fetch(bits) do
                    [code].pack("U").tap { code += 1 }
                end
            end.freeze
        end

        # Glyphs#octant: the cell's eight pixels, bit 0 the top left.
        module OctantGlyph
            private

            def octant(cx, cy)
                bits = 0
                (0...4).each do |dy|
                    (0...2).each do |dx|
                        bits |= 1 << ((dy * 2) + dx) if
                            @field.on?((cx * 2) + dx, (cy * 4) + dy)
                    end
                end
                OCTANT[bits]
            end
        end
    end
end
