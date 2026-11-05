# frozen_string_literal: true

require_relative "test_helper"

# Meter and rule regressions from the blind bug hunt: widths counted in
# glyphs for a meter, in columns (whole glyphs) for a rule.
class TestMeterRuleFixes < Minitest::Test
    def bar(fraction)
        Tessella.meter(fraction, style: "＃－", width: 10, label: false,
                                 brackets: false).to_s.chomp
    end

    def test_a_wide_pair_keeps_its_length
        [0.25, 0.5, 0.75, 1.0].each { assert_equal(10, bar(it).length) }
    end

    def test_a_cjk_unicode_rule_is_its_width
        widths = Tessella::Target.with(:cjk) do
            [Tessella.rule(width: 20, ascii: false),
             Tessella.rule(width: 20, ornament: "x", ascii: false)]
                .map { Tessella::Width.of(it.to_s.chomp) }
        end
        assert_equal([20, 20], widths)
    end
end
