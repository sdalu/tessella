# frozen_string_literal: true

module Tessella
    # Text styles (DESIGN.md, "Text styles"): plain letters and digits
    # to the Unicode forms of a style -- bold, italic, script, fraktur,
    # double-struck, sans, monospace, small caps, superscript,
    # subscript, circled, parenthesized, squared, fullwidth -- and back
    # (style: :plain). A character the style has no form for passes
    # through unchanged; strict: true refuses the text instead, naming
    # them. Only letters and digits count as missing: punctuation and
    # spaces are expected to pass. Small caps keep capitals as they
    # are; the styles with capitals only use them for small letters
    # too. Every style is non-ASCII, so ascii: true refuses them all.
    # The output is text, measured by Width like any other: fullwidth
    # is two columns a glyph.
    module Text
        CAPITALS_ONLY = %i[squared negative_circled negative_squared].freeze
        STYLES = (FORMS.keys + %i[plain]).freeze

        def self.convert(text, style:, strict: false, ascii: false)
            name = style!(style)
            raise ArgumentError, "text styles are not ASCII" if ascii

            missing = unmapped(text, name)
            if strict && !missing.empty?
                raise ArgumentError, "no #{dashed(name)} form for: " \
                                     "#{missing.join(" ")}"
            end
            text.to_s.each_char.map { form(it, name) }.join
        end

        # The letters and digits of text the style has no form for.
        def self.unmapped(text, style)
            name = style!(style)
            return [] if name == :plain

            text.to_s.each_char.select do |ch|
                ch.match?(/[A-Za-z0-9]/) && form(ch, name) == ch &&
                    !(name == :small_caps && ch.match?(/[A-Z]/))
            end.uniq
        end

        def self.dashed(name) = name.to_s.tr("_", "-")

        def self.style!(style)
            name = Borders.name(style)
            return name if STYLES.include?(name)

            raise ArgumentError, "unknown text style: #{style.inspect} " \
                                 "(#{STYLES.join(", ").tr("_", "-")})"
        end

        def self.form(char, name)
            return plain_map.fetch(char, char) if name == :plain

            key = CAPITALS_ONLY.include?(name) ? char.upcase : char
            map(name).fetch(key, char)
        end

        def self.map(name)
            (@maps ||= {})[name] ||= FORMS.fetch(name).then do |form|
                form[:from].chars.zip(form[:to].chars).to_h
            end
        end

        # Every style's forms back to their plain characters.
        def self.plain_map
            @plain_map ||= FORMS.keys.each_with_object({}) do |name, back|
                map(name).each { |plain, styled| back[styled] ||= plain }
            end
        end
    end

    # (text, style:, strict: false, ascii: false) => String.
    def self.text(text, **) = Text.convert(text, **)
end
