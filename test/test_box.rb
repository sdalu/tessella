# frozen_string_literal: true

require_relative "test_helper"

# AsciiArt.box and its Chart subclass (DESIGN.md, "Chart and kinds"):
# construction, add, option checking, document safety. Oracle parity
# lives in TestBoxOracle below.
class TestBox < Minitest::Test
    def test_box_builds_a_box_chart
        chart = AsciiArt.box(["s1"], [[1, 2, 3]])
        assert_kind_of(AsciiArt::Box, chart)
        assert_includes(chart.to_s, "s1")
    end

    def test_add_appends_more_boxes
        chart = AsciiArt.box(["s1"], [[1, 2, 3]])
        chart.add(["s2"], [[4, 5, 6]])
        assert_includes(chart.to_s, "s1")
        assert_includes(chart.to_s, "s2")
    end

    def test_add_returns_self_for_chaining
        chart = AsciiArt::Box.new
        assert_same(chart, chart.add(["s1"], [[1, 2, 3]]))
    end

    def test_each_box_draws_three_rows
        one = AsciiArt.box(["s1"], [[1, 2, 3]]).to_s.split("\n", -1)
        two = AsciiArt.box(%w[s1 s2], [[1, 2, 3], [4, 5, 6]])
                      .to_s.split("\n", -1)
        assert_equal(3, two.length - one.length)
    end

    def test_unknown_option_raises_naming_it
        error = assert_raises(ArgumentError) do
            AsciiArt.box(["s1"], [[1, 2, 3]], bogus: true)
        end
        assert_match(/bogus/, error.message)
    end

    def test_no_line_ends_in_a_blank
        out = AsciiArt.box(%w[s1 s2], [[1, 2, 3], [4, 5, 6]],
                           title: "T", xlabel: "x", ylabel: "y").to_s
        lines = out.split("\n", -1)
        assert_equal("", lines.last)
        refute(lines[0..-2].any? { it.end_with?(" ") })
    end

    def test_color_false_never_emits_an_escape
        out = AsciiArt.box(["s1"], [[1, 2, 3]], color: false).to_s
        refute_includes(out, "\e")
    end

    def test_color_true_emits_an_escape
        out = AsciiArt.box(["s1"], [[1, 2, 3]], color: true).to_s
        assert_includes(out, "\e")
    end

    def test_ascii_true_is_pure_ascii
        out = AsciiArt.box(["s1"], [[1, 2, 3]], ascii: true).to_s
        refute_match(/[^\x00-\x7F]/, out)
    end

    def test_unnamed_box_shows_no_left_label
        out = AsciiArt.box([""], [[1, 2, 3]]).to_s
        refute_match(/[a-zA-Z]/, out)
    end
end

# ASCII box plots are the Unicode ones with each glyph mapped one for
# one: a whisker meeting the box (├ ┤), a whisker end cap (╷ ╵), and a
# vertical box side (│) all become "|"; a corner or median end
# (┌ ┐ └ ┘ ┬ ┴) becomes "+"; a horizontal line (─) becomes "-" --
# never two different glyphs colliding into the same byte.
class TestBoxAscii < Minitest::Test
    GLYPH_MAP = {
        "┌" => "+", "┐" => "+", "└" => "+", "┘" => "+",
        "┬" => "+", "┴" => "+",
        "├" => "|", "┤" => "|",
        "─" => "-", "│" => "|",
        "╷" => "|", "╵" => "|"
    }.freeze

    def test_one_box_ascii_is_the_unicode_mapped_one_for_one
        assert_mapped_match(["a"], [[1, 2, 3, 9]])
    end

    def test_two_boxes_ascii_is_the_unicode_mapped_one_for_one
        assert_mapped_match(%w[a b], [[1, 2, 3, 9], [4, 5, 7, 8, 12]])
    end

    def test_ascii_box_plot_is_pure_ascii
        out = mine(%w[a b], [[1, 2, 3, 9], [4, 5, 7, 8, 12]], ascii: true)
        refute_match(/[^\x00-\x7F]/, out)
    end

    private

    def mine(names, samples, **)
        AsciiArt.box(names, samples, width: 30, **).to_s
    end

    def assert_mapped_match(names, samples)
        uni = mine(names, samples)
        asc = mine(names, samples, ascii: true)
        mapped = uni.each_char.map { |ch| GLYPH_MAP.fetch(ch, ch) }.join
        assert_equal(mapped, asc)
    end
end

# AsciiArt::Box against unicode_plot's boxplot (DESIGN.md's oracle
# note): the percentile shapes, the corner border with blank sides --
# Frame has no such border type, so Box builds it into the body cells
# itself (see lib/ascii_art/kinds/box.rb) -- and the min/mean/max line
# below it.
class TestBoxOracle < Minitest::Test
    include Oracle::Test

    DATASETS = {
        one_box: [["s1"], [[1, 2, 3, 4, 5, 10, 20]], { width: 30 }],
        several_boxes: [%w[alpha beta],
                        [[1, 2, 3, 4, 5], [0, 10, 20, 30, 40]],
                        { width: 30 }],
        floats: [["s1"], [[1.5, 2.5, 3.5, 4.5]], { width: 20 }],
        negative: [%w[x y],
                   [[-10, -5, 0, 5, 10], [-20, 0, 20]], { width: 25 }]
    }.freeze

    def test_matches_unicode_plot_on_four_datasets
        need_oracle
        DATASETS.each_value do |names, samples, opts|
            assert_parity(mine(names, samples, opts),
                          theirs(names, samples, opts))
        end
    end

    private

    def normalize(text) = text.split("\n", -1).map(&:rstrip).join("\n")

    def assert_parity(mine, theirs)
        assert_equal(normalize(theirs), normalize(mine))
    end

    def mine(names, samples, opts)
        AsciiArt.box(names, samples, **opts).to_s
    end

    def theirs(names, samples, opts)
        Oracle.render(UnicodePlot.boxplot(names, samples, **opts))
    end
end
