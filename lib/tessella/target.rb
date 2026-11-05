# frozen_string_literal: true

module Tessella
    # Where a figure will be read (DESIGN.md, "Width targets"), which
    # decides what a glyph's width is and which glyphs are safe:
    #
    #   :term  a terminal (the default): ambiguous glyphs -- box
    #          drawing, blocks, · ● ★, Greek, accented Latin -- one
    #          column, wide ones two.
    #   :cjk   a CJK-configured terminal: ambiguous glyphs two columns
    #          too, so figures draw their structure in ASCII (ascii:
    #          defaults to true, text stays as given) and measure text
    #          with ambiguous glyphs as two.
    #   :web   a browser: as :term, but emoji-capable glyphs (▶ ☀ ✔ ...)
    #          may turn into wide emoji, so a figure's text carries
    #          U+FE0E, the text-presentation selector, after each one.
    #          That keeps it a text glyph, not its width: a glyph the
    #          viewer's monospace font lacks takes its fallback font's
    #          advance (▶ two columns, ↗ 1.4 in Chrome on GitHub's font
    #          stack), so only glyphs that font carries line up.
    #
    # The target is set for a block of code (Target.with) or for the
    # rest of the fiber (Tessella.target=); the command line takes
    # `tessella --target T COMMAND` or TESSELLA_TARGET.
    module Target
        TARGETS = %i[term cjk web].freeze
        TEXT_STYLE = "\u{FE0E}"

        # Emoji-capable with text-default presentation (Emoji=Yes minus
        # Emoji_Presentation=Yes, BMP; digits/#/* excluded): one cell in
        # terminals, but web viewers may substitute the 2-cell emoji
        # glyph. Generated from Unicode 15.1 emoji-data.txt.
        EMOJI_RISK = [
            0x00A9..0x00A9, 0x00AE..0x00AE, 0x203C..0x203C, 0x2049..0x2049,
            0x2122..0x2122, 0x2139..0x2139, 0x2194..0x2199, 0x21A9..0x21AA,
            0x2328..0x2328, 0x23CF..0x23CF, 0x23ED..0x23EF, 0x23F1..0x23F2,
            0x23F8..0x23FA, 0x24C2..0x24C2, 0x25AA..0x25AB, 0x25B6..0x25B6,
            0x25C0..0x25C0, 0x25FB..0x25FC, 0x2600..0x2604, 0x260E..0x260E,
            0x2611..0x2611, 0x2618..0x2618, 0x261D..0x261D, 0x2620..0x2620,
            0x2622..0x2623, 0x2626..0x2626, 0x262A..0x262A, 0x262E..0x262F,
            0x2638..0x263A, 0x2640..0x2640, 0x2642..0x2642, 0x265F..0x2660,
            0x2663..0x2663, 0x2665..0x2666, 0x2668..0x2668, 0x267B..0x267B,
            0x267E..0x267E, 0x2692..0x2692, 0x2694..0x2697, 0x2699..0x2699,
            0x269B..0x269C, 0x26A0..0x26A0, 0x26A7..0x26A7, 0x26B0..0x26B1,
            0x26C8..0x26C8, 0x26CF..0x26CF, 0x26D1..0x26D1, 0x26D3..0x26D3,
            0x26E9..0x26E9, 0x26F0..0x26F1, 0x26F4..0x26F4, 0x26F7..0x26F9,
            0x2702..0x2702, 0x2708..0x2709, 0x270C..0x270D, 0x270F..0x270F,
            0x2712..0x2712, 0x2714..0x2714, 0x2716..0x2716, 0x271D..0x271D,
            0x2721..0x2721, 0x2733..0x2734, 0x2744..0x2744, 0x2747..0x2747,
            0x2763..0x2764, 0x27A1..0x27A1, 0x2934..0x2935, 0x2B05..0x2B07,
            0x3030..0x3030, 0x303D..0x303D, 0x3297..0x3297, 0x3299..0x3299
        ].freeze
        def self.current = Fiber[:tessella_target] || :term
        def self.cjk? = current == :cjk
        def self.web? = current == :web

        # ascii:'s default: true under :cjk, whose terminals give box
        # drawing two columns.
        def self.ascii? = cjk?

        # Text under ascii: true must be ASCII, except under :cjk,
        # where ascii: only means the structure.
        def self.text_free? = cjk?

        def self.check!(target)
            sym = target.to_s.to_sym
            return sym if TARGETS.include?(sym)

            raise ArgumentError, "unknown target: #{target.inspect} " \
                                 "(#{TARGETS.join(", ")})"
        end

        def self.with(target)
            before = Fiber[:tessella_target]
            Fiber[:tessella_target] = check!(target)
            yield
        ensure
            Fiber[:tessella_target] = before
        end

        def self.emoji_risk?(code) = EMOJI_RISK.any? { it.cover?(code) }

        # Under :web, U+FE0E after every emoji-capable glyph not
        # already followed by a presentation selector; else as is.
        def self.adapt(text)
            return text unless web?

            text.gsub(/(.)(?![\u{FE0E}\u{FE0F}])/) do |ch|
                emoji_risk?(ch.ord) ? ch + TEXT_STYLE : ch
            end
        end
    end

    def self.target = Target.current

    def self.target=(target)
        Fiber[:tessella_target] = Target.check!(target)
    end
end
