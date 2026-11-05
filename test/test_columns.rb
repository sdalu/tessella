# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Bar and histogram layouts besides unicode_plot's horizontal eighths
# (DESIGN.md, "Chart and kinds"): orientation: :vertical columns, and
# blocks: :braille / :block, which pack bars into one character.
class TestColumns < Minitest::Test
    def body(chart)
        chart.to_s.lines[1..-2].filter_map { it[/[│|](.*)[│|]/, 1] }
    end

    def test_vertical_eighths_rise_by_eighths_with_a_gap
        chart = Tessella.bar(%w[a b], [8, 4], orientation: :vertical,
                                              height: 1, width: 3)
        assert_equal(["█ ▄"], body(chart))
        assert_match(/^   8 │/, chart.to_s)
        assert_includes(chart.to_s, "      a b\n")
    end

    def test_vertical_braille_holds_two_columns_per_character
        chart = Tessella.bar(%w[a b c d], [4, 1, 3, 2],
                             orientation: :vertical, blocks: :braille,
                             height: 1, width: 2)
        assert_equal(["⣇⣦"], body(chart))
    end

    def test_horizontal_braille_holds_four_rows_per_character
        chart = Tessella.bar(%w[a b c d], [4, 1, 3, 2], blocks: :braille,
                                                        width: 2)
        assert_equal(["⣯⠍"], body(chart))
        assert_includes(chart.to_s, "a..d │")
    end

    def test_horizontal_block_holds_two_rows_per_character
        chart = Tessella.bar(%w[a b], [2, 1], blocks: :block, width: 1)
        assert_equal(["▛"], body(chart))
    end

    def test_quadrant_is_the_block_glyphs_by_their_image_name
        cols = lambda do |blocks|
            body(Tessella.bar(%w[a b], [2, 1], blocks: blocks, height: 1,
                                               orientation: :vertical,
                                               width: 1))
        end
        assert_equal(["▙"], cols.call(:quadrant))
        assert_equal(cols.call(:block), cols.call(:quadrant))
        line = Tessella.line([1, 2], area: true, canvas: :quadrant)
        assert_equal(Tessella.line([1, 2], area: true, canvas: :block).to_s,
                     line.to_s)
    end

    # Halves: one bar per character, half a cell per step.
    def test_half_blocks_step_by_half_a_cell
        up = Tessella.bar(%w[a b], [2, 1], blocks: :half, height: 1,
                                           orientation: :vertical, width: 2)
        assert_equal(["█▄"], body(up))
        across = Tessella.bar(%w[a b], [2, 1], blocks: :half, width: 1)
        assert_equal(["█", "▌"], body(across))
        area = Tessella.line([2, 1], xlim: [0.5, 2.5], area: true,
                                     canvas: :half, width: 2, height: 1)
        assert_equal(["█▄"], body(area))
    end

    def test_a_vertical_histogram_names_its_axis_ends_and_frequency
        out = Tessella.histogram([1, 2, 2, 3, 3, 3], bins: 3,
                                                     orientation: :vertical,
                                                     height: 3).to_s
        assert_includes(out, "Frequency")
        assert_match(/^\s+1\.0\s+4\.0$/, out)
    end

    def test_ascii_vertical_columns_are_ascii
        out = Tessella.bar(%w[a b], [3, 1], orientation: :vertical,
                                            ascii: true, height: 3).to_s
        assert_predicate(out, :ascii_only?)
        assert_includes(out, "#")
    end

    def test_refusals
        [{ orientation: :diagonal }, { blocks: :hex },
         { blocks: :braille, ascii: true }, { blocks: :braille, fill: "x" }]
            .each do |opts|
            assert_raises(ArgumentError, opts.inspect) do
                Tessella.bar(%w[a], [1], **opts).to_s
            end
        end
        assert_raises(ArgumentError) do
            Tessella.bar(%w[a b], [1, -1], orientation: :vertical).to_s
        end
    end

    def cli(argv, input = "a 3\nb 5\n")
        Tessella::CLI.run(["chart", *argv], stdin: StringIO.new(input),
                                            stdout: StringIO.new,
                                            stderr: StringIO.new)
    end

    def test_the_command_takes_orientation_and_blocks_for_bar_kinds
        assert_equal(0, cli(%w[--kind bar --orientation vertical]))
        assert_equal(0, cli(%w[--kind histogram --blocks braille],
                            "1\n2\n3\n"))
        assert_equal(2, cli(%w[--blocks braille], "1\n2\n"))
        assert_equal(2, cli(%w[--kind bar --orientation sideways]))
        assert_equal(2, cli(%w[--kind bar --orientation vertical --track .]))
    end
end

# What the new layouts refuse, and how they round.
class TestColumnsRules < Minitest::Test
    def body(chart)
        chart.to_s.lines[1..-2].filter_map { it[/[│|](.*)[│|]/, 1] }
    end

    def test_a_negative_value_names_the_exact_layout
        error = assert_raises(ArgumentError) do
            Tessella.bar(%w[a b], [1, -1], orientation: :vertical).to_s
        end
        assert_match(/a vertical eighths bar chart needs values of 0/,
                     error.message)
    end

    def test_track_is_refused_for_upright_bars
        assert_raises(ArgumentError) do
            Tessella.bar(%w[a], [1], orientation: :vertical, track: ".")
        end
    end

    # A value above zero shows at least one step, however small.
    def test_a_small_value_is_never_drawn_empty
        [{}, { ascii: true }, { blocks: :braille }, { blocks: :half }]
            .each do |opts|
            chart = Tessella.bar(%w[a b], [1, 1000], orientation: :vertical,
                                                     height: 2, width: 4,
                                                     **opts)
            assert_match(/\S/, body(chart).last[0, 2], opts.inspect)
        end
        across = Tessella.bar(%w[a b], [1, 1000], blocks: :braille, width: 4)
        refute_equal("⠀", body(across).first[0])
    end
end
