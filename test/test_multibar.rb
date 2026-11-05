# frozen_string_literal: true

require_relative "test_helper"

# Bars of several series: grouped (a bar a series under each label) or
# stacked (end to end, labelled with the total), across or upright;
# fills tell series apart without colour, and eighths end only █ ones.
class TestMultiBar < Minitest::Test
    LABELS = %w[q1 q2].freeze
    VALUES = [[3, 5], [4, 2]].freeze

    def bar(**) = Tessella.bar(LABELS, VALUES, series: %w[cpu io], **).to_s

    def test_grouped_rows_with_a_legend
        out = bar(width: 16)
        assert_match(/q1 ┤█+[▏▎▍▌▋▊▉]?·* 3  █ cpu/, out)
        assert_match(/┤▓+·* 5  ▓ io/, out)
        assert_equal(1, out.lines.count { it.strip == "┤" })
    end

    def test_stacked_rows_end_to_end_with_the_total
        out = bar(width: 16, stacked: true)
        assert_match(/q1 ┤█+▓+·* 8 /, out)
        assert_match(/q2 ┤█+▓+·* 6/, out)
    end

    def test_upright_grouped_and_stacked
        grouped = bar(orientation: :vertical, height: 4, width: 9)
        assert_match(/│.*█.*▓.*│/, grouped)
        assert_includes(grouped, "q1")
        stacked = bar(orientation: :vertical, stacked: true, height: 4,
                      width: 5)
        assert_match(/^\s+8 │/, stacked)
    end

    def test_eighths_end_only_a_solid_series
        out = Tessella.bar(%w[a], [[7, 7]], width: 16).to_s
        refute_match(/▓[▏▎▍▌▋▊▉]/, out)
    end

    def test_ascii_fills
        out = bar(width: 16, stacked: true, ascii: true)
        assert_predicate(out, :ascii_only?)
        assert_match(/#+=+/, out)
    end

    def test_refusals
        assert_raises(ArgumentError) { Tessella.bar(%w[a b], [[1, 2], [3]]) }
        assert_raises(ArgumentError) { Tessella.bar(%w[a], [[1, -2]]).to_s }
        assert_raises(ArgumentError) do
            Tessella.bar(%w[a], [[1, 2]], blocks: :braille).to_s
        end
    end
end
