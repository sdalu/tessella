# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Tessella.wave (DESIGN.md): a timing diagram from WaveDrom-like
# signal text, ported from the ascii-art skill's scripts/wave.rb --
# every case in its own check-wave.sh, plus a case per refusal.
class TestWave < Minitest::Test
    def test_a_01_run_matches_the_hand_derived_rise_at_period_two
        assert_equal("        ┌───\nSIG ────┘\n",
                     Tessella.wave("SIG: 0011", period: 2).to_s)
    end

    def test_a_bus_run_centres_its_label_and_ticks_every_equals
        assert_equal("        ╳\nBUS ─A──╳B\n",
                     Tessella.wave("BUS: =.= | A B", period: 2).to_s)
    end

    def test_dot_after_p_repeats_the_cycle_not_the_level_unicode
        assert_equal("    ──┐ ┌─┐ ┌─┐ ┌─┐\nclk   └─┘ └─┘ └─┘ └─\n",
                     Tessella.wave("clk: p...", period: 4).to_s)
    end

    def test_dot_after_p_repeats_the_cycle_not_the_level_ascii
        wave = Tessella.wave("clk: p...", period: 4, ascii: true)
        assert_equal("    __   _   _   _\nclk   |_| |_| |_| |_\n",
                     wave.to_s)
    end

    def test_clocks_rising_edges_sit_at_the_other_signals_own_edges
        out = Tessella.wave("clk: p.......\ncs: 1.0....1.", period: 4).to_s
        lines = out.lines(chomp: true)
        rises = positions(lines[1], "┘")
        edges = (positions(lines[3], "┐┌└┘") +
                 positions(lines[4], "┐┌└┘")).uniq
        refute_empty(edges)
        assert_empty(edges - rises)
    end

    def test_unicode_draws_corners_the_bands_and_the_bus_mark
        out = Tessella.wave("A: pnxz=.|L").to_s
        %w[┌ ┐ ┘ └ ▒ ┄ ╳].each { |g| assert_includes(out, g) }
    end

    def test_ascii_draws_the_fill_tick_unknown_hiz_and_mark_letters
        out = Tessella.wave("A: pnxz=.|L", ascii: true).to_s
        %w[_ | x - X].each { |g| assert_includes(out, g) }
    end

    def test_ascii_output_has_no_byte_outside_0x20_0x7e
        out = Tessella.wave("A: pnxz=.|L", ascii: true).to_s
        assert(out.ascii_only?)
    end

    def test_a_lone_separator_reads_as_one_extra_blank_row
        out = Tessella.wave("A: 01\n---\nB: 10", period: 2).to_s
        assert_equal("    ┌─\nA ──┘\n\n\n  ──┐\nB   └─\n", out)
    end

    def test_ruler_appends_an_indexed_row_under_the_steps
        out = Tessella.wave("A: 0101", period: 2, ruler: true).to_s
        assert_equal("    ┌─┐ ┌─\nA ──┘ └─┘\n\n  0 1 2 3\n", out)
    end

    def test_back_to_back_equals_each_get_their_own_box_and_mark
        out = Tessella.wave("BUS: == | A A", period: 2).to_s
        assert_equal("      ╳\nBUS A─╳A\n", out)
    end

    def test_a_cjk_bus_label_is_centred_by_display_width
        out = Tessella.wave("BUS: =.=.= | 漢 字 漢", period: 6).to_s
        assert_equal("                ╳           ╳\n" \
                     "BUS ─────漢─────╳────字─────╳─漢──\n", out)
    end

    def test_period_from_2_to_8_all_draw
        (2..8).each do |n|
            wave = Tessella.wave("A: 01p.n.xz=.|L", period: n)
            assert_kind_of(Tessella::Block, wave)
        end
    end

    def test_returns_an_tessella_block
        assert_kind_of(Tessella::Block, Tessella.wave("A: 01"))
    end

    private

    def positions(line, chars)
        (0...line.length).select { |i| chars.include?(line[i]) }
    end
end

# Tessella.wave's refusals (DESIGN.md): every bad-input case raises
# ArgumentError naming what and where, as wave.rb's own BadInput does.
class TestWaveRefusals < Minitest::Test
    def test_an_unknown_wave_character_names_the_line
        error = assert_raises(ArgumentError) { Tessella.wave("A: 03") }
        assert_equal("line 1: unknown wave character 3", error.message)
    end

    def test_a_missing_colon_is_refused
        assert_raises(ArgumentError) { Tessella.wave("A 01") }
    end

    def test_an_empty_signal_name_is_refused
        assert_raises(ArgumentError) { Tessella.wave(": 01") }
    end

    def test_an_empty_wave_is_refused
        assert_raises(ArgumentError) { Tessella.wave("A: ") }
    end

    def test_a_dot_with_no_previous_state_is_refused
        error = assert_raises(ArgumentError) { Tessella.wave("A: .0") }
        assert_equal("line 1: '.' with no previous state", error.message)
    end

    def test_fewer_labels_than_equals_values_is_refused
        error = assert_raises(ArgumentError) { Tessella.wave("A: =.=") }
        assert_equal("line 1: not enough labels for '='", error.message)
    end

    def test_more_labels_than_equals_values_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.wave("A: = | A B")
        end
        assert_equal("line 1: too many labels for '='", error.message)
    end

    def test_a_label_wider_than_its_bus_segment_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.wave("A: = | LONGLABEL", period: 2)
        end
        assert_match(/does not fit in \d+ columns/, error.message)
    end

    def test_no_signal_lines_at_all_is_refused
        error = assert_raises(ArgumentError) { Tessella.wave("---") }
        assert_equal("no signal lines", error.message)
    end

    def test_period_below_2_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.wave("A: 01", period: 1)
        end
        assert_match(/period must be an Integer >= 2/, error.message)
    end

    def test_period_not_an_integer_is_refused
        assert_raises(ArgumentError) { Tessella.wave("A: 01", period: 2.5) }
    end
end

# `tessella wave` (DESIGN.md, "Command line"): options, exit status,
# and the prefixed error messages, ported from check-wave.sh's own
# CLI-facing cases (its --no-lint ones only, since the lint pass stays
# in the skill).
class TestWaveCLI < Minitest::Test
    def run_cli(*argv, stdin: "")
        run_command(argv, stdin, runner: Tessella::WaveCLI)
    end

    def test_draws_from_stdin
        status, out, = run_cli("--period", "2", stdin: "SIG: 0011\n")
        assert_equal(0, status)
        assert_equal("        ┌───\nSIG ────┘\n", out)
    end

    def test_draws_from_a_file
        Dir.mktmpdir do |dir|
            path = File.join(dir, "sig")
            File.write(path, "SIG: 0011\n")
            status, out, = run_cli("--period", "2", path)
            assert_equal([0, "        ┌───\nSIG ────┘\n"], [status, out])
        end
    end

    def test_ascii_flag_through_the_cli
        status, out, = run_cli("--period", "4", "--ascii",
                               stdin: "clk: p...\n")
        assert_equal(0, status)
        assert_equal("    __   _   _   _\nclk   |_| |_| |_| |_\n", out)
    end

    def test_ruler_flag_through_the_cli
        status, out, = run_cli("--period", "2", "--ruler",
                               stdin: "A: 0101\n")
        assert_equal(0, status)
        assert_includes(out, "0 1 2 3")
    end

    def test_bad_input_exits_one_with_the_prefixed_message
        status, _, err = run_cli(stdin: "A: 03\n")
        assert_equal(1, status)
        assert_equal("tessella wave: line 1: unknown wave character 3\n",
                     err)
    end

    def test_max_width_passes_under_the_limit
        long = "WIDE: #{"0" * 30}\n"
        status, _, err = run_cli("--period", "4", "--max-width", "200",
                                 stdin: long)
        assert_equal(0, status, err)
    end

    def test_max_width_refuses_over_the_limit_naming_the_width
        long = "WIDE: #{"0" * 30}\n"
        status, _, err = run_cli("--period", "4", "--max-width", "10",
                                 stdin: long)
        assert_equal(1, status)
        assert_includes(err, "exceeds --max-width 10")
    end

    def test_an_unknown_option_is_a_usage_error
        status, _, err = run_cli("--bogus", stdin: "")
        assert_equal(2, status)
        assert_includes(err, "tessella wave: ")
    end

    def test_too_many_arguments_is_a_usage_error
        status, = run_cli("a", "b", stdin: "")
        assert_equal(2, status)
    end

    def test_a_missing_file_is_bad_input
        status, _, err = run_cli("/no/such/wave/file")
        assert_equal(1, status)
        assert_includes(err, "tessella wave: ")
    end

    def test_help_prints_usage_and_exits_zero
        status, out, = run_cli("--help")
        assert_equal(0, status)
        assert_includes(out, "Usage: tessella wave")
    end

    def test_the_command_is_registered_on_the_main_cli
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["wave", "--period", "2"],
                                   stdin: StringIO.new("SIG: 0011\n"),
                                   stdout: out, stderr: err)
        assert_equal(0, status)
        assert_equal("        ┌───\nSIG ────┘\n", out.string)
    end
end
