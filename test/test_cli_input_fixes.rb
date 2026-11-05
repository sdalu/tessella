# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Input regressions from the blind bug hunt: invalid UTF-8 is bad
# input in every command, lint --fences reads past it, bad data values
# exit 1, an overflowing sparkline value, a misspelt ramp, a bad PNM
# sample.
class TestCliInputFixes < Minitest::Test
    def cli(argv, input)
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(argv, stdin: StringIO.new(input),
                                         stdout: out, stderr: err)
        [status, err.string]
    end

    COMMANDS = [%w[chart], %w[table], %w[compose frame -], %w[tree],
                %w[seq], %w[wave], %w[bitfield], %w[sparkline],
                %w[text --style bold]].freeze

    def test_invalid_utf8_is_bad_input_everywhere
        COMMANDS.each do |argv|
            status, err = cli(argv, "caf\xE9 1\n".b)
            assert_equal([1, true], [status, err.include?("invalid UTF-8")],
                         argv.join(" "))
        end
    end

    def test_lint_fences_reads_past_invalid_utf8
        Dir.mktmpdir do |dir|
            path = File.join(dir, "bad.md")
            File.binwrite(path, "```\n\xFF\n```\n")
            status, err = cli(["lint", "--fences", path], "")
            assert_equal(1, status)
            assert_includes(err, "invalid UTF-8 byte sequence")
        end
    end

    def test_bad_data_values_are_bad_input
        [[%w[chart], "1\n1e400\n3\n"], [%w[chart --kind pie], "a 1\nb -2\n"],
         [%w[chart --kind candlestick], "1 10 5 12 8\n"],
         [%w[chart --xscale log10], "0 1\n1 2\n"],
         [%w[sparkline], "1 2 1e400\n"]]
            .each do |argv, input|
            assert_equal(1, cli(argv, input).first,
                         input)
        end
    end

    def test_a_misspelt_ramp_and_a_bad_sample_are_refused
        pgm = File.binread("examples/disc.pgm")
        assert_raises(ArgumentError) { Tessella.image(pgm, ramp: :blokcs) }
        assert_raises(ArgumentError) do
            Tessella.image("P2\n2 1\n255\n0 -128\n")
        end
    end
end
