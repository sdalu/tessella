# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.text and `tessella text`: styles from Unicode's own forms,
# the Mathematical Alphanumeric holes filled from Letterlike Symbols,
# gaps passing through (or refused under strict:), and back to plain.
class TestText < Minitest::Test
    def text(*, **) = Tessella.text(*, **)

    # The holes a table built by offset would fill with reserved code
    # points: each must be its Letterlike Symbols character.
    def test_the_holes_are_the_letterlike_symbols
        assert_equal("ℎ", text("h", style: :italic))
        assert_equal("ℬℰℱℋℐℒℳℛℯℊℴ", text("BEFHILMRego", style: :script))
        assert_equal("ℭℌℑℜℨ", text("CHIRZ", style: :fraktur))
        assert_equal("ℂℍℕℙℚℝℤ", text("CHNPQRZ", style: "double-struck"))
    end

    def test_digits_only_where_unicode_has_them
        assert_equal("𝟏𝟐", text("12", style: :bold))
        assert_equal(%w[1 2], Tessella::Text.unmapped("12", :italic))
    end

    def test_small_caps_and_the_capitals_only_styles
        assert_equal("Fᴏx", text("Fox", style: :small_caps))
        assert_equal(%w[x], Tessella::Text.unmapped("Fox", :small_caps))
        assert_equal("🄰🄱", text("ab", style: :squared))
    end

    def test_superscripts_are_modifier_letters_not_ordinals
        assert_equal("ᵃᵒ", text("ao", style: :superscript))
    end

    def test_fullwidth_is_two_columns_a_glyph
        wide = text("ab c", style: :fullwidth)
        assert_equal("ａｂ　ｃ", wide)
        assert_equal(8, Tessella::Width.of(wide))
    end

    def test_plain_undoes_every_style
        sample = "Hello World 123"
        Tessella::Text::FORMS.each_key do |style|
            next unless Tessella::Text.unmapped(sample, style).empty?

            back = text(text(sample, style: style), style: :plain)
            capitals = Tessella::Text::CAPITALS_ONLY.include?(style)
            assert_equal(capitals ? sample.upcase : sample, back, style)
        end
    end

    def test_refusals
        assert_raises(ArgumentError) do
            text("x", style: :small_caps, strict: true)
        end
        assert_raises(ArgumentError) { text("x", style: :bold, ascii: true) }
        assert_raises(ArgumentError) { text("x", style: :gothic) }
    end

    def cli(*argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["text", *argv], stdin: StringIO.new(stdin),
                                                    stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def test_the_command
        assert_equal([0, "𝐇𝐢\n", ""], cli("--style", "bold", "Hi"))
        assert_equal([0, "Hi\n", ""], cli("--plain", stdin: "𝐇𝐢\n"))
        status, out, err = cli("--style", "small-caps", "--strict", "fox")
        assert_equal([1, ""], [status, out])
        assert_match(/no small-caps form for: x/, err)
        assert_equal(2, cli("--style", "bold", "--ascii", "x").first)
        assert_equal(2, cli("x").first)
    end
end
