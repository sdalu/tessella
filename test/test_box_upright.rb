# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Box's orientation: :vertical -- boxes three columns wide, whiskers
# running up and down, the value axis on the left, names under.
class TestBoxUpright < Minitest::Test
    def test_a_box_stands_from_its_minimum_to_its_maximum
        out = Tessella.box(%w[a], [[0, 1, 2, 3, 4]], orientation: :vertical,
                                                     height: 5).to_s
        assert_equal(["     ┌────┐", "   4 │╶┬╴ │", "     │┌┴┐ │",
                      "   2 │├─┤ │", "     │└┬┘ │", "   0 │╶┴╴ │",
                      "     └────┘", "       a"], out.lines(chomp: true))
    end

    def test_the_median_wins_a_shared_row
        out = Tessella.box(%w[a], [[0, 2, 2, 2, 4]], orientation: :vertical,
                                                     height: 3).to_s
        assert_includes(out.lines[2], "├─┤")
    end

    def test_ascii_boxes_are_ascii
        out = Tessella.box(%w[a], [[0, 1, 2, 3, 4]], orientation: :vertical,
                                                     height: 5,
                                                     ascii: true).to_s
        assert_predicate(out, :ascii_only?)
        assert_includes(out, "|-|")
    end

    def test_an_unknown_orientation_is_refused
        assert_raises(ArgumentError) do
            Tessella.box(%w[a], [[1, 2]], orientation: :diagonal)
        end
    end

    def test_the_command_takes_orientation_for_box
        status = Tessella::CLI.run(
            %w[chart --kind box --orientation vertical],
            stdin: StringIO.new("1 2\n3 4\n"), stdout: StringIO.new,
            stderr: StringIO.new
        )
        assert_equal(0, status)
    end
end
