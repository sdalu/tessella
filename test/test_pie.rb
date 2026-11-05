# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.pie and `chart --kind pie`: slices clockwise from the top,
# told apart by fill, a ring under donut:, shares in the legend.
class TestPie < Minitest::Test
    def test_two_halves
        out = Tessella.pie(%w[a b], [1, 1], height: 4).to_s.lines
        assert_equal(["     ▓▓▓███\n", "    ▓▓▓▓████ █ a 50 %\n",
                      "    ▓▓▓▓████ ▓ b 50 %\n", "     ▓▓▓███\n"], out)
    end

    def test_a_donut_is_hollow
        rows = Tessella.pie(%w[a], [1], height: 8, donut: true).to_s.lines
        assert_match(/█ +█/, rows[4])
        refute_match(/█ +█/, Tessella.pie(%w[a], [1], height: 8).to_s.lines[4])
    end

    def test_ascii_and_colour
        out = Tessella.pie(%w[a b c], [1, 1, 2], height: 4, ascii: true).to_s
        assert(out.ascii_only?)
        assert_includes(out, "+ c 50 %")
        colored = Tessella.pie(%w[a b], [1, 3], height: 4, color: true).to_s
        assert_includes(colored, "\e[31m")
        assert_includes(colored, "\e[32m")
    end

    def test_shares_sum_to_a_hundred
        out = Tessella.pie(%w[a b c], [1, 1, 1], height: 4).to_s
        assert_equal(100, out.scan(/(\d+) %/).flatten.sum(&:to_i))
    end

    def test_more_slices_than_rows_go_under
        out = Tessella.pie(%w[a b c d e], [1, 2, 3, 4, 5], height: 4).to_s
        assert_equal("    █ a 7 %  ▓ b 13 %  ▒ c 20 %  ░ d 27 %\n",
                     out.lines[-2])
        assert_equal("    ╳ e 33 %\n", out.lines.last)
    end

    # Twelve fills, no two alike: a thirteenth slice is refused.
    def test_every_slice_its_own_fill
        out = Tessella.pie((1..12).map(&:to_s), [1] * 12, height: 4).to_s
        fills = out.scan(/(\S) \d+ \d+ %/).flatten
        assert_equal(12, fills.uniq.size)
        assert_raises(ArgumentError) do
            Tessella.pie((1..13).map(&:to_s), [1] * 13)
        end
    end

    def test_refusals
        assert_raises(ArgumentError) { Tessella.pie(%w[a b], [0, 0]) }
        assert_raises(ArgumentError) { Tessella.pie(%w[a b], [1, -1]) }
        assert_raises(ArgumentError) { Tessella.pie(%w[a], [1, 2]) }
        assert_raises(ArgumentError) { Tessella.pie(%w[a], [1], width: 9) }
    end

    def run_cli(argv, input)
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(argv, stdin: StringIO.new(input),
                                         stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def test_the_command
        status, out, = run_cli(%w[chart --kind pie --donut --height 8],
                               "name,share\nruby,1\nc,3\n")
        assert_equal(0, status)
        assert_includes(out, "▓ c 75 %")
    end

    def test_the_command_refuses
        status, _, err = run_cli(%w[chart --kind pie --width 9], "a 1\n")
        assert_equal(2, status)
        assert_includes(err, "--width is not valid with --kind pie")
        status, _, err = run_cli(%w[chart --kind bar --donut], "a 1\n")
        assert_equal(2, status)
        assert_includes(err, "--donut is not valid with --kind bar")
        status, _, err = run_cli(%w[chart --kind pie], "a 1 2\n")
        assert_equal(1, status)
        assert_includes(err, "pie reads label value")
    end
end
