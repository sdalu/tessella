# frozen_string_literal: true

require_relative "test_helper"
require_relative "test_lint"

# Tessella.lint's target: (DESIGN.md, "Width targets"): widths are the
# target's; cjk names ambiguous glyphs on aligned rows, web lets an
# emoji-capable glyph followed by U+FE0E pass.
class TestLintTarget < Minitest::Test
    include LintHelper

    def test_cjk_names_ambiguous_glyphs_on_aligned_rows
        assert_equal(["1: ambiguous U+00E9 é on aligned row (cjk target: " \
                      "2 columns)"],
                     findings("│ é │\n│ a │\n", target: :cjk))
        assert_empty(findings("│ é │\n│ a │\n"))
    end

    def test_cjk_names_the_small_head_for_a_full_one
        assert_equal(["1: ambiguous U+25B2 ▲ on aligned row (cjk target: " \
                      "2 columns; ▴ lines up)"],
                     findings("│ ▲ │\n", target: :cjk))
    end

    def test_cjk_measures_ambiguous_glyphs_as_two
        assert_equal(["1: 3 columns rendered (budget 2)"],
                     findings("éa\n", target: :cjk, width: 2))
        assert_empty(findings("éa\n", width: 2))
    end

    def test_web_accepts_a_glyph_kept_as_text
        assert_empty(findings("go ▶\u{FE0E}\n", target: :web))
        assert_equal(["1: emoji-capable U+25B6 ▶ (web target)"],
                     findings("go ▶\n", target: :web))
        assert_equal(["1: invisible char U+FE0E"], findings("a\u{FE0E}\n"))
    end

    def test_the_current_target_is_the_default
        out = Tessella::Target.with(:cjk) { findings("│ é │\n") }
        assert_equal(1, out.size)
        assert_raises(ArgumentError) { findings("x\n", target: :mars) }
    end
end
