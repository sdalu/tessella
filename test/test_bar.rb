# frozen_string_literal: true

require_relative "test_helper"

# Tessella.bar / .histogram and their Chart subclasses (DESIGN.md,
# "Chart and kinds"): construction, add, option checking, and the
# house defaults (fill, eighths, track, Axis.label value). Oracle
# parity lives in the *Oracle classes below.
class TestBar < Minitest::Test
    def test_bar_builds_a_bar_chart_with_one_set_of_bars
        chart = Tessella.bar(%w[a b], [1, 2])
        assert_kind_of(Tessella::Bar, chart)
        assert_includes(chart.to_s, "a")
        assert_includes(chart.to_s, "2")
    end

    def test_histogram_builds_a_histogram_chart
        chart = Tessella.histogram([1, 2, 2, 3, 3, 3])
        assert_kind_of(Tessella::Histogram, chart)
        assert_kind_of(Tessella::Bar, chart)
    end

    def test_add_appends_more_bars
        chart = Tessella.bar(["a"], [1])
        chart.add(["b"], [2])
        assert_includes(chart.to_s, "a")
        assert_includes(chart.to_s, "b")
    end

    def test_add_returns_self_for_chaining
        chart = Tessella::Bar.new
        assert_same(chart, chart.add(["a"], [1]))
    end

    def test_unknown_option_raises_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.bar(["a"], [1], bogus: true)
        end
        assert_match(/bogus/, error.message)
    end

    def test_fill_longer_than_one_character_raises_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.bar(["a"], [1], fill: "ab")
        end
        assert_match(/ab/, error.message)
    end

    def test_unknown_xscale_raises_naming_it
        error = assert_raises(ArgumentError) do
            Tessella.bar(["a"], [1], xscale: :bogus)
        end
        assert_match(/bogus/, error.message)
    end

    def test_value_label_keeps_an_integer_whole
        assert_includes(Tessella.bar(["a"], [5]).to_s, "5")
        refute_includes(Tessella.bar(["a"], [5]).to_s, "5.0")
    end

    def test_value_label_keeps_a_float_s_digits
        assert_includes(Tessella.bar(["a"], [3.5]).to_s, "3.5")
    end

    def test_default_fill_is_a_solid_block
        assert_includes(Tessella.bar(["a"], [5]).to_s, "█")
    end

    def test_ascii_true_uses_hash_as_the_fill
        out = Tessella.bar(["a"], [5], ascii: true).to_s
        assert_includes(out, "#")
        refute_includes(out, "█")
    end

    def test_track_default_fills_the_rest_of_the_bar_s_width
        out = Tessella.bar(%w[a b], [1, 10], width: 20).to_s
        assert_includes(out, "·")
    end

    def test_track_nil_disables_it
        out = Tessella.bar(%w[a b], [1, 10], width: 20, track: nil).to_s
        refute_includes(out, "·")
    end

    def test_eighths_default_draws_a_partial_cell
        out = Tessella.bar(%w[a b], [1, 3], width: 20).to_s
        assert_match(/[▉-▏]/, out)
    end

    def test_eighths_never_appear_under_ascii
        out = Tessella.bar(["a"], [1], width: 20, ascii: true).to_s
        refute_match(/[^\x00-\x7F]/, out)
    end

    def test_no_line_ends_in_a_blank
        out = Tessella.bar(%w[a b], [1, 2], title: "T", xlabel: "x").to_s
        lines = out.split("\n", -1)
        assert_equal("", lines.last)
        refute(lines[0..-2].any? { it.end_with?(" ") })
    end

    def test_color_false_never_emits_an_escape
        out = Tessella.bar(["a"], [1], color: false).to_s
        refute_includes(out, "\e")
    end

    def test_color_true_emits_an_escape
        out = Tessella.bar(["a"], [1], color: true).to_s
        assert_includes(out, "\e")
    end

    def test_ascii_true_is_pure_ascii
        out = Tessella.bar(%w[a b], [1, 2], ascii: true).to_s
        refute_match(/[^\x00-\x7F]/, out)
    end

    def test_histogram_closed_right_uses_a_different_bracket
        left = Tessella.histogram([1, 2, 3, 4], closed: :left).to_s
        right = Tessella.histogram([1, 2, 3, 4], closed: :right).to_s
        assert_includes(left, ")")
        assert_includes(right, "]")
    end
end

# Tessella::Bar against unicode_plot's barplot (DESIGN.md's oracle
# note): fill square, eighths off, no track -- the exact rendering
# unicode_plot's own barplot produces, line for line.
class TestBarOracle < Minitest::Test
    include Oracle::Test

    WIDTH = 20
    DATASETS = {
        integers: [%w[a b cc], [1, 5, 3]],
        floats: [%w[a b cc], [0.5, 12.25, 3.1]],
        zero: [%w[x y], [0, 5]],
        long_labels: [["Population of Paris", "NY"], [10, 20]]
    }.freeze

    def test_matches_unicode_plot_on_four_datasets
        need_oracle
        DATASETS.each_value do |labels, values|
            assert_parity(mine(labels, values), theirs(labels, values))
        end
    end

    def test_matches_unicode_plot_with_log10_xscale
        need_oracle
        labels = %w[a b cc]
        values = [1.0, 50.0, 1000.0]
        mine = mine(labels, values, xscale: :log10)
        theirs = theirs(labels, values, xscale: :log10)
        assert_parity(mine, theirs)
    end

    private

    def normalize(text) = text.split("\n", -1).map(&:rstrip).join("\n")

    def assert_parity(mine, theirs)
        assert_equal(normalize(theirs), normalize(mine))
    end

    def mine(labels, values, **)
        Tessella.bar(labels, values, width: WIDTH, fill: "■",
                                     eighths: false, track: nil, **).to_s
    end

    def theirs(labels, values, **)
        Oracle.render(UnicodePlot.barplot(labels, values, width: WIDTH,
                                                          **))
    end
end

# Tessella::Histogram against unicode_plot's histogram: Stats.histogram
# bins, the "[lo, hi)" labels unicode_plot prints (plain text -- its
# own labels carry ANSI escapes, stripped here before comparing).
class TestHistogramOracle < Minitest::Test
    include Oracle::Test

    WIDTH = 30
    DATASETS = {
        integers: [1, 2, 2, 3, 3, 3, 4, 5, 10],
        floats: [0.5, 1.2, 2.3, 2.4, 3.1, 3.9, 5.5],
        negative: [-5, -2, 0, 1, 3, 8],
        small_range: [1, 1, 2, 2, 3, 5, 6, 7]
    }.freeze

    def test_matches_unicode_plot_on_four_datasets
        need_oracle
        DATASETS.each_value do |values|
            assert_parity(mine(values),
                          theirs(values))
        end
    end

    def test_matches_unicode_plot_with_closed_right
        need_oracle
        values = DATASETS[:integers]
        assert_parity(mine(values, closed: :right),
                      theirs(values, closed: :right))
    end

    private

    def normalize(text)
        text.gsub(/\e\[[0-9]+m/, "").split("\n", -1).map(&:rstrip).join("\n")
    end

    def assert_parity(mine, theirs)
        assert_equal(normalize(theirs), normalize(mine))
    end

    def mine(values, **)
        Tessella.histogram(values, width: WIDTH, fill: "▇",
                                   eighths: false, track: nil, **).to_s
    end

    def theirs(values, **)
        Oracle.render(UnicodePlot.histogram(values, width: WIDTH, **))
    end
end

# Negative values: a zero column splits the bar area, negative bars
# grow left from it and positive ones right, each in proportion.
class TestBarNegative < Minitest::Test
    def rows(labels, values, **)
        Tessella.bar(labels, values, width: 30, **).to_s.lines
                .select { it.include?("┤") || it.include?("|") }
                .map { it.chomp.sub(/\A.*?[┤|]/, "") }
    end

    def span(row, glyphs = "█▐#")
        idx = row.chars.each_index.select { glyphs.include?(row[it]) }
        idx.empty? ? nil : [idx.first, idx.last]
    end

    def test_negative_bars_end_where_positive_bars_start
        neg, pos, = rows(%w[a b c], [-6, 3, 0])
        assert_equal(span(neg).last + 1, span(pos).first)
    end

    def test_bar_lengths_are_in_proportion_across_zero
        neg, pos, = rows(%w[a b], [-6, 3])
        n = span(neg).last - span(neg).first + 1
        p = span(pos).last - span(pos).first + 1
        assert_in_delta(2.0, n.fdiv(p), 0.25)
    end

    def test_a_zero_value_draws_no_bar_and_keeps_its_label
        _, _, zero = rows(%w[a b c], [-6, 3, 0])
        assert_nil(span(zero))
        assert(zero.rstrip.end_with?(" 0"))
    end

    def test_every_row_is_as_wide_as_the_frame
        lines = Tessella.bar(%w[a b], [-12.5, 3], width: 30).to_s.lines
        bars = lines.select { it.include?("┤") }
        frame = lines.first.rstrip.length
        bars.each { assert_operator(it.index(" ", it.index("┤")), :<, frame) }
    end

    def test_all_negative_bars_grow_left_from_the_right_edge
        a, b = rows(%w[a b], [-6, -3])
        assert_equal(span(a).last, span(b).last)
        assert_operator(span(a).first, :<, span(b).first)
    end

    def test_negative_bars_under_ascii_are_ascii
        out = Tessella.bar(%w[a b], [-6, 3], ascii: true).to_s
        assert(out.ascii_only?)
        assert_includes(out, "#")
    end

    def test_values_all_nonnegative_keep_the_layout
        plain = Tessella.bar(%w[a b], [6, 3], width: 30).to_s
        assert_includes(plain, "a ┤#{"█" * 25}")
    end
end
