# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Table regressions from the blind bug hunt: a blank line, a long
# title, markdown pipes and ASCII, cjk fitting and minimal edges, and
# "-" for stdin.
class TestTableFixes < Minitest::Test
    T = Tessella::Target

    def test_a_blank_line_is_no_rows
        assert_raises(ArgumentError) { Tessella.table([[]]) }
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(%w[table], stdin: StringIO.new("\n"),
                                              stdout: out, stderr: err)
        assert_equal(1, status)
    end

    def test_a_long_title_widens_the_table
        lines = Tessella.table([%w[a b], %w[1 2]], title: "a much longer title")
                        .to_s.lines.map { Tessella::Width.of(it.chomp) }
        assert_equal(1, lines.uniq.size)
    end

    def test_markdown_escapes_a_pipe_and_stays_markdown_under_ascii
        md = Tessella.table([%w[a b], ["x|y", "2"]], style: :markdown).to_s
        assert_includes(md, "| x\\|y |")
        ascii = Tessella.table([%w[a b], %w[1 2]], style: :markdown,
                                                   ascii: true).to_s
        assert(ascii.start_with?("| a"))
    end

    def cjk_widths(rows, **)
        T.with(:cjk) do
            Tessella.table(rows, ascii: false, **)
                    .lines.map { Tessella::Width.of(it) }
        end
    end

    def test_cjk_tables_fit_their_width_and_close
        rows = [%w[name description],
                ["alpha", "a fairly long description of the thing"]]
        assert(cjk_widths(rows, width: 30).all? { it <= 30 })
        minimal = T.with(:cjk) do
            Tessella.table([%w[a bb], %w[1 2]], style: :minimal, ascii: false)
                    .lines.map { Tessella::Width.of(it) }
        end
        assert_equal(1, minimal.uniq.size)
    end

    def test_a_dash_reads_stdin
        out = StringIO.new
        Tessella::CLI.run(%w[table -], stdin: StringIO.new("a,b\n1,2\n"),
                                       stdout: out, stderr: StringIO.new)
        assert_includes(out.string, "│ a │")
    end
end
