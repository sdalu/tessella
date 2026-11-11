# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# `tessella lint`: artlint.rb's output contract, which the skills
# shelf parses -- findings on stderr as NAME:LINE: message, ruler rows
# and --alphabet answers on stdout, exit 0 clean, 1 on any finding,
# 2 on usage.
class TestLintCLI < Minitest::Test
    def lint(argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["lint", *argv], stdin: StringIO.new(stdin),
                                                    stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def with_files(files)
        Dir.mktmpdir do |dir|
            paths = files.map do |name, text|
                File.join(dir, name).tap { File.binwrite(it, text) }
            end
            yield paths
        end
    end

    def test_stdin_findings_are_named_stdin_and_exit_one
        assert_equal([1, "", "stdin:1: tab character\n"],
                     lint([], stdin: "a\tb\n"))
    end

    def test_a_clean_input_exits_zero_silently
        assert_equal([0, "", ""], lint([], stdin: "┌─┐\n"))
    end

    def test_every_file_is_linted_under_its_own_name
        with_files("a.txt" => "ok\n", "b.txt" => "x \n") do |a, b|
            assert_equal([1, "", "#{b}:1: trailing whitespace\n"],
                         lint([a, b]))
        end
    end

    def test_an_unreadable_file_fails_alone
        with_files("b.txt" => "x \n") do |(b)|
            status, _, err = lint(["/nonexistent/a", b])
            assert_equal(1, status)
            assert_equal("tessella lint: cannot read /nonexistent/a: No " \
                         "such file or directory\n", err.lines.first)
            assert_equal("#{b}:1: trailing whitespace\n", err.lines.last)
        end
    end

    def test_ruler_rows_go_to_stdout
        assert_equal([0, "stdin:1: width=7  verticals=3,7\n" \
                         "stdin:2: width=2\n", ""],
                     lint(["--ruler", "--prefix", "  "], stdin: "│ a │\n\n"))
    end

    def test_suffix_is_charged_to_the_budget
        assert_equal([1, "", "stdin:1: 6 columns rendered (budget 5)\n"],
                     lint(["--width", "5", "--suffix", " -->"], stdin: "ab\n"))
    end

    def test_alphabet_answers_on_stdout_and_exits_zero
        assert_equal([0, "stdin: ascii\n", ""],
                     lint(["--alphabet"], stdin: "a\tb \n"))
    end

    def test_forbid_repeats_and_takes_presets
        status, _, err = lint(%w[--forbid c-block --forbid ZZ],
                              stdin: "*/ ZZ\n")
        assert_equal(1, status)
        assert_equal(["stdin:1: forbidden sequence \"*/\"",
                      "stdin:1: forbidden sequence \"ZZ\""],
                     err.lines(chomp: true))
    end

    def test_fences_and_geometry_flags
        text = "x\t\n```\n┌──┐\n│ab │\n└──┘\n```\n"
        status, _, err = lint(%w[--fences --geometry], stdin: text)
        assert_equal(1, status)
        assert_equal(["stdin:4: side of box opened at line 3 col 1 is off " \
                      "at col 4", "stdin:4: connector '│' at col 5 hangs " \
                                  "from ' '"], err.lines(chomp: true))
    end

    def test_a_bad_width_is_a_usage_error
        status, _, err = lint(%w[--width 0])
        assert_equal(2, status)
        assert_match(/width must be a positive Integer/, err)
    end

    def test_paranoid_is_gone
        assert_equal(2, lint(["--paranoid"]).first)
    end

    def test_help_describes_every_option_within_80_columns
        status, out, = lint(["--help"])
        assert_equal(0, status)
        assert(out.lines.all? { it.chomp.length <= 80 }, out)
        %w[--width --prefix --suffix --ruler --forbid --web --no-wide --ascii
           --alphabet --allow-mixed --fences --geometry].each do |flag|
            assert_match(/^\s+#{flag}\b.*\S\s{2,}\S/, out, flag)
        end
    end
end
