# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# DESIGN.md's "ASCII from the first byte": under ascii: true no text
# drawn into a figure may carry a non-ASCII character -- refused,
# named, never passed through. A bit-field is always ASCII. One case
# per module that once let such text through (table, bitfield, wave,
# chart), in the library and on the command line.
class TestAsciiRule < Minitest::Test
    def refused(pattern, &)
        assert_match(pattern, assert_raises(ArgumentError, &).message)
    end

    def test_table_refuses_a_non_ascii_cell_or_title
        refused(/row 2, column 2 is non-ASCII/) do
            Tessella.table([%w[a b], %w[1 é]], ascii: true)
        end
        refused(/title is non-ASCII/) do
            Tessella.table([%w[a]], ascii: true, title: "é")
        end
        assert_includes(Tessella.table([%w[a b], %w[1 é]]).to_s, "é")
    end

    def test_bitfield_refuses_a_non_ascii_name_always
        refused(/line 1: name "é" is non-ASCII/) { Tessella.bitfield("é:8\n") }
        refused(/field 1: name/) { Tessella.bitfield([["é", 8]]) }
    end

    def test_wave_refuses_a_non_ascii_name_or_label
        refused(/line 1 is non-ASCII/) do
            Tessella.wave("é: 01\n", ascii: true)
        end
        refused(/line 1 is non-ASCII/) do
            Tessella.wave("a: =. | ü\n", ascii: true)
        end
        assert_includes(Tessella.wave("é: 01\n").to_s, "é")
    end

    def test_chart_refuses_non_ascii_text_anywhere_in_the_figure
        refused(/chart line 1 is non-ASCII/) do
            Tessella.line([1, 2], ascii: true, title: "tï").to_s
        end
        refused(/is non-ASCII/) do
            Tessella.bar(%w[é b], [1, 2], ascii: true).to_s
        end
    end
end

# The same refusals through `tessella`: a non-ASCII input line is bad
# input (exit 1); a non-ASCII option value is usage (exit 2).
class TestAsciiRuleCLI < Minitest::Test
    def status(argv, input)
        Tessella::CLI.run(argv, stdin: StringIO.new(input),
                                stdout: StringIO.new, stderr: StringIO.new)
    end

    def test_non_ascii_input_is_bad_input
        assert_equal(1, status(%w[table --ascii], "a,b\n1,é\n"))
        assert_equal(1, status(%w[bitfield], "é:8\n"))
        assert_equal(1, status(%w[wave --ascii], "é: 01\n"))
        assert_equal(1, status(%w[chart --kind bar --ascii], "é,1\nb,2\n"))
    end

    def test_a_non_ascii_chart_title_is_usage
        assert_equal(2, status(["chart", "--ascii", "--title", "tï"],
                               "1\n2\n"))
    end
end
