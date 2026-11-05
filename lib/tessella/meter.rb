# frozen_string_literal: true

module Tessella
    # A one-line meter (DESIGN.md, "Meters and rules"): a progress bar
    # or gauge, as the ascii-art skill's ui.md draws one --
    # "[██████······] 50 %". The fill/track pair is a style from
    # Glyphs::METERS or glyphs of one's own, of one width class; the
    # block style fills its last cell by eighths. title: goes before
    # the bar, the percentage after it unless label: false;
    # title_width: pads the title to that many columns, so meters with
    # titles of different lengths line up. orientation: :vertical
    # stands the bar up (MeterUpright).
    module Meter
        EIGHTHS = " ▏▎▍▌▋▊▉".chars.freeze

        DEFAULTS = { style: :block, title: nil, label: true,
                     brackets: true, ascii: false, title_width: nil }.freeze

        # orientation: :horizontal takes width: (20), :vertical height:
        # (8); the other is refused.
        def self.build(fraction, orientation: :horizontal, **opts)
            share = fraction!(fraction)
            opts = sized!(orientation,
                          DEFAULTS.merge(ascii: Target.ascii?, **opts))
            return MeterUpright.build(share, opts) if orientation == :vertical

            Block.new([line(share, opts)])
        end

        def self.sized!(orientation, opts)
            sizes = { horizontal: [:width, 20], vertical: [:height, 8] }
            own, default = sizes.fetch(orientation) do
                raise ArgumentError, "orientation must be :horizontal or " \
                                     ":vertical: #{orientation.inspect}"
            end
            other = (%i[width height] - [own]).first
            raise ArgumentError, "a #{orientation} meter takes no #{other}:" if
                opts.key?(other)

            opts.merge(own => opts.fetch(own, default))
        end

        def self.line(share, opts)
            Check.positive_integer!(opts[:width], "width")
            bar = bar(share, opts[:width], glyphs(opts), eighths?(opts))
            [title_of(opts), opts[:brackets] ? "[#{bar}]" : bar,
             (percent(share) if opts[:label])].compact.join(" ")
        end

        # [fill, track]: the style's, or classic's under ascii:.
        def self.glyphs(opts)
            pair!(opts[:ascii] ? :classic : opts[:style], opts[:ascii])
        end

        def self.title_of(opts)
            opts[:title] && title!(opts[:title], opts[:title_width],
                                   opts[:ascii])
        end

        def self.eighths?(opts)
            Borders.name(opts[:style]) == :block && !opts[:ascii]
        end

        # The title, padded to title_width: columns when given.
        def self.title!(title, title_width, ascii)
            text = Compose.text!("title", title, ascii)
            return text unless title_width

            Check.positive_integer!(title_width, "title_width")
            if Width.of(text) > title_width
                raise ArgumentError, "title #{text.inspect} is wider than " \
                                     "title_width #{title_width}"
            end
            Width.ljust(text, title_width)
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

        def self.bar(share, width, glyphs, eighths)
            fill, track = glyphs
            units = (share * width * (eighths ? 8 : 1)).round
            full, rem = eighths ? units.divmod(8) : [units, 0]
            cells = (fill * full) + (rem.zero? ? "" : EIGHTHS[rem])
            cells + (track * (width - Width.of(cells)))
        end

        def self.percent(share) = "#{(share * 100).round} %"
    end

    # fraction (0..1, or "45%"), style: :block, width: 20, title: nil,
    # label: true, brackets: true, ascii: false, title_width: nil,
    # orientation: :horizontal (:vertical takes height: 8 instead).
    def self.meter(fraction, **) = Meter.build(fraction, **)
end
