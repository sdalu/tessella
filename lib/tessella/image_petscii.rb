# frozen_string_literal: true

module Tessella
    # PETSCII-style pictures for Tessella.image (style: :petscii): each
    # cell is sampled as 4x8 tones and drawn with the glyph whose shape
    # fits them best (least squared error), from a set in the spirit of
    # the Commodore character ROM -- blocks, halves and quadrants,
    # quarter and three-quarter blocks on every side (the upper and
    # right ones from Symbols for Legacy Computing), eighth-lines,
    # diagonal triangles and lines, shades, line pieces, discs. The
    # shape a glyph draws is a function of the cell's x and y (0..1, y
    # down), so the set is one table. Threshold and dither do
    # not apply: the match reads tones, not on/off pixels.
    module Image
        HLINE = ->(_x, y) { (y - 0.5).abs < 0.13 }
        VLINE = ->(x, _y) { (x - 0.5).abs < 0.26 }

        PETSCII_SHAPES = {
            " " => ->(_x, _y) { false }, "█" => ->(_x, _y) { true },
            "▀" => ->(_x, y) { y < 0.5 }, "▄" => ->(_x, y) { y >= 0.5 },
            "▌" => ->(x, _y) { x < 0.5 }, "▐" => ->(x, _y) { x >= 0.5 },
            "▘" => ->(x, y) { x < 0.5 && y < 0.5 },
            "▝" => ->(x, y) { x >= 0.5 && y < 0.5 },
            "▖" => ->(x, y) { x < 0.5 && y >= 0.5 },
            "▗" => ->(x, y) { x >= 0.5 && y >= 0.5 },
            "▚" => ->(x, y) { (x < 0.5) == (y < 0.5) },
            "▞" => ->(x, y) { (x < 0.5) != (y < 0.5) },
            "▙" => ->(x, y) { x < 0.5 || y >= 0.5 },
            "▛" => ->(x, y) { x < 0.5 || y < 0.5 },
            "▜" => ->(x, y) { x >= 0.5 || y < 0.5 },
            "▟" => ->(x, y) { x >= 0.5 || y >= 0.5 },
            "▏" => ->(x, _y) { x < 0.25 }, "▕" => ->(x, _y) { x >= 0.75 },
            "▔" => ->(_x, y) { y < 0.125 }, "▁" => ->(_x, y) { y >= 0.875 },
            "▊" => ->(x, _y) { x < 0.75 },
            "\u{1FB8A}" => ->(x, _y) { x >= 0.25 },
            "▂" => ->(_x, y) { y >= 0.75 }, "▆" => ->(_x, y) { y >= 0.25 },
            "\u{1FB82}" => ->(_x, y) { y < 0.25 },
            "\u{1FB85}" => ->(_x, y) { y < 0.75 },
            "◢" => ->(x, y) { x + y >= 1 }, "◣" => ->(x, y) { y >= x },
            "◤" => ->(x, y) { x + y < 1 }, "◥" => ->(x, y) { x > y },
            "╱" => ->(x, y) { (x + y - 1).abs < 0.22 },
            "╲" => ->(x, y) { (x - y).abs < 0.22 },
            "╳" => ->(x, y) { (x + y - 1).abs < 0.22 || (x - y).abs < 0.22 },
            "─" => HLINE, "│" => VLINE,
            "┼" => ->(x, y) { HLINE.call(x, y) || VLINE.call(x, y) },
            "┌" => ->(x, y) { corner(x, y, x >= 0.375, y >= 0.4375) },
            "┐" => ->(x, y) { corner(x, y, x < 0.625, y >= 0.4375) },
            "└" => ->(x, y) { corner(x, y, x >= 0.375, y < 0.5625) },
            "┘" => ->(x, y) { corner(x, y, x < 0.625, y < 0.5625) },
            "├" => lambda { |x, y|
                VLINE.call(x, y) || (HLINE.call(x, y) && x >= 0.375)
            },
            "┤" => lambda { |x, y|
                VLINE.call(x, y) || (HLINE.call(x, y) && x < 0.625)
            },
            "┬" => lambda { |x, y|
                HLINE.call(x, y) || (VLINE.call(x, y) && y >= 0.4375)
            },
            "┴" => lambda { |x, y|
                HLINE.call(x, y) || (VLINE.call(x, y) && y < 0.5625)
            },
            "●" => ->(x, y) { disc(x, y) < 0.42 },
            "○" => ->(x, y) { disc(x, y).between?(0.25, 0.45) }
        }.freeze

        # A corner piece: the horizontal run on one side, the vertical
        # on the other.
        def self.corner(x, y, across, down)
            (HLINE.call(x, y) && across) || (VLINE.call(x, y) && down)
        end

        # Distance from the cell's centre, x counted half as much: the
        # cell is twice as tall as wide, so this is a round disc.
        def self.disc(x, y) = Math.hypot((x - 0.5) * 0.5, y - 0.5)

        PETSCII_SUB = [4, 8].freeze

        # Each glyph's shape as 4x8 ink (1.0) or paper (0.0), row by
        # row, plus the shades as flat tones.
        PETSCII = begin
            sw, sh = PETSCII_SUB
            shapes = PETSCII_SHAPES.transform_values do |shape|
                (0...sh).flat_map do |y|
                    (0...sw).map do |x|
                        shape.call((x + 0.5) / sw, (y + 0.5) / sh) ? 1.0 : 0.0
                    end
                end
            end
            shades = { "░" => 0.25, "▒" => 0.5, "▓" => 0.75 }
                     .transform_values { Array.new(sw * sh, it) }
            shapes.merge(shades).freeze
        end

        # Glyphs#petscii: the glyph of least squared error over the
        # cell's 4x8 tones.
        module PetsciiGlyph
            private

            def petscii(cx, cy)
                tones = petscii_tones(cx, cy)
                PETSCII.min_by do |_, ink|
                    ink.each_with_index.sum { |v, i| (v - tones[i])**2 }
                end.first
            end

            def petscii_tones(cx, cy)
                sw, sh = PETSCII_SUB
                (0...sh).flat_map do |y|
                    (0...sw).map do |x|
                        @field.level((cx * sw) + x, (cy * sh) + y)
                    end
                end
            end
        end
    end
end
