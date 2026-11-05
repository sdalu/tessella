# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# The hand-derived exact renders from the ascii-art skill's
# check-seq.sh, shared by the render tests below and by TestSeqCLI.
module SeqFixtures
    EXCHANGE = <<~DIAGRAM
        ┌───┐  ┌───┐
        │ A │  │ B │
        └─┬─┘  └─┬─┘
          │      │
          │  hi  │
          │─────►│
          │      │
          │  ok  │
          │◄┄┄┄┄┄│
          │      │
    DIAGRAM

    SELF_LOOP = <<~DIAGRAM
        ┌───┐
        │ A │
        └─┬─┘
          │
          │──┐
          │  │ loop
          │◄─┘
          │
    DIAGRAM

    SKIP = <<~DIAGRAM
        ┌───┐  ┌───┐  ┌───┐
        │ A │  │ B │  │ C │
        └─┬─┘  └─┬─┘  └─┬─┘
          │      │      │
          │  hi  │      │
          │─────►│      │
          │      │      │
          │     go      │
          │────────────►│
          │      │      │
          │      ┌──────┐
          │      │ wait │
          │      └──────┘
          │      │      │
    DIAGRAM

    SKIP_ASCII = <<~DIAGRAM
        +---+  +---+  +---+
        | A |  | B |  | C |
        +-+-+  +-+-+  +-+-+
          |      |      |
          |  hi  |      |
          |----->|      |
          |      |      |
          |     go      |
          |------------>|
          |      |      |
          |      +------+
          |      | wait |
          |      +------+
          |      |      |
    DIAGRAM
end

# Tessella.seq (ported from the ascii-art skill's scripts/seq.rb):
# the hand-derived exact renders, every glyph set, and lifelines that
# stay unbroken across a skipped participant.
class TestSeqRender < Minitest::Test
    include SeqFixtures

    def test_call_and_dashed_reply_exact_render
        assert_equal(EXCHANGE, Tessella.seq("A -> B: hi\nB --> A: ok\n").to_s)
    end

    def test_self_call_exact_render
        assert_equal(SELF_LOOP, Tessella.seq("A -> A: loop\n").to_s)
    end

    def test_skipped_middle_participant_and_two_way_note
        text = "A -> B: hi\nA -> C: go\nnote over B,C: wait\n"
        assert_equal(SKIP, Tessella.seq(text).to_s)
    end

    def test_same_but_ascii
        text = "A -> B: hi\nA -> C: go\nnote over B,C: wait\n"
        assert_equal(SKIP_ASCII, Tessella.seq(text, ascii: true).to_s)
    end

    def test_every_lifeline_column_is_never_blank
        text = "A -> B: hi\nA -> C: go\nnote over B,C: wait\n"
        lines = Tessella.seq(text, ascii: true).lines
        cols = lines[3].each_char.with_index.filter_map { |c, i| i if c == "|" }
        lines[3..].each do |line|
            cols.each { |c| refute_equal(" ", line[c], line) }
        end
    end

    def test_a_cjk_participant_name_aligns_box_and_lifeline
        block = Tessella.seq("Client -> 服务器: GET\n")
        top = block.lines[2].each_char.with_index
        bot = block.lines[3].each_char.with_index
        tees = top.filter_map { |c, i| i if c == "┬" }
        lives = bot.filter_map { |c, i| i if c == "│" }
        assert_equal(lives, tees)
        refute_empty(tees)
    end

    def test_async_draws_a_double_head
        out = Tessella.seq("A ->> B: ping\n").to_s
        assert_includes(out, "──►►│")
    end

    def test_ascii_call_reply_and_async_all_render_ascii_only
        text = "A -> B: hi\nB --> A: ok\nA ->> B: ping\n"
        assert(Tessella.seq(text, ascii: true).to_s.ascii_only?)
    end

    def test_a_note_over_two_participants_is_boxed
        out = Tessella.seq("A -> B: hi\nnote over A,B: both\n").to_s
        assert_includes(out, "both")
        assert_includes(out, "┌")
    end

    def test_a_note_over_one_participant_is_centred_over_it
        block = Tessella.seq("A -> B: hi\nnote over A: solo\n")
        assert_includes(block.lines.join("\n"), "solo")
    end

    def test_a_diagram_over_78_columns_still_renders
        long = "x" * 80
        out = Tessella.seq("Alice -> Bob: #{long}\n").to_s
        assert_operator(out.lines.map { it.chomp.length }.max, :>, 78)
    end

    def test_no_trailing_blank_on_any_line
        out = Tessella.seq("A -> B: hi\n", footer: true).to_s
        refute_match(/[ \t]\n/, out)
    end
end

# Tessella.seq, continued: --numbered, --footer, participant columns
# fixed by declaration or by first appearance, and input shape (
# comments, blank lines, stray space, the name alphabet).
class TestSeqOptions < Minitest::Test
    include SeqFixtures

    def test_numbered_prefixes_every_message_label
        out = Tessella.seq("A -> B: hi\nB --> A: ok\n", numbered: true).to_s
        assert_includes(out, "1. hi")
        assert_includes(out, "2. ok")
    end

    def test_numbered_does_not_number_a_note
        text = "A -> B: hi\nnote over A,B: both\n"
        out = Tessella.seq(text, numbered: true).to_s
        assert_includes(out, "1. hi")
        assert_includes(out, "both")
        refute_includes(out, "2. both")
    end

    def test_footer_repeats_the_participant_boxes
        out = Tessella.seq("A -> B: hi\n", footer: true).to_s
        assert_equal(2, out.scan(/│ A │/).size)
    end

    def test_a_bare_participant_declaration_draws_nothing
        with = Tessella.seq("participant A\nparticipant B\nA -> B: x\n").to_s
        without = Tessella.seq("A -> B: x\n").to_s
        assert_equal(without, with)
    end

    def test_an_undeclared_participant_is_fine_declared_by_appearance
        out = Tessella.seq("A -> B: hi\nC -> D: go\n").to_s
        assert_includes(out, "│ C │")
        assert_includes(out, "│ D │")
    end

    def test_comments_and_blank_lines_are_ignored
        text = "# a comment\n\nA -> B: hi\n\n# another\nB --> A: ok\n"
        assert_equal(EXCHANGE, Tessella.seq(text).to_s)
    end

    def test_leading_and_trailing_space_on_a_line_is_stripped
        assert_equal(EXCHANGE, Tessella.seq("  A -> B: hi  \nB --> A: ok\n")
                                        .to_s)
    end

    def test_a_label_may_hold_a_colon
        out = Tessella.seq("A -> B: time is 12:30\n").to_s
        assert_includes(out, "time is 12:30")
    end

    def test_participant_names_may_hold_dot_dash_underscore
        out = Tessella.seq("A.1 -> B_2: x\nA.1 -> C-3: y\n").to_s
        assert_includes(out, "A.1")
        assert_includes(out, "B_2")
        assert_includes(out, "C-3")
    end
end

# Tessella.seq's refusals: every one is an ArgumentError, naming the
# offending line (or line 0, for input with no statements at all).
class TestSeqRefusals < Minitest::Test
    def test_an_unrecognised_statement_names_the_line
        error = assert_raises(ArgumentError) do
            Tessella.seq("this is not a statement\n")
        end
        assert_equal("line 1: this is not a statement", error.message)
    end

    def test_a_missing_colon_is_refused
        assert_raises(ArgumentError) { Tessella.seq("A -> B hi\n") }
    end

    def test_an_unrecognised_arrow_is_refused
        assert_raises(ArgumentError) { Tessella.seq("A ==> B: hi\n") }
    end

    def test_a_malformed_participant_line_is_refused
        assert_raises(ArgumentError) { Tessella.seq("participant\n") }
    end

    def test_a_malformed_note_is_refused
        assert_raises(ArgumentError) { Tessella.seq("note over : text\n") }
    end

    def test_empty_input_is_refused_naming_line_zero
        error = assert_raises(ArgumentError) { Tessella.seq("") }
        assert_equal("line 0: no statements in the input", error.message)
    end

    def test_only_comments_and_blanks_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.seq("# just a comment\n\n")
        end
        assert_includes(error.message, "no statements in the input")
    end

    def test_a_cjk_name_under_ascii_is_refused_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.seq("Client -> 服务器: GET\n", ascii: true)
        end
        assert_includes(error.message, "is not ASCII")
    end
end

# `tessella seq` (SeqCLI): options, exit statuses and the messages
# every refusal is turned into.
class TestSeqCLI < Minitest::Test
    include SeqFixtures

    def run_cli(argv, input = "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["seq", *argv], stdin: StringIO.new(input),
                                                   stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def test_draws_from_stdin
        status, out, = run_cli([], "A -> B: hi\nB --> A: ok\n")
        assert_equal(0, status)
        assert_equal(EXCHANGE, out)
    end

    def test_ascii_flag
        status, out, = run_cli(["--ascii"], "A -> A: loop\n")
        assert_equal(0, status)
        assert(out.ascii_only?)
    end

    def test_numbered_flag
        status, out, = run_cli(["--numbered"], "A -> B: hi\n")
        assert_equal(0, status)
        assert_includes(out, "1. hi")
    end

    def test_footer_flag
        status, out, = run_cli(["--footer"], "A -> B: hi\n")
        assert_equal(0, status)
        assert_equal(2, out.scan(/│ A │/).size)
    end

    def test_max_width_passes_when_wide_enough
        status, = run_cli(["--max-width", "40"], "A -> B: hi\n")
        assert_equal(0, status)
    end

    def test_max_width_refuses_too_narrow_naming_the_width
        long = "x" * 80
        status, _out, err = run_cli(["--max-width", "40"],
                                    "Alice -> Bob: #{long}\n")
        assert_equal(1, status)
        assert_includes(err, "over --max-width 40")
    end

    def test_bad_input_exits_one_naming_the_line
        status, _out, err = run_cli([], "this is not a statement\n")
        assert_equal(1, status)
        assert_includes(err, "line 1")
        assert_includes(err, "tessella seq:")
    end

    def test_an_unknown_option_is_a_usage_error
        status, _out, err = run_cli(["--not-a-flag"], "A -> B: hi\n")
        assert_equal(2, status)
        assert_includes(err, "tessella seq:")
    end

    def test_too_many_file_arguments_is_a_usage_error
        status, = run_cli(%w[a b])
        assert_equal(2, status)
    end

    def test_a_missing_file_is_bad_input
        status, _out, err = run_cli(["/no/such/file"])
        assert_equal(1, status)
        assert_includes(err, "tessella seq:")
    end

    def test_help_exits_0_and_prints_usage
        status, out, = run_cli(["--help"])
        assert_equal(0, status)
        assert_includes(out, "Usage: tessella seq")
    end

    def test_no_lint_flag_is_an_unknown_option
        status, = run_cli(["--no-lint"], "A -> B: hi\n")
        assert_equal(2, status)
    end
end
