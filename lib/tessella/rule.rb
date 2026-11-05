# frozen_string_literal: true

module Tessella
    # A divider (DESIGN.md, "Meters and rules"): a line width columns
    # long in a rule style from Glyphs::RULES (light, heavy, double,
    # dashed, ascii), with an optional ornament centred in it by
    # display width and set off by a space on each side --
    # "────────── ✦ ──────────".
    module Rule
        def self.build(width: 78, ornament: nil, style: :light, ascii: false)
            Check.positive_integer!(width, "width")
            line = glyph!(ascii ? :ascii : style)
            return Block.new([line * width]) if ornament.to_s.empty?

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

        def self.ornamented(line, ornament, width)
            middle = " #{ornament} "
            room = width - Width.of(middle)
            if room < 2
                raise ArgumentError, "ornament #{ornament.inspect} needs a " \
                                     "width of #{Width.of(middle) + 2} at least"
            end
            (line * (room / 2)) + middle + (line * (room - (room / 2)))
        end
    end

    # width: 78, ornament: nil, style: :light, ascii: false.
    def self.rule(**) = Rule.build(**)
end
