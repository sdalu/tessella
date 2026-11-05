# frozen_string_literal: true

module Tessella
    # Display width: the columns a terminal gives a string. East Asian
    # Wide and Fullwidth glyphs take two, invisible ones (combining
    # marks, zero-width and format characters, variation selectors)
    # none, everything else one -- ambiguous glyphs (box drawing,
    # blocks) included, the Western terminal width. The two tables,
    # generated from Unicode 15.1, came from the ascii-art skill's
    # artlint.rb and are now shared with Tessella.lint (lint.rb); the
    # markdown skill's check_md.rb keeps a copy that must stay
    # identical to them.
    module Width
        WIDE = [
            0x1100..0x115F, 0x231A..0x231B, 0x2329..0x232A, 0x23E9..0x23EC,
            0x23F0..0x23F0, 0x23F3..0x23F3, 0x25FD..0x25FE, 0x2614..0x2615,
            0x2648..0x2653, 0x267F..0x267F, 0x2693..0x2693, 0x26A1..0x26A1,
            0x26AA..0x26AB, 0x26BD..0x26BE, 0x26C4..0x26C5, 0x26CE..0x26CE,
            0x26D4..0x26D4, 0x26EA..0x26EA, 0x26F2..0x26F3, 0x26F5..0x26F5,
            0x26FA..0x26FA, 0x26FD..0x26FD, 0x2705..0x2705, 0x270A..0x270B,
            0x2728..0x2728, 0x274C..0x274C, 0x274E..0x274E, 0x2753..0x2755,
            0x2757..0x2757, 0x2795..0x2797, 0x27B0..0x27B0, 0x27BF..0x27BF,
            0x2B1B..0x2B1C, 0x2B50..0x2B50, 0x2B55..0x2B55, 0x2E80..0x2E99,
            0x2E9B..0x2EF3, 0x2F00..0x2FD5, 0x2FF0..0x303E, 0x3041..0x3096,
            0x3099..0x30FF, 0x3105..0x312F, 0x3131..0x318E, 0x3190..0x31E3,
            0x31EF..0x321E, 0x3220..0x3247, 0x3250..0x4DBF, 0x4E00..0xA48C,
            0xA490..0xA4C6, 0xA960..0xA97C, 0xAC00..0xD7A3, 0xF900..0xFAFF,
            0xFE10..0xFE19, 0xFE30..0xFE52, 0xFE54..0xFE66, 0xFE68..0xFE6B,
            0xFF01..0xFF60, 0xFFE0..0xFFE6, 0x16FE0..0x16FE4, 0x16FF0..0x16FF1,
            0x17000..0x187F7, 0x18800..0x18CD5, 0x18D00..0x18D08,
            0x1AFF0..0x1AFF3, 0x1AFF5..0x1AFFB, 0x1AFFD..0x1AFFE,
            0x1B000..0x1B122, 0x1B132..0x1B132, 0x1B150..0x1B152,
            0x1B155..0x1B155, 0x1B164..0x1B167, 0x1B170..0x1B2FB,
            0x1F004..0x1F004, 0x1F0CF..0x1F0CF, 0x1F18E..0x1F18E,
            0x1F191..0x1F19A, 0x1F200..0x1F202, 0x1F210..0x1F23B,
            0x1F240..0x1F248, 0x1F250..0x1F251, 0x1F260..0x1F265,
            0x1F300..0x1F320, 0x1F32D..0x1F335, 0x1F337..0x1F37C,
            0x1F37E..0x1F393, 0x1F3A0..0x1F3CA, 0x1F3CF..0x1F3D3,
            0x1F3E0..0x1F3F0, 0x1F3F4..0x1F3F4, 0x1F3F8..0x1F43E,
            0x1F440..0x1F440, 0x1F442..0x1F4FC, 0x1F4FF..0x1F53D,
            0x1F54B..0x1F54E, 0x1F550..0x1F567, 0x1F57A..0x1F57A,
            0x1F595..0x1F596, 0x1F5A4..0x1F5A4, 0x1F5FB..0x1F64F,
            0x1F680..0x1F6C5, 0x1F6CC..0x1F6CC, 0x1F6D0..0x1F6D2,
            0x1F6D5..0x1F6D7, 0x1F6DC..0x1F6DF, 0x1F6EB..0x1F6EC,
            0x1F6F4..0x1F6FC, 0x1F7E0..0x1F7EB, 0x1F7F0..0x1F7F0,
            0x1F90C..0x1F93A, 0x1F93C..0x1F945, 0x1F947..0x1F9FF,
            0x1FA70..0x1FA7C, 0x1FA80..0x1FA88, 0x1FA90..0x1FABD,
            0x1FABF..0x1FAC5, 0x1FACE..0x1FADB, 0x1FAE0..0x1FAE8,
            0x1FAF0..0x1FAF8, 0x20000..0x2FFFD, 0x30000..0x3FFFD
        ].freeze

        INVISIBLE = [
            0x0300..0x036F, 0x1AB0..0x1AFF, 0x1DC0..0x1DFF, 0x200B..0x200F,
            0x2060..0x206F, 0xFE00..0xFE0F, 0xFE20..0xFE2F, 0xFEFF..0xFEFF
        ].freeze

        # An ANSI colour sequence (a chart drawn with color: true) takes
        # no column.
        ANSI = /\e\[[0-9;]*m/

        # What makes a cluster one emoji: a zero-width joiner, or a
        # skin-tone modifier.
        EMOJI_JOIN = /[\u200D\u{1F3FB}-\u{1F3FF}]/

        # Summed over grapheme clusters, so an emoji sequence counts
        # once (Width.cluster).
        def self.of(text)
            plain = text.to_s.gsub(ANSI, "")
            return plain.length if plain.ascii_only?

            plain.each_grapheme_cluster.sum { cluster(it) }
        end

        # One grapheme cluster's columns: its characters' sum, except an
        # emoji sequence -- joined by ZWJ (👨‍👩‍👧) or skin-toned (👍🏽)
        # -- which terminals draw as the one wide glyph it is: 2.
        def self.cluster(text)
            widths = text.each_char.map { char(it.ord) }
            return 2 if widths.include?(2) && text.match?(EMOJI_JOIN)

            widths.sum
        end

        def self.pad(count) = " " * [count, 0].max

        # glyph repeated to fill cols columns: cols / its width copies,
        # so a two-column box glyph (an ambiguous one under :cjk) runs
        # half as many times.
        def self.run(glyph, cols) = glyph * (cols / [of(glyph), 1].max)

        # cols rounded up to a whole number of units: a frame's or a
        # column's inner width, so its border glyphs fill it exactly.
        def self.round_up(cols, unit) = ((cols + unit - 1) / unit) * unit
        def self.ljust(text, cols) = text + pad(cols - of(text))
        def self.rjust(text, cols) = pad(cols - of(text)) + text

        def self.center(text, cols)
            gap = cols - of(text)
            pad(gap / 2) + text + pad(gap - (gap / 2))
        end

        # A character's columns under the current target (Target):
        # an ambiguous glyph takes two under :cjk.
        def self.char(code)
            width = base(code)
            return width unless width == 1 && code > 0x7F && Target.cjk?

            ambiguous?(code) ? 2 : 1
        end

        # A character's columns in a Western terminal, whatever the
        # target: what its width class is read from.
        def self.base(code)
            return 1 if code < 0x300
            return 2 if WIDE.any? { it.cover?(code) }

            INVISIBLE.any? { it.cover?(code) } ? 0 : 1
        end
    end
end
