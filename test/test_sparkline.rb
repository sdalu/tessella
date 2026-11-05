# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.sparkline / `tessella sparkline`, and yscale: on the
# plotted kinds.
class TestSparkline < Minitest::Test
    def spark(*, **) = Tessella.sparkline(*, **).to_s.chomp

    def test_eight_steps_from_lowest_to_highest
        assert_equal("▁▂▄▃█▁▂", spark([1, 5, 22, 13, 53, 2, 8]))
        assert_equal("_.:-#_.", spark([1, 5, 22, 13, 53, 2, 8], ascii: true))
    end

    def test_width_averages_and_a_flat_line_sits_mid_height
        assert_equal("▁▂▃▃▄▅▆▆▇█", spark((1..100).to_a, width: 10))
        assert_equal("▅▅▅", spark([3, 3, 3]))
    end

    def test_a_fixed_range_shares_one_scale
        assert_equal("▁▅█", spark([0, 60, 100], min: 0, max: 100))
        assert_equal("▅", spark([50], min: 0, max: 100))
    end

    def test_refusals
        assert_raises(ArgumentError) { spark([]) }
        assert_raises(ArgumentError) { spark([1], min: 5, max: 1) }
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(%w[sparkline],
                                   stdin: StringIO.new("1,2 3\n"),
                                   stdout: out, stderr: StringIO.new)
        assert_equal([0, "▁▅█\n"], [status, out.string])
    end

    def test_yscale_transforms_y_and_bars_refuse_it
        assert_equal(Tessella.line([0, 1, 2, 3]).to_s,
                     Tessella.line([1, 10, 100, 1000], yscale: :log10).to_s)
        assert_raises(ArgumentError) { Tessella.bar(%w[a], [1], yscale: :ln) }
        assert_raises(ArgumentError) do
            Tessella.line([0, 1], yscale: :log10).to_s
        end
    end
end
