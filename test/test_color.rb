# frozen_string_literal: true

require_relative "test_helper"

# AsciiArt::Color: colour names to ANSI SGR, and nothing else
# (DESIGN.md, "Frame and Color").
class TestColor < Minitest::Test
    def test_wrap_with_nil_name_returns_text_unchanged
        assert_equal("plain", AsciiArt::Color.wrap("plain", nil))
    end

    def test_wrap_never_emits_an_escape_for_a_nil_name
        refute_includes(AsciiArt::Color.wrap("plain", nil), "\e")
    end

    def test_wrap_adds_an_sgr_code_and_resets_at_the_end
        wrapped = AsciiArt::Color.wrap("x", :red)
        assert_match(/\A\e\[\d+mx\e\[0m\z/, wrapped)
    end

    def test_names_are_the_series_cycle
        assert_equal(%i[red green yellow blue magenta cyan white],
                     AsciiArt::Color::NAMES)
    end

    def test_names_is_frozen
        assert(AsciiArt::Color::NAMES.frozen?)
    end

    def test_every_name_wraps_to_a_distinct_code
        codes = AsciiArt::Color::NAMES.map do |name|
            AsciiArt::Color.wrap("x", name)[/\e\[(\d+)m/, 1]
        end
        assert_equal(codes.uniq.size, codes.size)
    end

    def test_unknown_colour_raises
        assert_raises(ArgumentError) { AsciiArt::Color.wrap("x", :octarine) }
    end
end
