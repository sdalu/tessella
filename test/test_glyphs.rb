# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Width classes (Unicode 15.1 East Asian Width: N, A, W) and the
# named glyph sets, whose classes are computed, never typed in; the
# values below are the ascii-art skill's glyph-palette annotations.
class TestGlyphs < Minitest::Test
    def test_classes_match_the_palette
        { "░" => :N, "▒" => :A, "▐" => :N, "▌" => :A, "·" => :A, "◦" => :N,
          "▸" => :N, "■" => :A, "∘" => :N, "─" => :A, "a" => :N,
          "漢" => :W }.each do |glyph, cls|
            assert_equal(cls, Tessella::Width.class_of(glyph), glyph)
        end
        assert_nil(Tessella::Width.class_of("​"))
    end

    def test_a_set_is_mixed_when_its_glyphs_span_two_classes
        assert_predicate(Tessella::Glyphs.fetch(:ramp, :blocks), :mixed?)
        refute_predicate(Tessella::Glyphs.fetch(:meter, :arrow), :mixed?)
        assert_equal([:A], Tessella::Glyphs.fetch(:border, "double-h").classes)
    end

    def test_every_border_style_is_registered
        assert_equal(Tessella::Borders::STYLES.keys,
                     Tessella::Glyphs.names(:border))
    end

    def test_an_unknown_set_names_the_known_ones
        error = assert_raises(ArgumentError) do
            Tessella::Glyphs.fetch(:meter, :rocket)
        end
        assert_match(/unknown meter: :rocket \(arrow, chevron/, error.message)
    end

    def glyphs(*argv) = run_command(["glyphs", *argv]).first(2)

    def test_the_command_lists_details_and_checks
        assert_match(/^meter\s+arrow\s+N\s+term cjk web\s+▸▹$/, glyphs.last)
        assert_equal("∴  U+2234  A\n∵  U+2235  A\n",
                     glyphs("pattern", "stipple").last)
        assert_equal([0, "A\nsafe for: term web\n"], glyphs("--check", "■□"))
        assert_equal([1, "mixed: A N\nsafe for: term web\n"],
                     glyphs("--check", "█░"))
        assert_equal(2, glyphs("bogus").first)
        assert_equal(2, glyphs("border", "nope").first)
    end

    # Safe for term always, cjk with no ambiguous glyph, web with no
    # wide or emoji-capable one.
    def test_each_set_says_which_targets_it_suits
        g = Tessella::Glyphs
        assert_equal(%i[term web], g.fetch(:border, :light).targets)
        assert_equal(%i[term cjk web], g.targets("+-|"))
        assert_equal(%i[term cjk], g.targets("日本"))
        assert_equal(%i[term], g.targets("▶·"))
    end

    def test_the_command_lists_the_sets_for_a_target
        listed = glyphs("--target", "cjk").last.lines
        assert(listed.all? { it.include?("cjk") })
        assert_equal(2, glyphs("--target", "mars").first)
    end

    # The arrow heads by the ascii-art skill's rule: full-size, small
    # (lining up everywhere), and emoji-capable (term only).
    def test_arrow_heads_say_where_they_line_up
        g = Tessella::Glyphs
        assert_equal(%i[term web], g.fetch(:head, :full).targets)
        assert_equal(%i[term cjk web], g.fetch(:head, :small).targets)
        assert_equal(%i[term], g.fetch(:head, :emoji).targets)
    end
end
