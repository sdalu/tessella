# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Tessella.table's box and markdown styles, title row and down-tee
# rule, ported byte for byte from the ascii-art skill's
# scripts/table.rb (check-table.sh's cases A and B, the glyph sets,
# and the title rule).
class TestTable < Minitest::Test
    MODES = [%w[Mode BW Range], ["LR", "499.2", "200 m"],
             ["HPRF", "499.2", "80 m"]].freeze
    AB = [%w[a b], %w[1 2]].freeze

    def test_a_mixed_csv_light_style_byte_for_byte
        assert_equal(<<~OUT, Tessella.table(MODES).to_s)
            ┌──────┬───────┬───────┐
            │ Mode │    BW │ Range │
            ├──────┼───────┼───────┤
            │ LR   │ 499.2 │ 200 m │
            │ HPRF │ 499.2 │ 80 m  │
            └──────┴───────┴───────┘
        OUT
    end

    def test_a_headerless_numeric_tsv_ascii_style
        rows = [%w[1 2], %w[10 20]]
        out = Tessella.table(rows, header: false, style: :ascii).to_s
        assert_equal(<<~OUT, out)
            +----+----+
            |  1 |  2 |
            | 10 | 20 |
            +----+----+
        OUT
    end

    def test_every_style_draws_its_own_glyphs
        {
            heavy: "┏━━━┳━━━┓\n┃ a ┃ b ┃\n┣━━━╋━━━┫\n┃ 1 ┃ 2 ┃\n┗━━━┻━━━┛\n",
            double: "╔═══╦═══╗\n║ a ║ b ║\n╠═══╬═══╣\n║ 1 ║ 2 ║\n╚═══╩═══╝\n",
            rounded: "╭───┬───╮\n│ a │ b │\n├───┼───┤\n│ 1 │ 2 │\n╰───┴───╯\n"
        }.each do |style, want|
            assert_equal(want, Tessella.table(AB, style: style).to_s, style)
        end
    end

    def test_minimal_style_has_dividers_only_no_outer_frame
        assert_equal(<<~OUT, Tessella.table(AB, style: :minimal).to_s)
                ╷
              a │ b
            ╶───┼───╴
              1 │ 2
                ╵
        OUT
    end

    def test_markdown_is_a_native_gfm_pipe_table
        assert_equal("| a | b |\n|--:|--:|\n| 1 | 2 |\n",
                     Tessella.table(AB, style: :markdown).to_s)
    end

    def test_markdown_delimiters_left_right_center
        out = Tessella.table(MODES, style: :markdown, align: "lrc").to_s
        assert_equal(<<~OUT, out)
            | Mode |    BW | Range |
            |------|------:|:-----:|
            | LR   | 499.2 | 200 m |
            | HPRF | 499.2 | 80 m  |
        OUT
    end

    def test_title_adds_a_centred_row_inside_the_frame
        assert_equal(<<~OUT, Tessella.table(AB, title: "Pair").to_s)
            ┌───────┐
            │ Pair  │
            ├───┬───┤
            │ a │ b │
            ├───┼───┤
            │ 1 │ 2 │
            └───┴───┘
        OUT
    end

    def test_title_rule_uses_the_down_tee_not_the_cross
        {
            heavy: "┳", double: "╦", rounded: "┬", ascii: "+"
        }.each do |style, tee|
            lines = Tessella.table(AB, style: style, title: "Pair").lines
            assert_includes(lines[2], tee, style)
        end
    end
end

# The numeric/align rules (Ruby's own Integer()/Float() reading), the
# output-hygiene guarantees (ASCII, no tab, no trailing blank, a
# single wide column), and the living-spec example (CJK, quoting, a
# title), all together.
class TestTableAlignment < Minitest::Test
    AB = [%w[a b], %w[1 2]].freeze
    NAMES = [%w[name n], %w[alice 1], %w[bob 22]].freeze
    FORMS = [%w[n other], %w[200 x], %w[80 x], %w[30 x], %w[1e3 x],
             ["", "x"]].freeze
    FORMS_WANT = <<~OUT
        ┌─────┬───────┐
        │   n │ other │
        ├─────┼───────┤
        │ 200 │ x     │
        │  80 │ x     │
        │  30 │ x     │
        │ 1e3 │ x     │
        │     │ x     │
        └─────┴───────┘
    OUT

    UWB_TEXT = <<~CSV
        Mode,BW (MHz),Range,Note
        LR,499.2,200,long range
        HPRF,499.2,80,
        高速,1081.6,30,中文
        "a,b",-12,1e3,"quoted ""x"""
    CSV

    UWB_WANT = <<~OUT
        ┌──────────────────────────────────────┐
        │              UWB modes               │
        ├──────┬──────────┬───────┬────────────┤
        │ Mode │ BW (MHz) │ Range │ Note       │
        ├──────┼──────────┼───────┼────────────┤
        │ LR   │    499.2 │   200 │ long range │
        │ HPRF │    499.2 │    80 │            │
        │ 高速 │   1081.6 │    30 │ 中文       │
        │ a,b  │      -12 │   1e3 │ quoted "x" │
        └──────┴──────────┴───────┴────────────┘
    OUT

    def test_numeric_detection_follows_integer_and_float
        assert_equal(FORMS_WANT, Tessella.table(FORMS).to_s)
    end

    def test_auto_align_text_left_numbers_right
        assert_equal(<<~OUT, Tessella.table(NAMES).to_s)
            ┌───────┬────┐
            │ name  │  n │
            ├───────┼────┤
            │ alice │  1 │
            │ bob   │ 22 │
            └───────┴────┘
        OUT
    end

    def test_align_overrides_the_numeric_column_to_left
        out = Tessella.table(NAMES, align: "ll").to_s
        assert_equal(<<~OUT, out)
            ┌───────┬────┐
            │ name  │ n  │
            ├───────┼────┤
            │ alice │ 1  │
            │ bob   │ 22 │
            └───────┴────┘
        OUT
    end

    def test_no_header_treats_every_row_as_data
        assert_equal("┌───┬───┐\n│ a │ b │\n│ 1 │ 2 │\n└───┴───┘\n",
                     Tessella.table(AB, header: false).to_s)
    end

    def test_ascii_draws_no_non_ascii_byte
        assert(Tessella.table(AB, ascii: true).to_s.ascii_only?)
    end

    def test_no_tab_and_no_trailing_blank_in_any_line
        out = Tessella.table(AB, style: :minimal).to_s
        refute_includes(out, "\t")
        out.each_line { |l| refute_match(/ +\n\z/, l) }
    end

    def test_a_single_wide_column_still_renders
        row = "x" * 90
        out = Tessella.table([["Header"], [row]]).to_s
        assert_equal(94, out.lines.first.rstrip.length)
    end

    def test_the_living_spec_example_byte_for_byte
        rows = Tessella::Table.parse(UWB_TEXT)
        out = Tessella.table(rows, title: "UWB modes").to_s
        assert_equal(UWB_WANT, out)
    end
end

# Every refusal: a ragged row, an empty table, an unknown style, and
# an align: of the wrong length or letters.
class TestTableRefusals < Minitest::Test
    AB = [%w[a b], %w[1 2]].freeze

    def test_a_ragged_row_is_refused_naming_the_line
        error = assert_raises(ArgumentError) do
            Tessella.table([%w[a b], %w[1 2 3]])
        end
        assert_includes(error.message, "line 2")
    end

    def test_no_rows_at_all_is_refused
        assert_raises(ArgumentError) { Tessella.table([]) }
    end

    def test_an_unknown_style_is_refused
        assert_raises(ArgumentError) { Tessella.table(AB, style: :triangle) }
    end

    def test_align_of_the_wrong_length_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.table(AB, align: "lrc")
        end
        assert_includes(error.message, "3 letters")
        assert_includes(error.message, "2 columns")
    end

    def test_align_with_an_unknown_letter_is_refused
        assert_raises(ArgumentError) { Tessella.table(AB, align: "lx") }
    end
end

# The hand-written RFC 4180 reader (no "csv" gem: DESIGN.md's "no
# runtime dependency"): quoted fields, "" escapes, a separator or
# newline inside quotes, CRLF, and TSV.
class TestTableCSVReader < Minitest::Test
    def test_plain_rows
        assert_equal([%w[a b], %w[1 2]], Tessella::Table.parse("a,b\n1,2\n"))
    end

    def test_a_quoted_field_may_hold_the_separator
        assert_equal([%w[a b], ["x,y", "2"]],
                     Tessella::Table.parse("a,b\n\"x,y\",2\n"))
    end

    def test_a_doubled_quote_is_one_literal_quote
        assert_equal([%w[a b], ["x\"y", "2"]],
                     Tessella::Table.parse("a,b\n\"x\"\"y\",2\n"))
    end

    def test_a_quoted_field_may_hold_a_newline
        assert_equal([%w[a b], %W[x\ny 2]],
                     Tessella::Table.parse("a,b\n\"x\ny\",2\n"))
    end

    def test_crlf_row_endings
        assert_equal([%w[a b], %w[1 2]],
                     Tessella::Table.parse("a,b\r\n1,2\r\n"))
    end

    def test_lone_cr_row_endings
        assert_equal([%w[a b], %w[1 2]],
                     Tessella::Table.parse("a,b\r1,2\r"))
    end

    def test_tsv_uses_tab_as_the_separator
        assert_equal([%w[a b], %w[1 2]],
                     Tessella::Table.parse("a\tb\n1\t2\n", tsv: true))
    end

    def test_a_quoted_empty_field_is_an_empty_string
        assert_equal([%w[a b], ["", "2"]],
                     Tessella::Table.parse("a,b\n\"\",2\n"))
    end

    def test_a_trailing_comma_adds_a_trailing_empty_field
        assert_equal([%w[a b], ["1", ""]],
                     Tessella::Table.parse("a,b\n1,\n"))
    end

    def test_a_blank_line_is_a_row_with_no_fields
        assert_equal([%w[a b], [], %w[1 2]],
                     Tessella::Table.parse("a,b\n\n1,2\n"))
    end

    def test_empty_text_is_no_rows
        assert_equal([], Tessella::Table.parse(""))
    end

    def test_an_unterminated_quote_is_refused
        assert_raises(ArgumentError) do
            Tessella::Table.parse("a,b\n\"unterminated\n1,2\n")
        end
    end

    def test_a_stray_quote_mid_field_is_refused
        assert_raises(ArgumentError) do
            Tessella::Table.parse("a,b\nx\"y,2\n")
        end
    end

    SPEC_TEXT = <<~CSV
        Mode,BW (MHz),Range,Note
        LR,499.2,200,long range
        HPRF,499.2,80,
        "a,b",-12,1e3,"quoted ""x"""
    CSV

    # The records CSV.parse returns for SPEC_TEXT (Ruby 3.4's csv,
    # blank fields as ""), written out so the test needs no csv gem.
    SPEC_ROWS = [["Mode", "BW (MHz)", "Range", "Note"],
                 ["LR", "499.2", "200", "long range"],
                 ["HPRF", "499.2", "80", ""],
                 ["a,b", "-12", "1e3", 'quoted "x"']].freeze

    def test_matches_csv_parse_on_the_living_spec_example
        assert_equal(SPEC_ROWS, Tessella::Table.parse(SPEC_TEXT))
    end
end

class TestTableCLI < Minitest::Test
    def run_cli(*argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["table", *argv],
                                   stdin: StringIO.new(stdin),
                                   stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def test_draws_from_stdin_and_exits_zero
        status, out, = run_cli(stdin: "a,b\n1,2\n")
        assert_equal(0, status)
        assert_equal("┌───┬───┐\n│ a │ b │\n├───┼───┤\n│ 1 │ 2 │\n└───┴───┘\n",
                     out)
    end

    def test_a_ragged_row_exits_one_naming_the_line
        status, _, err = run_cli(stdin: "a,b\n1,2,3\n")
        assert_equal(1, status)
        assert_includes(err, "line 2")
    end

    def test_no_rows_at_all_exits_one
        status, = run_cli(stdin: "")
        assert_equal(1, status)
    end

    def test_max_width_refuses_an_over_wide_render_naming_it
        row = "x" * 90
        status, _, err = run_cli("--max-width", "78", stdin: "Header\n#{row}\n")
        assert_equal(1, status)
        assert_includes(err, "--max-width 78")
    end

    def test_a_render_within_max_width_still_draws
        row = "x" * 90
        status, out, = run_cli("--max-width", "94", stdin: "Header\n#{row}\n")
        assert_equal(0, status)
        refute_empty(out)
    end

    def test_an_unknown_style_is_a_usage_error
        status, = run_cli("--style", "bogus", stdin: "a,b\n1,2\n")
        assert_equal(2, status)
    end

    def test_align_of_the_wrong_length_is_a_usage_error
        status, _, err = run_cli("--align", "lrc", stdin: "a,b\n1,2\n")
        assert_equal(2, status)
        assert_includes(err, "--align")
    end

    def test_more_than_one_file_argument_is_a_usage_error
        Dir.mktmpdir do |dir|
            path = File.join(dir, "ab.csv")
            File.write(path, "a,b\n1,2\n")
            status, = run_cli(path, path)
            assert_equal(2, status)
        end
    end

    def test_a_missing_file_is_bad_input
        status, _, err = run_cli("/no/such/file.csv")
        assert_equal(1, status)
        refute_empty(err)
    end

    def test_help_exits_zero_and_prints_usage
        status, out, = run_cli("--help")
        assert_equal(0, status)
        assert_includes(out, "Usage:")
    end

    def test_tsv_and_no_header_and_style_ascii
        status, out, = run_cli("--tsv", "--no-header", "--style", "ascii",
                               stdin: "1\t2\n10\t20\n")
        assert_equal(0, status)
        assert_equal("+----+----+\n|  1 |  2 |\n| 10 | 20 |\n+----+----+\n",
                     out)
    end
end

# Multi-line cells, fitting a width, colour in cells (climat's Render
# needs): a cell's "\n" draws on several lines, the row top-aligned;
# width: narrows the widest column and wraps it, refusing below
# min_width; colour is zero width and survives padding and wrapping.
class TestTableCells < Minitest::Test
    ROWS = [%w[zone devices], ["living", "thermostat\nvalve"],
            ["bed", "one two three four five"]].freeze

    def lines(rows = ROWS, **)
        Tessella.table(rows, **).to_s.lines(chomp: true)
    end

    def test_a_multi_line_cell_draws_on_several_lines_top_aligned
        assert_equal(["│ living │ thermostat              │",
                      "│        │ valve                   │"], lines[3, 2])
    end

    def test_width_narrows_the_widest_column_and_wraps_it
        out = lines(width: 20)
        assert(out.all? { Tessella::Width.of(it) <= 20 }, out.join("\n"))
        assert_equal(20, Tessella::Width.of(out.first))
        assert_includes(out, "│ bed    │ one two │")
    end

    def test_a_word_longer_than_the_column_breaks_inside
        out = lines([%w[k v], %w[a abcdefghijkl]], width: 13)
        assert_equal(["│ a │ abcde │", "│   │ fghij │", "│   │ kl    │"],
                     out[3, 3])
    end

    def test_too_narrow_a_width_is_refused_naming_the_least
        error = assert_raises(ArgumentError) { lines(width: 10) }
        assert_includes(error.message, "needs 17 columns")
    end

    def test_colour_is_zero_width_and_reopened_across_a_wrap
        red = "\e[31mred text here\e[0m"
        out = lines([%w[k v], ["a", red]], width: 14)
        assert_equal(["│ a │ \e[31mred\e[0m    │", "│   │ \e[31mtext\e[0m   │",
                      "│   │ \e[31mhere\e[0m   │"], out[3, 3])
        assert(out.all? { Tessella::Width.of(it) == 14 })
    end

    def test_color_makes_the_header_bold
        assert_includes(lines(color: true)[1], "\e[1mzone\e[0m")
        refute_includes(lines[1], "\e[")
    end

    def test_align_takes_symbols
        out = lines([%w[a b], %w[1 2]], align: %i[right center])
        assert_equal(lines([%w[a b], %w[1 2]], align: "rc"), out)
        assert_raises(ArgumentError) { lines(align: %i[left sideways]) }
    end

    def test_markdown_refuses_multi_line_cells_and_width
        assert_raises(ArgumentError) { lines(style: :markdown) }
        assert_raises(ArgumentError) do
            lines([%w[a b]], style: :markdown, width: 10)
        end
    end
end

# A custom border set for a table: eleven glyphs, the frame's six and
# the tees (top_t bot_t sep_l sep_t sep_r).
class TestTableCustomBorders < Minitest::Test
    def test_eleven_glyphs_draw_the_table
        out = Tessella.table([%w[a b], %w[1 2]], style: "╒╕╘╛═│╤╧╞╪╡")
        assert_equal(<<~OUT, out.to_s)
            ╒═══╤═══╕
            │ a │ b │
            ╞═══╪═══╡
            │ 1 │ 2 │
            ╘═══╧═══╛
        OUT
    end

    def test_six_glyphs_are_not_enough_for_a_table
        error = assert_raises(ArgumentError) do
            Tessella.table([%w[a]], style: "╒╕╘╛═│")
        end
        assert_match(/needs 11 glyphs/, error.message)
    end

    def test_the_command_takes_glyphs_and_refuses_a_short_set
        out = StringIO.new
        err = StringIO.new
        run = lambda do |style|
            Tessella::CLI.run(["table", "--style", style],
                              stdin: StringIO.new("a,b\n"), stdout: out,
                              stderr: err)
        end
        assert_equal(0, run.call("╒╕╘╛═│╤╧╞╪╡"))
        assert_equal(2, run.call("╒╕╘╛═│"))
    end
end

# The named sets past light/heavy/double/rounded: dashed and fine
# dashed, light and heavy; double horizontals or double verticals,
# with their mixed tees.
class TestNamedBorderStyles < Minitest::Test
    def test_double_h_and_double_v_tables_use_the_mixed_tees
        { double_h: "╤╞╪╡╧", "double-v" => "╥╟╫╢╨" }.each do |style, tees|
            out = Tessella.table([%w[a b], %w[1 2]], style: style).to_s
            tees.each_char { assert_includes(out, it, style) }
        end
    end

    def test_each_dashed_style_frames_with_its_dash
        { dashed: "┄┆", dashed_fine: "┈┊", heavy_dashed: "┅┇",
          heavy_dashed_fine: "┉┋" }.each do |style, glyphs|
            out = Tessella.frame("ab", style: style).to_s
            glyphs.each_char { assert_includes(out, it, style) }
        end
    end

    def test_the_command_takes_hyphenated_names
        status = Tessella::CLI.run(%w[table --style heavy-dashed-fine],
                                   stdin: StringIO.new("a,b\n"),
                                   stdout: StringIO.new, stderr: StringIO.new)
        assert_equal(0, status)
    end
end
