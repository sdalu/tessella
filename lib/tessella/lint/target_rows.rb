# frozen_string_literal: true

module Tessella
    module Lint
        # The checks a target adds to a line (DESIGN.md, "Width
        # targets"): under :web, emoji-capable glyphs, and wide glyphs
        # or braille on an aligned row, which a browser does not keep a
        # column wide; under :cjk, ambiguous glyphs on an aligned row,
        # two columns there. Kept apart so Lines stays under budget.
        module TargetRows
            private

            def check_target_row(sec, i, line)
                check_web_row(sec, i, line) if @opts[:web]
                check_cjk_row(sec, i, line) if @opts[:target] == :cjk
            end

            def check_web_char(sec, i, ch)
                return unless Lint.emoji_risk?(ch.ord)

                report(sec, i, "#{glyph("emoji-capable", ch)} (web target)")
            end

            def check_web_row(sec, i, line)
                return unless line.match?(STRUCTURAL)

                line.each_char do |ch|
                    next unless Lint.wide?(ch.ord)

                    report(sec, i, "#{glyph("wide", ch)} on aligned row " \
                                   "(web target)")
                end
                check_web_braille(sec, i, line)
            end

            # Braille comes from a fallback font in a browser, wider
            # than a column: named once a row, as a chart has many.
            def check_web_braille(sec, i, line)
                ch = line[BRAILLE] or return

                report(sec, i, "#{glyph("braille", ch)} on aligned row " \
                               "(web target: not a column wide)")
            end

            # Under :cjk an ambiguous glyph that is not box drawing (·, é,
            # ●) on a row that must line up takes two columns: named,
            # as the drift and geometry checks measure it so.
            def check_cjk_row(sec, i, line)
                return unless line.match?(STRUCTURAL)

                line.each_char.grep_v(BOX_CHAR).uniq.each do |ch|
                    next unless Width.class_of(ch) == :A

                    report(sec, i, "#{glyph("ambiguous", ch)} on aligned row " \
                                   "(cjk target: 2 columns#{stand_in(ch)})")
                end
            end

            # The small head that lines up in place of a full-size one.
            def stand_in(ch)
                small = { "▲" => "▴", "▼" => "▾" }[ch]
                small ? "; #{small} lines up" : ""
            end
        end
    end
end
