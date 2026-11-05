# frozen_string_literal: true

module Tessella
    # A one-line meter (DESIGN.md, "Meters and rules"): a progress bar
    # or gauge, as the ascii-art skill's ui.md draws one --
    # "[██████······] 50 %". The fill/track pair is a style from
    # Glyphs::METERS or glyphs of one's own, of one width class; the
    # block style fills its last cell by eighths. title: goes before
    # the bar, the percentage after it unless label: false.
    module Meter
        EIGHTHS = " ▏▎▍▌▋▊▉".chars.freeze

        # rubocop:disable-next Metrics/ParameterLists
        def self.build(fraction, style: :block, width: 20, title: nil,
                       label: true, brackets: true, ascii: false)
            share = fraction!(fraction)
            Check.positive_integer!(width, "width")
            fill, track = pair!(ascii ? :classic : style, ascii)
            bar = bar(share, width, fill, track, style == :block && !ascii)
            line = [title && Compose.text!("title", title, ascii),
                    brackets ? "[#{bar}]" : bar,
                    (percent(share) if label)].compact.join(" ")
            Block.new([line])
        end

        # A number 0..1, or a String "45%" / "0.45".
        def self.fraction!(value)
            number = value.is_a?(String) ? parse(value) : value
            return number.to_f if number.is_a?(Numeric) &&
                                  number.to_f.between?(0.0, 1.0)

            raise ArgumentError, "fraction must be 0..1 or 0%..100%: " \
                                 "#{value.inspect}"
        end

        def self.parse(text)
            return Float(text.delete_suffix("%"), exception: false)&./(100) if
                text.end_with?("%")

            Float(text, exception: false)
        end

        # [fill, track] from a style name or two glyphs of one's own.
        def self.pair!(style, ascii)
            key = Borders.name(style)
            glyphs = Glyphs::METERS.fetch(key) { style.to_s }.chars
            unless glyphs.size == 2
                raise ArgumentError, "unknown meter style: #{style.inspect} " \
                                     "(#{Glyphs::METERS.keys.join(", ")}, " \
                                     "or a fill and a track glyph)"
            end
            same_class!(glyphs, style)
            glyphs.each { Compose.text!("meter glyph", it, ascii) }
        end

        def self.same_class!(glyphs, style)
            classes = Width.classes(glyphs.join)
            return if classes.size <= 1

            raise ArgumentError, "meter style #{style.inspect} mixes width " \
                                 "classes: #{classes.join(", ")}"
        end

        def self.bar(share, width, fill, track, eighths)
            units = (share * width * (eighths ? 8 : 1)).round
            full, rem = eighths ? units.divmod(8) : [units, 0]
            cells = (fill * full) + (rem.zero? ? "" : EIGHTHS[rem])
            cells + (track * (width - Width.of(cells)))
        end

        def self.percent(share) = "#{(share * 100).round} %"
    end

    # fraction (0..1, or "45%"), style: :block, width: 20, title: nil,
    # label: true, brackets: true, ascii: false.
    def self.meter(fraction, **) = Meter.build(fraction, **)
end
