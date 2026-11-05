# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# What every `tessella` command shares (DESIGN.md, "Command line"):
# a file that cannot be read is bad input, exit 1; an unknown option is
# a usage error, exit 2; --help answers 0. One loop over the commands,
# so a command added later is held to the same contract.
class TestCLIContract < Minitest::Test
    COMMANDS = [%w[chart], %w[compose frame], %w[tree], %w[table],
                %w[bitfield], %w[wave], %w[seq], %w[image],
                %w[lint]].freeze

    def run_cli(argv)
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(argv, stdin: StringIO.new(""),
                                         stdout: out, stderr: err)
        [status, err.string]
    end

    def test_every_command_is_listed_in_the_help
        out = StringIO.new
        Tessella::CLI.run(["--help"], stdin: StringIO.new, stdout: out,
                                      stderr: StringIO.new)
        COMMANDS.each { assert_includes(out.string, "  #{it.first} ") }
    end

    def test_an_unreadable_file_is_bad_input_in_every_command
        Dir.mktmpdir do |dir|
            [File.join(dir, "missing"), dir].each do |path|
                COMMANDS.each do |cmd|
                    status, err = run_cli([*cmd, path])
                    assert_equal(1, status, "#{cmd.join(" ")} #{path}: #{err}")
                end
            end
        end
    end

    # The reason in the system's own words, not Ruby's "@ rb_sysopen".
    def test_an_unreadable_file_is_named_with_its_reason
        Dir.mktmpdir do |dir|
            missing = File.join(dir, "missing")
            COMMANDS.each do |cmd|
                _, err = run_cli([*cmd, missing])
                want = ": cannot read #{missing}: No such file or directory\n"
                assert(err.end_with?(want), "#{cmd.join(" ")}: #{err}")
                refute_match(/rb_sysopen/, err, cmd.join(" "))
            end
        end
    end

    def test_an_unknown_option_is_a_usage_error_in_every_command
        COMMANDS.each do |cmd|
            status, err = run_cli([*cmd, "--bogus"])
            assert_equal(2, status, "#{cmd.join(" ")}: #{err}")
        end
    end

    def test_every_command_answers_help
        COMMANDS.each do |cmd|
            assert_equal(0, run_cli([cmd.first, "--help"]).first, cmd.first)
        end
    end

    def test_a_wave_period_below_two_is_a_usage_error
        assert_equal(2, run_cli(%w[wave --period 1]).first)
    end
end
