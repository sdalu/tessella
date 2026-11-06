# frozen_string_literal: true

require_relative "test_helper"

# Glyphs that keep a column in a browser (measured in Chrome on
# GitHub's code fonts): braille does not, so the web target charts on
# quadrant blocks and lint names braille rows; ■ replaces ◆, which
# took two columns there.
class TestWebGlyphs < Minitest::Test
    def test_the_web_target_charts_on_quadrant_blocks
        out = Tessella::Target.with(:web) do
            Tessella.line([1, 3, 2], width: 10, height: 3).to_s
        end
        refute_match(/[⠁-⣿]/, out)
        assert_match(/[▖▗▘▝▚▞▙▛▜▟▌▐▀▄█]/, out)
        assert_match(/[⠁-⣿]/, Tessella.line([1, 3, 2]).to_s)
    end

    def test_web_lint_names_a_braille_row_once
        chart = Tessella.line([1, 3, 2], width: 10, height: 3).to_s
        findings = Tessella.lint(chart, target: :web).findings
        braille = findings.map(&:message).grep(/braille/)
        refute_empty(braille)
        assert_equal(braille.size, findings.map(&:line).uniq.size)
    end

    def test_no_fill_takes_two_columns_and_braille_is_not_web_safe
        refute_includes(Tessella::Legend::FILLS, "◆")
        assert_includes(Tessella::Legend::FILLS, "■")
        assert_equal(%i[term cjk], Tessella::Glyphs.targets("⣿"))
    end
end
