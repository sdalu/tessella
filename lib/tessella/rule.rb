# frozen_string_literal: true

module Tessella
    # A divider (DESIGN.md, "Meters and rules"): a line width columns
    # long in a rule style from Glyphs::RULES (light, heavy, double,
    # dashed, ascii), with an optional ornament centred in it by
    # display width and set off by a space on each side --
    # "────────── ✦ ──────────".
    module Rule
        def self.build(width: 78, ornament: nil, style: :light,
                       ascii: Target.ascii?)
            Check.positive_integer!(width, "width")
            line = glyph!(ascii ? :ascii : style)
            return Block.new([Width.run(line, width)]) if ornament.to_s.empty?

            Block.new([ornamented(line, ornament!(ornament, ascii), width)])
        end

        def self.glyph!(style)
            Glyphs::RULES.fetch(Borders.name(style)) do
                raise ArgumentError, "unknown rule style: #{style.inspect} " \
                                     "(#{Glyphs::RULES.keys.join(", ")})"
            end
        end

        def self.ornament!(ornament, ascii)
            Compose.text!("ornament", ornament.to_s, ascii)
        end

        # The ornament centred, the line in whole glyphs either side (a
        # blank more after the ornament when a two-column glyph, under
        # :cjk, would otherwise end half a glyph short).
        def self.ornamented(line, ornament, width)
            unit = Width.of(line)
            middle = middle(ornament, width, unit)
            room = width - Width.of(middle)
            room!(ornament, middle, room, unit)
            left = (room / unit / 2) * unit
            Width.run(line, left) + middle + Width.run(line, room - left)
        end

        def self.middle(ornament, width, unit)
            middle = " #{ornament} "
            middle += " " until ((width - Width.of(middle)) % unit).zero?
            middle
        end

        def self.room!(ornament, middle, room, unit)
            return if room >= 2 * unit

            least = Width.of(middle) + (2 * unit)
            raise ArgumentError, "ornament #{ornament.inspect} needs a " \
                                 "width of #{least} at least"
        end
    end

    # width: 78, ornament: nil, style: :light, ascii: false.
    def self.rule(**) = Rule.build(**)
end
