# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# yerr: on line and scatter: a segment a point along the value axis,
# symmetric or [lows, highs], the limits taking the bars in.
class TestErrorBars < Minitest::Test
    def rows(chart) = chart.to_s.lines.map(&:chomp)

    def test_a_bar_widens_the_axis_to_its_ends
        out = rows(Tessella.scatter([1, 2], [5, 5], yerr: [4, 1], width: 8,
                                                    height: 3))
        assert_match(/^\s+9 │/, out[1])
        assert_match(/^\s+1 │/, out[3])
    end

    def test_symmetric_equals_the_two_arrays
        a = Tessella.line([1, 2], [3, 4], yerr: [1, 2]).to_s
        b = Tessella.line([1, 2], [3, 4], yerr: [[1, 2], [1, 2]]).to_s
        assert_equal(a, b)
        refute_equal(a, Tessella.line([1, 2], [3, 4]).to_s)
    end

    def test_sideways_bars_run_across
        opts = { yerr: [2, 2], width: 8, height: 3 }
        up = Tessella.scatter([1, 2], [5, 5], **opts)
        across = Tessella.scatter([1, 2], [5, 5], orientation: :horizontal,
                                                  **opts)
        refute_equal(up.to_s, across.to_s)
        assert_match(/^\s+3\s+7$/, across.to_s.lines.last)
    end

    def test_refusals
        assert_raises(ArgumentError) do
            Tessella.line([1, 2], [1, 2], yerr: [1])
        end
        assert_raises(ArgumentError) do
            Tessella.line([1, 2], [1, 2], yerr: [1, -1])
        end
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(%w[chart --kind scatter --yerr],
                                   stdin: StringIO.new("1 2 1\n2 4 1\n"),
                                   stdout: out, stderr: StringIO.new)
        assert_equal(0, status)
        assert_match(/^\s+5 │/, out.string.lines[1])
    end
end
