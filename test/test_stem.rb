# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Tessella.stem / Tessella::Stem (DESIGN.md, "Chart and kinds"):
# construction, document safety, and the shared option/error rules.
# Oracle parity lives in TestStemOracle below.
class TestStem < Minitest::Test
    def test_stem_builds_a_stem_chart
        assert_kind_of(Tessella::Stem, Tessella.stem([1, 2, 3]))
    end

    def test_to_s_ends_with_a_single_trailing_newline
        out = Tessella.stem([1, 2, 3]).to_s
        assert(out.end_with?("\n"))
        refute(out.end_with?("\n\n"))
    end

    def test_no_line_ends_in_a_blank
        out = Tessella.stem([1, 2, 3], [40, 5, 60]).to_s
        lines = out.split("\n", -1)
        assert_equal("", lines.last)
        refute(lines[0..-2].any? { it.end_with?(" ") })
    end

    def test_color_false_never_emits_an_escape
        out = Tessella.stem([1, 2, 3], [4, 5, 6], color: false).to_s
        refute_includes(out, "\e")
    end

    def test_color_true_emits_an_escape
        out = Tessella.stem([1, 2, 3], color: true).to_s
        assert_includes(out, "\e")
    end

    def test_color_true_colours_both_samples_of_a_back_to_back_plot
        out = Tessella.stem([1, 2, 3], [4, 5, 6], color: true).to_s
        assert_includes(out, "\e[31m")
        assert_includes(out, "\e[32m")
    end

    def test_ascii_true_is_pure_ascii
        out = Tessella.stem([-12, 1, 35], ascii: true).to_s
        refute_match(/[^\x00-\x7F]/, out)
    end

    def test_plain_output_is_already_pure_ascii
        out = Tessella.stem([-12, 1, 35]).to_s
        refute_match(/[^\x00-\x7F]/, out)
    end

    def test_key_line_names_the_scale
        assert_match(/Key: 1\|0 = 10\b/, Tessella.stem([1, 2]).to_s)
        out = Tessella.stem([1, 2], scale: 100).to_s
        assert_match(/Key: 1\|0 = 100\b/, out)
    end

    def test_unknown_option_raises_argument_error_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.stem([1, 2], bogus: true)
        end
        assert_match(/bogus/, error.message)
    end

    def test_non_numeric_value_raises_argument_error_naming_it
        error = assert_raises(ArgumentError) { Tessella.stem([1, "x", 3]) }
        assert_match(/x/, error.message)
    end

    def test_non_numeric_value_in_the_second_sample_also_raises
        error = assert_raises(ArgumentError) do
            Tessella.stem([1, 2], [3, "y"])
        end
        assert_match(/y/, error.message)
    end

    def test_non_numeric_scale_raises_argument_error_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.stem([1, 2], scale: "ten")
        end
        assert_match(/ten/, error.message)
    end

    def test_render_writes_the_same_text_as_to_s
        chart = Tessella.stem([1, 2, 3])
        io = StringIO.new
        chart.render(io)
        assert_equal(chart.to_s, io.string)
    end

    def test_repeated_values_appear_as_repeated_leaves
        out = Tessella.stem([42, 42, 42]).to_s
        assert_match(/4 \| 222/, out)
    end

    def test_a_single_negative_value_near_zero_gets_its_own_stem
        out = Tessella.stem([-7]).to_s
        assert_match(/-0 \| 7/, out)
    end
end

# Tessella.stem against unicode_plot's stemplot (DESIGN.md's oracle
# note): exact, line-for-line equality (colour off, trailing blanks
# stripped on both sides) for the single-sample and the back-to-back
# form, across datasets of integers, floats, negatives, mixed signs, a
# given scale, and a repeated value. unicode_plot's stemplot writes
# straight to $stdout rather than returning a renderable Plot, so this
# class captures $stdout itself instead of using Oracle.render.
class TestStemOracle < Minitest::Test
    include Oracle::Test

    INTEGERS = [40, 53, 33, 8, 30, 78, 68, 63, 80, 75].freeze
    FLOATS = [1.5, -2.25, 3.75, 0.0, -0.5, 10.125].freeze
    NEGATIVES = [-30, -7, -1, -45, -99, -12].freeze
    MIXED = [-23, 5, 47, -3, 0, 12, -100].freeze
    REPEATED = [42, 42, 42, 42, 5].freeze
    OTHER = [23, 24, 70, 61, 26, 57, 28, 18, 69, 53].freeze

    SAMPLES = {
        integers: INTEGERS, floats: FLOATS, negatives: NEGATIVES,
        mixed: MIXED, repeated: REPEATED
    }.freeze

    def test_single_sample_matches_unicode_plot_on_six_datasets
        need_oracle
        SAMPLES.each_value { |vals| assert_parity(mine(vals), theirs(vals)) }
        assert_parity(mine(INTEGERS, scale: 100), theirs(INTEGERS, scale: 100))
    end

    def test_back_to_back_matches_unicode_plot_on_six_datasets
        need_oracle
        SAMPLES.each_value do |vals|
            assert_parity(mine(vals, other: OTHER), theirs(vals, other: OTHER))
        end
        assert_parity(mine(INTEGERS, other: OTHER, scale: 100),
                      theirs(INTEGERS, other: OTHER, scale: 100))
    end

    private

    def normalize(text)
        text.split("\n", -1).map(&:rstrip).join("\n")
    end

    def assert_parity(mine, theirs) = assert_equal(theirs, mine)

    def mine(values, other: nil, **)
        chart = if other
                    Tessella.stem(values, other, **)
                else
                    Tessella.stem(values, **)
                end
        normalize(chart.to_s)
    end

    def theirs(values, other: nil, **)
        args = other ? [values, other] : [values]
        normalize(capture_stdout { UnicodePlot.stemplot(*args, **) })
    end

    def capture_stdout
        original = $stdout
        $stdout = StringIO.new
        yield
        $stdout.string
    ensure
        $stdout = original
    end
end

# Leaves and stems computed without float truncation error, and the
# scale and stem count kept to what can be drawn.
class TestStemNumbers < Minitest::Test
    def lines(*, **) = Tessella.stem(*, **).to_s.lines.map(&:rstrip)

    def test_decimal_leaves_are_not_truncated_by_float_error
        assert_equal(["0 | 37", "1 | 1", "2 | 3"],
                     lines([0.3, 0.7, 1.1, 2.3], scale: 1).first(3))
    end

    def test_a_negative_decimal_keeps_its_leaf
        assert_equal("-0 | 3", lines([-0.3], scale: 1).first)
    end

    def test_scale_must_be_positive
        [0, -10].each do |scale|
            error = assert_raises(ArgumentError) do
                Tessella.stem([1, 2], scale: scale)
            end
            assert_includes(error.message, "scale")
        end
    end

    def test_too_many_stems_is_refused
        error = assert_raises(ArgumentError) { Tessella.stem([1, 100_000]) }
        assert_includes(error.message, "scale")
    end

    def test_an_empty_sample_still_draws_its_key
        assert_equal("Key: 1|0 = 10", lines([]).first)
    end

    def test_a_non_finite_value_is_refused
        assert_raises(ArgumentError) { Tessella.stem([1, Float::NAN]) }
    end
end
