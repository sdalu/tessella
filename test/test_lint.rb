# frozen_string_literal: true

require_relative "test_helper"

# Tessella.lint (DESIGN.md, "Lint"): one case per check of the
# ascii-art skill's artlint.rb, ported with it. The fixtures under
# test/fixtures/lint are the skill's own (tests/fixtures/lint and the
# eval fixtures check-fixtures.py vouches for), copied byte for byte.
module LintHelper
    FIXTURES = File.join(__dir__, "fixtures", "lint")

    def fixture(name) = File.binread(File.join(FIXTURES, name))

    def findings(text, **)
        Tessella.lint(text, **).findings.map { "#{it.line}: #{it.message}" }
    end

    def lines_of(text, pattern, **)
        findings(text, **).grep(pattern).map(&:to_i)
    end
end

# The line-at-a-time checks.
class TestLintLines < Minitest::Test
    include LintHelper

    def test_a_clean_text_has_no_finding
        assert_predicate(Tessella.lint("┌─┐\n│a│\n└─┘\n"), :clean?)
    end

    def test_tab_and_trailing_whitespace
        assert_equal(["1: tab character", "2: trailing whitespace"],
                     findings("a\tb\nc  \n"))
    end

    def test_the_budget_counts_the_prefix_and_wide_glyphs
        assert_equal(["1: 6 columns rendered (budget 5)"],
                     findings("漢字\n", width: 5, prefix: "# "))
    end

    def test_an_invisible_glyph_is_named
        assert_equal(["1: invisible char U+200B"], findings("a\u200Bb\n"))
    end

    def test_a_space_other_than_u0020_is_named
        assert_equal(["1: look-alike space U+00A0",
                      "1: look-alike space U+202F",
                      "1: look-alike space U+3000"],
                     findings("a\u00A0b\u202Fc\u3000d\n"))
        assert_equal(["1: look-alike space U+2009"],
                     findings("a\u2009b\n", ascii: true))
    end

    def test_wide_glyphs_are_errors_only_under_no_wide
        assert_empty(findings("漢\n"))
        assert_equal(["1: wide char U+6F22 漢"], findings("漢\n", no_wide: true))
    end

    def test_ascii_flags_every_non_ascii_glyph
        assert_equal(["1: non-ASCII U+2500 ─", "1: wide char U+6F22 漢"],
                     findings("─漢\n", ascii: true))
    end

    def test_web_flags_emoji_capable_and_wide_on_an_aligned_row
        assert_equal(["1: emoji-capable U+25B6 ▶ (web target)",
                      "2: wide U+6F22 漢 on aligned row (web target)"],
                     findings("▶\n│漢\n", web: true))
    end

    def test_forbid_takes_a_preset_or_a_literal
        assert_equal(["1: forbidden sequence \"*/\"",
                      "2: forbidden sequence \"XX\""],
                     findings("a */\nXX\n", forbid: %w[c-block XX]))
    end

    def test_c_line_forbids_a_trailing_backslash
        assert_equal(["1: row ends in backslash (line splicing)"],
                     findings("a \\\n", forbid: ["c-line"]).take(1))
    end

    def test_invalid_utf8_is_named_then_linted_as_question_marks
        assert_equal(["2: invalid UTF-8 byte sequence"],
                     findings("ok\nbad \xFF\n".b))
    end

    def test_rulers_carry_the_width_and_vertical_columns
        ruler = Tessella.lint("│ a │\n", prefix: "  ").rulers.first
        assert_equal([1, 7, [3, 7]],
                     [ruler.line, ruler.width, ruler.verticals])
    end
end

# The figure checks: shadows, vocabulary mixing, anchor drift.
class TestLintFigures < Minitest::Test
    include LintHelper

    SHADOWED = "┌──┐\n│ab│░\n└──┘░\n ░░░░\n"

    def test_a_full_drop_shadow_is_clean
        assert_empty(findings(SHADOWED))
    end

    def test_a_shadow_on_the_closing_row_only
        text = "┌──┐\n│ab│\n└──┘░\n ░░░░\n"
        assert_equal(["2: row has no drop shadow at column 5"],
                     findings(text))
    end

    def test_a_shadow_on_the_top_row_and_a_short_bar
        text = "┌──┐░\n│ab│░\n└──┘░\n ░░░\n"
        assert_equal(["1: drop shadow on the frame's top row (offset it " \
                      "one row down)",
                      "4: bottom bar ends at column 4, should reach the " \
                      "shadow column 5"], findings(text))
    end

    def test_a_shadow_without_a_bottom_bar
        assert_equal(["3: drop shadow has no bottom bar"],
                     findings("┌──┐\n│ab│░\n└──┘░\n"))
    end

    def test_mixed_vocabulary_is_one_finding_per_figure
        assert_equal(["3: ASCII structure (a +-/-+/--/|-/-|/+|/|+/->/<- " \
                      "pair, or | at the line edge) mixed with Unicode " \
                      "box-drawing (U+2500-257F) in the same figure"],
                     findings("┌──┐\n│ab│\n+--+\n|  |\n"))
    end

    def test_an_allow_mixed_marker_exempts_the_next_figure_only
        figure = "┌──┐\n+--+\n"
        %w[artlint tessella].each do |tool|
            text = "<!-- #{tool}: allow-mixed -->\n\n#{figure}\n#{figure}"
            assert_equal([7], lines_of(text, /ASCII structure/), tool)
        end
    end

    def test_allow_mixed_skips_the_check_for_the_whole_text
        assert_empty(findings("┌──┐\n+--+\n", allow_mixed: true))
    end

    def test_inline_code_naming_a_glyph_is_not_a_figure
        assert_empty(findings("a `+--+` corner on a `─` line\n"))
    end

    def test_a_drifted_anchor_names_its_rows
        drift = findings(fixture("drift-bad.md")).grep(/one column off/)
        assert_equal(["14: vertical at column 37 on 2 row(s) (14,15) " \
                      "beside the figure's anchor at column 36 (11 rows) " \
                      "-- one column off?"], drift)
    end

    def test_a_markdown_pipe_table_is_not_a_figure
        assert_predicate(Tessella.lint(fixture("table-ok.md")), :clean?)
    end
end
