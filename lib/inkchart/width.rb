# frozen_string_literal: true

module Inkchart
    # Display width: the columns a terminal gives a string. East Asian
    # wide and fullwidth characters take two, combining marks and zero
    # width spaces none, everything else one. A small table rather than
    # a dependency, covering the blocks a chart label realistically
    # holds (CJK, Hangul, kana, fullwidth forms, emoji).
    module Width
        WIDE = [
            0x1100..0x115F, 0x2E80..0x303E, 0x3041..0x33FF,
            0x3400..0x4DBF, 0x4E00..0x9FFF, 0xA000..0xA4CF,
            0xAC00..0xD7A3, 0xF900..0xFAFF, 0xFE30..0xFE4F,
            0xFF00..0xFF60, 0xFFE0..0xFFE6, 0x1F300..0x1F64F,
            0x1F900..0x1F9FF, 0x20000..0x2FFFD, 0x30000..0x3FFFD
        ].freeze

        ZERO = [0x0300..0x036F, 0x200B..0x200F, 0xFE00..0xFE0F].freeze

        def self.of(text)
            text.to_s.each_char.sum { char(it.ord) }
        end

        def self.char(code)
            return 1 if code < 0x300
            return 0 if ZERO.any? { it.cover?(code) }

            WIDE.any? { it.cover?(code) } ? 2 : 1
        end
    end
end
