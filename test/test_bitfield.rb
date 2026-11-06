# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Tessella.bitfield and Tessella::Bitfield.parse: an RFC-style
# packet/bit-field diagram, ported byte for byte from the tessella
# skill's scripts/bitfield.rb (test/check-bitfield.sh's own cases).
class TestBitfield < Minitest::Test
    RECIPE = "Source Port:16\nDestination Port:16\nSequence Number:32\n"

    RECIPE_WANT = <<~TEXT
         0                   1                   2                   3
         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        |          Source Port          |       Destination Port        |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        |                        Sequence Number                        |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    TEXT

    def test_the_recipes_own_32_bit_figure_byte_for_byte
        assert_equal(RECIPE_WANT, Tessella.bitfield(RECIPE).to_s)
    end

    def test_a_hand_derived_8_bit_figure_byte_for_byte
        want = <<~TEXT
             0
             0 1 2 3 4 5 6 7
            +-+-+-+-+-+-+-+-+
            | High  |  Low  |
            +-+-+-+-+-+-+-+-+
        TEXT
        assert_equal(want, Tessella.bitfield("High:4\nLow:4\n", word: 8).to_s)
    end

    def test_octets_ticks_every_8_bits_not_every_bit
        lines = Tessella.bitfield("Source Port:16\nDestination Port:16\n",
                                  octets: true).lines
        assert_equal("+---------------+---------------+---------------+" \
                     "---------------+", lines.first)
    end

    def test_octets_drops_the_two_row_bit_ruler
        lines = Tessella.bitfield("Source Port:16\nDestination Port:16\n",
                                  octets: true).lines
        refute(lines.any? { it.start_with?(" ") })
    end

    def test_no_ruler_keeps_per_bit_ticks_and_drops_the_header
        lines = Tessella.bitfield("Source Port:16\nDestination Port:16\n",
                                  ruler: false).lines
        assert_equal(RECIPE_WANT.lines[2].chomp, lines.first)
        refute(lines.any? { it.start_with?(" ") })
    end

    def test_a_field_wider_than_its_row_wraps_repeating_its_name
        block = Tessella.bitfield("Data:12\n", word: 8)
        assert_equal(2, block.lines.count { it.include?("Data") })
        assert_equal(3, block.lines.count { it.start_with?("+") })
    end

    def test_output_is_ascii_only
        assert(Tessella.bitfield(RECIPE).ascii?)
    end
end

# Refusals, and the Array / Bitfield.parse entry points.
class TestBitfieldRefusals < Minitest::Test
    RECIPE = TestBitfield::RECIPE

    def test_a_name_too_wide_for_its_cell_is_refused_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.bitfield("Supercalifragilistic:4\n", word: 8)
        end
        assert_includes(error.message, "Supercalifragilistic")
    end

    def test_abbrev_truncates_with_a_trailing_dot_instead
        block = Tessella.bitfield("Supercalifragilistic:4\n", word: 8,
                                                              abbrev: true)
        assert_includes(block.to_s, "|Superc.|")
    end

    def test_check_width_names_the_line_and_the_budget
        block = Tessella.bitfield(RECIPE)
        assert_raises(ArgumentError) { block.check_width!(40) }
    end

    def test_an_unparseable_line_is_refused_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.bitfield("this is not a field line\n")
        end
        assert_includes(error.message, "not a field line")
    end

    def test_a_zero_bit_field_is_refused
        error = assert_raises(ArgumentError) { Tessella.bitfield("A:0\n") }
        assert_includes(error.message, "has 0 bits")
    end

    def test_no_fields_is_refused
        assert_raises(ArgumentError) { Tessella.bitfield("\n\n") }
        assert_raises(ArgumentError) { Tessella.bitfield("# only a comment\n") }
    end

    def test_comments_and_blank_lines_are_skipped
        text = "# header\n\nSource Port:16\n# mid\nDestination Port:16\n\n"
        assert_equal(Tessella.bitfield(RECIPE.lines.first(2).join).to_s,
                     Tessella.bitfield(text).to_s)
    end

    def test_an_unsupported_word_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.bitfield(RECIPE, word: 24)
        end
        assert_includes(error.message, "word")
    end

    def test_an_array_of_name_bits_pairs_matches_the_text_form
        pairs = [["Source Port", 16], ["Destination Port", 16],
                 ["Sequence Number", 32]]
        assert_equal(Tessella.bitfield(RECIPE).to_s,
                     Tessella.bitfield(pairs).to_s)
    end

    def test_an_array_pair_with_bad_bits_is_refused
        assert_raises(ArgumentError) { Tessella.bitfield([["A", 0]]) }
        assert_raises(ArgumentError) { Tessella.bitfield([%w[A x]]) }
    end

    def test_bitfield_parse_exposes_the_fields
        fields = Tessella::Bitfield.parse("A:4\nB:4\n")
        assert_equal(%w[A B], fields.map(&:name))
        assert_equal([4, 4], fields.map(&:bits))
    end

    def test_a_1_bit_field_draws_a_single_column_cell
        block = Tessella.bitfield("F:1\n", word: 8)
        assert_includes(block.to_s, "|F|")
    end
end

# `tessella bitfield` (test/check-bitfield.sh's own cases, minus the
# dropped --no-lint, plus the usage refusals).
class TestBitfieldCLI < Minitest::Test
    RECIPE = TestBitfield::RECIPE

    def run_cli(*argv, stdin: "") = run_command(["bitfield", *argv], stdin)

    def test_draws_the_recipe_from_stdin
        status, out, = run_cli(stdin: RECIPE)
        assert_equal(0, status)
        assert_equal(TestBitfield::RECIPE_WANT, out)
    end

    def test_reads_a_file_argument
        Dir.mktmpdir do |dir|
            path = File.join(dir, "fields.txt")
            File.write(path, RECIPE)
            status, out, = run_cli(path)
            assert_equal(0, status)
            assert_equal(TestBitfield::RECIPE_WANT, out)
        end
    end

    def test_a_missing_file_exits_one
        status, out, err = run_cli("/no/such/file")
        assert_equal(1, status)
        assert_equal("", out)
        assert_includes(err, "tessella bitfield: ")
    end

    def test_bad_input_exits_one_naming_it
        status, _, err = run_cli(stdin: "not a field line\n")
        assert_equal(1, status)
        assert_includes(err, "not a field line")
    end

    def test_a_name_too_wide_exits_one_naming_it
        status, _, err = run_cli("--word", "8",
                                 stdin: "Supercalifragilistic:4\n")
        assert_equal(1, status)
        assert_includes(err, "Supercalifragilistic")
    end

    def test_abbrev_truncates_instead_of_refusing
        status, out, = run_cli("--word", "8", "--abbrev",
                               stdin: "Supercalifragilistic:4\n")
        assert_equal(0, status)
        assert_includes(out, "|Superc.|")
    end

    def test_max_width_refuses_output_over_budget
        status, out, err = run_cli("--max-width", "40", stdin: RECIPE)
        assert_equal(1, status)
        assert_equal("", out)
        assert_includes(err, "max-width 40")
    end

    def test_an_unsupported_word_is_a_usage_error
        status, out, = run_cli("--word", "24", stdin: RECIPE)
        assert_equal(2, status)
        assert_equal("", out)
    end

    def test_too_many_arguments_is_a_usage_error
        status, = run_cli("a", "b", stdin: RECIPE)
        assert_equal(2, status)
    end

    def test_no_lint_is_no_longer_accepted
        status, _, err = run_cli("--no-lint", stdin: RECIPE)
        assert_equal(2, status)
        assert_includes(err, "--no-lint")
    end

    def test_ascii_is_accepted_and_changes_nothing
        status, out, = run_cli("--ascii", stdin: RECIPE)
        assert_equal(0, status)
        assert_equal(TestBitfield::RECIPE_WANT, out)
    end

    def test_octets_drops_the_ruler_and_ticks_per_octet
        status, out, = run_cli("--octets",
                               stdin: "Source Port:16\n" \
                                      "Destination Port:16\n")
        assert_equal(0, status)
        refute(out.lines.first.start_with?(" "))
        assert(out.lines.first.start_with?("+---------------+"))
    end

    def test_help_prints_usage_and_exits_zero
        status, out, = run_cli("--help")
        assert_equal(0, status)
        assert_includes(out, "Usage: tessella bitfield")
    end

    # The tick line under a full row closes all of it, even when the
    # row after it is shorter.
    def test_a_short_last_row_leaves_no_row_open
        lines = Tessella.bitfield("A:32\nB:16\n").to_s.lines.map(&:chomp)
        assert_equal("#{"+-" * 32}+", lines[-3])
        assert_equal("#{"+-" * 16}+", lines[-1])
    end
end
