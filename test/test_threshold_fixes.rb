# frozen_string_literal: true

require_relative "test_helper"

# Option-combination regressions from the blind bug hunt: threshold:
# with yerr:, an area without gradient, marks and colour; the rule
# keeping the data's colour; a coloured heatmap under ascii:.
class TestThresholdFixes < Minitest::Test
    XS = [1, 2, 3].freeze
    YS = [1, 5, 2].freeze

    def test_error_bars_survive_a_threshold
        with = Tessella.scatter(XS, YS, yerr: [3] * 3, threshold: 4,
                                        width: 20, height: 6).to_s
        without = Tessella.scatter(XS, YS, threshold: 4, width: 20,
                                           height: 6).to_s
        assert_operator(with.count("⡇"), :>, without.count("⡇"))
    end

    def test_an_area_without_gradient_takes_a_threshold
        %i[vertical horizontal].each do |o|
            out = Tessella.line(XS, YS, area: true, threshold: 3,
                                        gradient: false, orientation: o)
            assert(out.to_s)
        end
    end

    def test_marks_take_the_threshold_colours
        out = Tessella.line(XS, YS, mark: "x", threshold: 3, color: true).to_s
        assert_includes(out, "\e[31mx")
    end

    def test_the_rule_keeps_the_data_colour
        out = Tessella.line(XS, YS, area: true, threshold: 3, color: true,
                                    width: 10, height: 4).to_s
        rule_row = out.lines.find { it.include?("⠄") }
        assert_includes(rule_row, "\e[")
    end

    def test_a_coloured_heatmap_under_ascii_is_ascii
        out = Tessella.heatmap([[1, 3], [4, 6]], ascii: true, color: true).to_s
        assert(out.gsub(/\e\[[0-9;]*m/, "").ascii_only?)
    end
end
