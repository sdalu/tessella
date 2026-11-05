# frozen_string_literal: true

require_relative "test_helper"

# Inkchart::Axis.limits and .label (DESIGN.md).
class TestAxis < Minitest::Test
    include Oracle::Test

    DATASETS = [
        [[1, 2, 3, 4, 5], [1, 2, 3, 4, 10]],
        [[0.03, 0.09, 0.17, 0.22], [1.2, 5.5, 13.7, 44.4]],
        [[-10, -5, 0, 3, 9], [-10, -5, 0, 3, 9]],
        [[1, 2, 3, 4, 5], [1, 1_000_000, 500_000, 250_000, 999_999]],
        [[1, 2, 3], [1.0, 2.5, 3.7]]
    ].freeze

    def test_label_integer_as_is
        assert_equal "5", Inkchart::Axis.label(5)
        assert_equal "-3", Inkchart::Axis.label(-3)
    end

    def test_label_float_keeps_its_digits
        assert_equal "5.0", Inkchart::Axis.label(5.0)
        assert_equal "3.14", Inkchart::Axis.label(3.14)
    end

    def test_label_no_exponent_in_range
        assert_equal "0.0001", Inkchart::Axis.label(0.0001)
        assert_equal "999999999999999.0",
                     Inkchart::Axis.label(999_999_999_999_999.0)
    end

    def test_limits_given_not_zero_is_kept
        assert_equal [2.0, 9.0], Inkchart::Axis.limits([1, 2, 3], [2, 9])
    end

    def test_limits_equal_values_widen_by_one
        assert_equal [4.0, 6.0], Inkchart::Axis.limits([5, 5, 5])
    end

    def test_limits_narrows_to_a_nice_round_extent
        assert_equal [1.0, 10.0], Inkchart::Axis.limits([1, 2, 3, 4, 10])
    end

    def test_oracle_limits_matches_extend_limits
        need_oracle
        DATASETS.each do |x, y|
            assert_equal UnicodePlot::Utils.extend_limits(x, [0, 0]),
                         Inkchart::Axis.limits(x)
            assert_equal UnicodePlot::Utils.extend_limits(y, [0, 0]),
                         Inkchart::Axis.limits(y)
        end
    end

    def test_oracle_label_matches_the_rendered_plot
        need_oracle
        DATASETS.each { |x, y| assert_rendered_extremes_match(x, y) }
    end

    def assert_rendered_extremes_match(x, y)
        xmin_s, xmax_s, ymin_s, ymax_s = rendered_extremes(x, y)
        xlim = Inkchart::Axis.limits(x)
        ylim = Inkchart::Axis.limits(y)
        assert_label_or_known_divergence(xlim[0], xmin_s)
        assert_label_or_known_divergence(xlim[1], xmax_s)
        assert_label_or_known_divergence(ylim[0], ymin_s)
        assert_label_or_known_divergence(ylim[1], ymax_s)
    end

    # DESIGN.md's Axis.label keeps a Float's digits; the oracle's own
    # display collapses a whole-number Float to an Integer-looking
    # string (grid_plot.rb: `roundable? ? x.round : x`). A documented
    # disagreement (escalation rules): assert both sides explicitly
    # rather than hiding the mismatch.
    def assert_label_or_known_divergence(value, oracle_s)
        if value.to_i == value
            assert_equal value.to_i.to_s, oracle_s
            assert_equal "#{value.to_i}.0", Inkchart::Axis.label(value)
        else
            assert_equal oracle_s, Inkchart::Axis.label(value)
        end
    end

    def rendered_extremes(x, y)
        lines = Oracle.render(UnicodePlot.lineplot(x, y)).lines.map(&:chomp)
        top, bot = border_rows(lines)
        x_min, x_max = x_axis_labels(lines[bot + 1])
        [x_min, x_max, label_cell(lines[bot - 1]), label_cell(lines[top + 1])]
    end

    def border_rows(lines)
        [lines.index { |l| l.include?("┌") },
         lines.index { |l| l.include?("└") }]
    end

    def label_cell(line) = line[/\A\s*(\S+)\s*│/, 1]

    def x_axis_labels(line)
        toks = line.split(/\s+/).reject(&:empty?)
        [toks.first, toks.last]
    end
end
