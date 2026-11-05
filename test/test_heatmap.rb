# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.heatmap / `tessella chart --kind heatmap`: a matrix as
# shaded cells, two columns each by default, a key for the range.
class TestHeatmap < Minitest::Test
    M = [[0, 1], [2, 4]].freeze

    def lines(**) = Tessella.heatmap(M, **).to_s.lines(chomp: true)

    def test_cells_shade_along_the_ramp_with_a_key
        out = lines(ylabels: %w[a b])
        assert_equal("   a │  ░░│ █ 4", out[1])
        assert_equal("   b │▒▒██│   0", out[2])
    end

    def test_ascii_and_cell_width
        out = lines(ascii: true, cell_width: 1)
        assert_equal("| :|", out[1][/\|.*\|/][0, 4])
        assert_predicate(out.join, :ascii_only?)
    end

    def test_colour_and_a_fixed_range
        out = Tessella.heatmap(M, color: true, min: 0, max: 8).to_s
        assert_includes(out, "\e[38;2;")
        assert_includes(out, "max 8")
    end

    def test_column_names_need_a_gap
        assert_includes(lines(xlabels: %w[a b]).last, " a b")
        assert_includes(lines(xlabels: %w[aa bb]).last, "aa  bb")
    end

    def test_refusals
        assert_raises(ArgumentError) { Tessella.heatmap([[1, 2], [3]]) }
        assert_raises(ArgumentError) { Tessella.heatmap(M, width: 10) }
        assert_raises(ArgumentError) { Tessella.heatmap(M, colormap: [:pink]) }
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(%w[chart --kind heatmap],
                                   stdin: StringIO.new("h x y\na 0 1\nb 2 4\n"),
                                   stdout: out, stderr: StringIO.new)
        assert_equal(0, status)
        assert_includes(out.string, "a │  ░░│ █ 4")
    end
end
