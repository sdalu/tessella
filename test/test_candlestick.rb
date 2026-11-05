# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.candlestick and `chart --kind candlestick`: a wick from low
# to high, a body from open to close, up █ and down ▒.
class TestCandlestick < Minitest::Test
    def body(chart) = chart.to_s.lines[1..-3].map { it[/│(.*)│/, 1] }

    def test_an_up_and_a_down_candle
        out = Tessella.candlestick(open: [1, 3], high: [4, 4], low: [0, 0],
                                   close: [3, 1], height: 5)
        assert_equal(["│ │", "█ ▒", "█ ▒", "█ ▒", "│ │"], body(out))
    end

    def test_a_flat_body_and_ascii
        out = Tessella.candlestick(open: [2], high: [4], low: [0], close: [2],
                                   height: 3, ascii: true)
        assert_equal(%w[| - |], out.to_s.lines[1..-3].map { it[/\|(.)\|/, 1] })
    end

    def test_colour_and_dates
        days = [Time.utc(2026, 11, 2), Time.utc(2026, 11, 3)]
        out = Tessella.candlestick(days, open: [1, 3], high: [4, 4],
                                         low: [0, 0], close: [3, 1],
                                         height: 3, color: true).to_s
        assert_includes(out, "\e[32m")
        assert_includes(out, "\e[31m")
        assert_includes(out.lines.last, "2026-11-02 2026-11-03")
    end

    def test_refusals
        assert_raises(ArgumentError) do
            Tessella.candlestick(open: [1], high: [0], low: [0], close: [1])
        end
        assert_raises(ArgumentError) do
            Tessella.candlestick(open: [1, 2], high: [3], low: [0], close: [1])
        end
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(
            %w[chart --kind candlestick --height 3],
            stdin: StringIO.new("a 1 4 0 3\nb 3 4 0 1\n"),
            stdout: out, stderr: StringIO.new
        )
        assert_equal(0, status)
        assert_includes(out.string, "█")
    end
end
