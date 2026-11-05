# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.rule and `tessella rule`: a divider width columns long, an
# ornament centred by display width.
class TestRule < Minitest::Test
    def rule(**) = Tessella.rule(**).to_s.chomp

    def test_a_plain_and_an_ornamented_rule
        assert_equal("─" * 10, rule(width: 10))
        assert_equal("────────── ✦ ───────────", rule(width: 24, ornament: "✦"))
        assert_equal(24, Tessella::Width.of(rule(width: 24, ornament: "漢")))
    end

    def test_styles_and_ascii
        assert_equal("═══ x ═══", rule(width: 9, ornament: "x", style: :double))
        assert_equal("--- x ---", rule(width: 9, ornament: "x", ascii: true))
    end

    def test_refusals
        assert_raises(ArgumentError) { rule(width: 4, ornament: "long") }
        assert_raises(ArgumentError) { rule(style: :wavy) }
        assert_raises(ArgumentError) { rule(ornament: "✦", ascii: true) }
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(%w[rule --width 9 --ornament x],
                                   stdin: StringIO.new, stdout: out,
                                   stderr: StringIO.new)
        assert_equal([0, "─── x ───\n"], [status, out.string])
    end
end
