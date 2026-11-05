# frozen_string_literal: true

require_relative "test_helper"

# AsciiArt::Stats.histogram, .percentiles and .transform (DESIGN.md).
class TestStats < Minitest::Test
    include Oracle::Test

    DATASETS = {
        ints: [1, 2, 2, 3, 3, 3, 4, 5, 10],
        floats: [0.1, 0.5, 0.5, 1.2, 3.3, 3.3, 3.3, 9.9],
        negs: [-10, -5, -5, 0, 3, 7, 9],
        repeated: [5, 5, 5, 5],
        wide: [1, 1_000_000, 500_000, 250_000, 999_999]
    }.freeze

    def test_histogram_default_bins_matches_sturges
        h = AsciiArt::Stats.histogram(DATASETS[:ints])
        assert_equal [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0], h.edges
        assert_equal [1, 5, 2, 0, 0, 1], h.counts
        assert_equal :left, h.closed
    end

    def test_histogram_right_closed
        h = AsciiArt::Stats.histogram(DATASETS[:ints], closed: :right)
        assert_equal [0.0, 2.0, 4.0, 6.0, 8.0, 10.0], h.edges
        assert_equal [3, 4, 1, 0, 1], h.counts
        assert_equal :right, h.closed
    end

    def test_histogram_repeated_value_widens_by_one
        h = AsciiArt::Stats.histogram(DATASETS[:repeated])
        assert_equal [5.0, 6.0], h.edges
        assert_equal [4], h.counts
    end

    def test_histogram_explicit_bins
        h = AsciiArt::Stats.histogram(DATASETS[:ints], bins: 3)
        assert_equal 4, h.edges.size
        assert_equal h.edges.size - 1, h.counts.size
    end

    def test_histogram_every_value_in_exactly_one_bin
        h = AsciiArt::Stats.histogram(DATASETS[:ints])
        assert_equal DATASETS[:ints].size, h.counts.sum
    end

    def test_histogram_empty
        h = AsciiArt::Stats.histogram([])
        assert_equal [0.0], h.edges
        assert_empty h.counts
    end

    def test_histogram_rejects_bad_closed
        assert_raises(ArgumentError) do
            AsciiArt::Stats.histogram([1, 2, 3], closed: :middle)
        end
    end

    def test_percentiles_quartiles
        ps = [0, 25, 50, 75, 100]
        got = AsciiArt::Stats.percentiles([1, 2, 3, 4, 5], ps)
        assert_equal [1.0, 2.0, 3.0, 4.0, 5.0], got
    end

    def test_percentiles_interpolates
        assert_equal [2.5], AsciiArt::Stats.percentiles([1, 2, 3, 4], [50])
    end

    def test_percentiles_out_of_bounds
        assert_raises(ArgumentError) do
            AsciiArt::Stats.percentiles([1, 2, 3], [101])
        end
    end

    def test_transform_identity
        assert_equal 3, AsciiArt::Stats.transform(nil).call(3)
        assert_equal 3, AsciiArt::Stats.transform(:identity).call(3)
    end

    def test_transform_named
        ln = AsciiArt::Stats.transform(:ln)
        log2 = AsciiArt::Stats.transform(:log2)
        log10 = AsciiArt::Stats.transform(:log10)
        assert_in_delta Math.log(8), ln.call(8)
        assert_in_delta 3.0, log2.call(8)
        assert_in_delta 2.0, log10.call(100)
    end

    def test_transform_unknown
        assert_raises(ArgumentError) { AsciiArt::Stats.transform(:sqrt) }
    end

    def test_oracle_histogram_matches_enumerable_statistics
        need_oracle
        DATASETS.each_value do |data|
            [nil, 3, 7].each do |bins|
                %i[left right].each do |closed|
                    assert_histogram_matches(data, bins, closed)
                end
            end
        end
    end

    def assert_histogram_matches(data, bins, closed)
        expected = data.histogram(*[bins].compact, closed: closed)
        mine = AsciiArt::Stats.histogram(data, bins: bins, closed: closed)
        assert_equal expected.edge, mine.edges
        assert_equal expected.weights, mine.counts
    end

    def test_oracle_percentiles_matches_enumerable_statistics
        need_oracle
        ps = [0, 1, 25, 50, 75, 99, 100]
        DATASETS.each_value do |data|
            mine = AsciiArt::Stats.percentiles(data, ps)
            assert_equal data.percentile(ps), mine
        end
    end
end

# Constant data too large for a bin of width 1 to hold it.
class TestStatsHugeConstant < Minitest::Test
    def test_constant_huge_values_are_all_counted
        [1e16, 3e18].each do |v|
            hist = AsciiArt::Stats.histogram([v, v, v])
            assert_equal(3, hist.counts.sum)
        end
    end
end
