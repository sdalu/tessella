# frozen_string_literal: true

require_relative "test_helper"

# Legend: the fills series are told apart by, and a legend wrapped
# under a frame.
class TestLegend < Minitest::Test
    def test_wraps_to_the_width
        entries = ["a 1", "b 2", "c 3"]
        assert_equal("a 1  b 2\nc 3", Tessella::Legend.wrap(entries, 8))
    end

    def test_never_splits_an_entry
        assert_equal("alpha\nb", Tessella::Legend.wrap(%w[alpha b], 3))
    end

    def test_fills_are_distinct_and_one_width
        fills = Tessella::Legend::FILLS
        assert_equal(fills.size, fills.uniq.size)
        assert_equal(1, fills.map { Tessella::Width.of(it) }.uniq.size)
        assert(Tessella::Legend::ASCII_FILLS.join.ascii_only?)
    end

    def test_a_thirteenth_series_is_refused
        assert_raises(ArgumentError) do
            Tessella.bar(%w[a], [[1] * 13])
        end
        out = Tessella.bar(%w[a], [[1] * 4], width: 20).to_s
        assert_includes(out, "░")
    end
end
