# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# orientation: :horizontal for the plotted kinds: the axes swap, so a
# horizontal chart of (x, y) is the vertical chart of (y, x), limits
# and labels following their axis; an area fills from the left edge.
class TestSideways < Minitest::Test
    XS = [1, 2, 3, 4].freeze
    YS = [1, 4, 9, 16].freeze

    def test_horizontal_is_the_vertical_chart_of_the_swapped_data
        %i[line scatter density].each do |kind|
            assert_equal(Tessella.public_send(kind, YS, XS).to_s,
                         Tessella.public_send(kind, XS, YS,
                                              orientation: :horizontal).to_s,
                         kind)
        end
    end

    # A sideways staircase is the upright one turned: its steps run
    # along x, so it is the line through the turned step corners.
    def test_horizontal_stairs_turn_the_steps
        assert_equal(Tessella.line([1, 1, 4, 4], [1, 2, 2, 3]).to_s,
                     Tessella.stairs([1, 2, 3], [1, 4, 4],
                                     orientation: :horizontal).to_s)
    end

    def test_limits_and_labels_follow_their_axis
        assert_equal(Tessella.line(YS, XS, xlim: [0, 20], ylim: [0, 5],
                                           xlabel: "y", ylabel: "x").to_s,
                     Tessella.line(XS, YS, xlim: [0, 5], ylim: [0, 20],
                                           xlabel: "x", ylabel: "y",
                                           orientation: :horizontal).to_s)
    end

    def test_an_area_fills_from_the_left_edge
        c = Tessella::Canvas.build(:braille, width: 1, height: 1,
                                             xlim: [0, 2], ylim: [0, 4])
        c.area([2, 1, 2, 1], [3.5, 2.5, 1.5, 0.5], across: true)
        assert_equal("⡯", c.rows.first.first.char)
    end

    def test_a_horizontal_area_takes_in_zero_on_the_value_axis
        out = Tessella.line([5, 6], area: true, orientation: :horizontal,
                                    width: 10, height: 2).to_s
        assert_match(/^\s+0\s+\S+$/, out.lines.last)
    end

    def test_an_unknown_orientation_is_refused
        assert_raises(ArgumentError) { Tessella.line(YS, orientation: :up) }
    end

    def cli(argv)
        Tessella::CLI.run(["chart", *argv], stdin: StringIO.new("1\n2\n"),
                                            stdout: StringIO.new,
                                            stderr: StringIO.new)
    end

    def test_the_command_takes_orientation_for_every_kind_but_stem
        assert_equal(0, cli(%w[--orientation horizontal --area]))
        assert_equal(0, cli(%w[--kind scatter --orientation horizontal]))
        assert_equal(2, cli(%w[--kind stem --orientation horizontal]))
    end
end
