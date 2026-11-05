# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# --help for a compose subcommand and for image: the subcommand's own
# usage line, every option described, nothing past 80 columns, and
# exit 0 without leaving the process (CLI.run returns, as in a test).
class TestHelp < Minitest::Test
    def help(argv)
        out = StringIO.new
        status = Tessella::CLI.run(argv, stdin: StringIO.new, stdout: out,
                                         stderr: StringIO.new)
        [status, out.string]
    end

    def described?(text)
        text.lines.grep(/^\s+--/).all? { it.strip.split(/\s{2,}/).size >= 2 }
    end

    def test_each_compose_subcommand_has_its_own_help
        %w[frame beside stack indent caption shadow fill grid].each do |sub|
            status, out = help(["compose", sub, "--help"])
            assert_equal(0, status, sub)
            assert(out.start_with?("Usage: tessella compose #{sub} "), out)
            assert(described?(out), out)
            assert(out.lines.all? { it.chomp.length <= 80 }, out)
        end
    end

    def test_image_describes_every_option
        status, out = help(%w[image --help])
        assert_equal(0, status)
        assert(described?(out), out)
        assert(out.lines.all? { it.chomp.length <= 80 }, out)
    end
end
