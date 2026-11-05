# frozen_string_literal: true

module Tessella
    module Lint
        # What a text is made of (Tessella.alphabet), so the character
        # policy is decided by measurement before a figure is drawn:
        # "ascii", or "utf-8" and each glyph class present with its
        # count, box-drawing first, and up to five unclassified glyphs
        # by code point. Invalid bytes are a class of their own, not
        # scrubbed away: a Latin-1 file is not ASCII either.
        module Alphabet
            CLASSES = {
                "box-drawing" => 0x2500..0x257F,
                "blocks" => 0x2580..0x259F,
                "geometric" => 0x25A0..0x25FF,
                "arrows" => 0x2190..0x21FF,
                "braille" => 0x2800..0x28FF
            }.freeze

            def self.of(text)
                seen = Hash.new(0)
                other = {}
                text.each_char { tally(it, seen, other) }
                return "ascii" if seen.empty? && other.empty?

                "utf-8 #{parts(seen, other).join(" ")}"
            end

            def self.tally(ch, seen, other)
                return seen["invalid-utf-8"] += 1 unless ch.valid_encoding?
                return if ch.ord <= 0x7F

                name = classify(ch.ord)
                name ? seen[name] += 1 : other[ch.ord] = ch
            end

            def self.classify(code)
                CLASSES.each { |name, range| return name if range.cover?(code) }
                return "wide" if Lint.wide?(code)
                return "invisible" if Lint.invisible?(code)

                "emoji-risk" if Lint.emoji_risk?(code)
            end

            def self.parts(seen, other)
                parts = seen.map { |name, n| "#{name}(#{n})" }
                return parts if other.empty?

                sample = other.first(5).map do |code, ch|
                    format("U+%<code>04X %<ch>s", code: code, ch: ch)
                end
                parts << "other(#{other.size}: #{sample.join(", ")})"
            end
        end
    end
end
