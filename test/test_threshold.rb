# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# threshold: a dashed rule at N, the value axis taking it in; under
# colour the cells beyond it take above: and the rest below:.
class TestThreshold < Minitest::Test
    Y = [10, 50, 90, 50, 10].freeze

    def chart(**) = Tessella.line(Y, width: 20, height: 5, **).to_s

    def test_a_dashed_rule_with_or_without_colour
        out = chart(threshold: 70)
        refute_equal(chart, out)
        refute_includes(out, "\e[")
    end

    def test_the_axis_takes_the_threshold_in
        assert_match(/^\s+200 │/, chart(threshold: 200))
    end

    def test_cells_beyond_take_above_and_the_rest_below
        out = chart(threshold: 70, color: true, above: :magenta, below: :cyan)
        assert_includes(out, "\e[35m")
        assert_includes(out, "\e[36m")
        top = out.lines[1]
        refute_includes(top, "\e[36m")
    end

    def test_refusals
        assert_raises(ArgumentError) { Tessella.line(Y, threshold: "x") }
        assert_raises(ArgumentError) do
            Tessella.line(Y, threshold: 1, above: :pink)
        end
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(%w[chart --threshold 2 --color],
                                   stdin: StringIO.new("1\n3\n"),
                                   stdout: out, stderr: StringIO.new)
        assert_equal(0, status)
        assert_includes(out.string, "\e[31m")
    end
end
