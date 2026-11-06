# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require_relative "../lib/tessella/cli"
require_relative "oracle"

# Runs a tessella command as the tests do: runner (the tessella
# command, or one command's class) on argv, input on stdin. Returns
# [status, stdout, stderr]; each test file's own helper picks from it.
module CommandHelper
    def run_command(argv, input = "", runner: Tessella::CLI, **)
        out = StringIO.new
        err = StringIO.new
        status = runner.run(argv, stdin: StringIO.new(input), stdout: out,
                                  stderr: err, **)
        [status, out.string, err.string]
    end
end

Minitest::Test.include(CommandHelper)
