# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.meter and `tessella meter`: one line, "[██████······] 50 %"
# as ui.md writes it; named fill/track pairs or one's own, never of
# two width classes; the block style fills by eighths.
class TestMeter < Minitest::Test
    def meter(*, **) = Tessella.meter(*, **).to_s.chomp

    def test_the_house_bar
        assert_equal("[██████████··········] 50 %", meter(0.5))
        assert_equal("[█████████···········] 45 %", meter("45%"))
    end

    def test_block_fills_its_last_cell_by_eighths
        assert_equal("███████▉····", meter(0.66, width: 12, label: false,
                                                 brackets: false))
    end

    def test_a_named_style_a_title_and_ascii
        assert_equal("cpu [★★★★★★☆☆] 73 %",
                     meter(0.73, style: :star, title: "cpu", width: 8))
        assert_equal("[=====     ] 50 %", meter(0.5, width: 10, ascii: true))
    end

    # The CLI passes the style as a String: block must still use eighths.
    def test_block_by_name_uses_eighths_and_titles_align
        assert_equal("ch 5 ████████████▍······· 62 %",
                     meter(0.62, style: "block", brackets: false,
                                 title: "ch 5"))
        assert_equal(["ch 5       [█▍] 70 %", "channel 12 [█▍] 70 %"],
                     ["ch 5", "channel 12"].map do |t|
                         meter(0.7, width: 2, title: t, title_width: 10)
                     end)
        assert_raises(ArgumentError) do
            meter(0.7, title: "channel 12", title_width: 4)
        end
    end

    def test_refusals
        assert_raises(ArgumentError) { meter(1.5) }
        assert_raises(ArgumentError) { meter(0.5, style: :rocket) }
        error = assert_raises(ArgumentError) { meter(0.5, style: "■░") }
        assert_match(/mixes width classes: A, N/, error.message)
    end

    def cli(*argv)
        out = StringIO.new
        status = Tessella::CLI.run(["meter", *argv], stdin: StringIO.new,
                                                     stdout: out,
                                                     stderr: StringIO.new)
        [status, out.string]
    end

    def test_the_command
        assert_equal([0, "[▸▸▸▹▹▹▹▹▹▹] 30 %\n"],
                     cli("--style", "arrow", "--width", "10", "0.3"))
        assert_equal(2, cli("2").first)
        assert_equal(2, cli.first)
        assert_equal(0, cli("--help").first)
    end
end
