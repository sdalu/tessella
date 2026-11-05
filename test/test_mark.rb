# frozen_string_literal: true

require_relative "test_helper"

# add's mark: (DESIGN.md, "Chart and kinds"): a series drawn as one
# glyph in the cell of each point, in place of the kind's own drawing,
# and Canvas#mark beneath it.
class TestMark < Minitest::Test
    LIMITS = { xlim: [0, 10], ylim: [0, 10] }.freeze

    def canvas
        AsciiArt::Canvas.build(:braille, width: 10, height: 5, **LIMITS)
    end

    def chars(canvas) = canvas.rows.map { it.map(&:char).join }

    def body(chart)
        chart.to_s.lines[1..-3].map { it[/│(.*)│/, 1] || it[/\|(.*)\|/, 1] }
    end

    def test_canvas_mark_lands_in_the_cell_holding_the_point
        c = canvas
        c.mark(0, 10, "a")
        c.mark(10, 0, "b")
        c.mark(5, 5, "c")
        rows = chars(c)
        assert_equal("a", rows[0][0])
        assert_equal("b", rows[4][9])
        assert_equal("c", rows[2][5])
    end

    def test_canvas_mark_outside_the_limits_draws_nothing
        c = canvas
        c.mark(10.5, 5, "x")
        c.mark(5, -0.5, "x")
        assert(chars(c).none? { it.include?("x") })
    end

    def test_canvas_mark_overwrites_what_the_cell_draws
        c = canvas
        c.line(0, 5, 10, 5)
        c.mark(5, 5, "x")
        assert_equal("x", chars(c)[2][5])
    end

    def test_a_marked_series_draws_its_marks_and_no_line
        chart = AsciiArt.line([0, 10], [0, 10], mark: "x", width: 10,
                                                height: 5, **LIMITS)
        cells = body(chart).join
        assert_equal(2, cells.count("x"))
        assert_equal([" ", "x"], cells.chars.uniq.sort)
    end

    def test_a_marked_series_sits_over_a_line_series
        chart = AsciiArt.line([0, 10], [5, 5], width: 10, height: 5,
                                               **LIMITS)
        chart.add([5], [5], mark: "x")
        assert_equal("x", body(chart)[2][5])
        assert_match(/[⠀-⣿]/, body(chart)[2])
    end

    def test_stairs_marks_the_points_given_not_the_step_corners
        chart = AsciiArt.stairs([1, 2, 4], [1, 3, 4], mark: "x")
        assert_equal(3, body(chart).join.count("x"))
    end

    def test_the_legend_shows_the_mark_before_the_name
        chart = AsciiArt.line([1, 2], [1, 2], name: "fit")
        chart.add([1, 2], [1, 2], name: "measured", mark: "o")
        lines = chart.to_s.lines
        assert(lines[1].rstrip.end_with?("fit"))
        assert(lines[2].rstrip.end_with?("o measured"))
    end

    def test_a_mark_takes_its_series_colour
        chart = AsciiArt.line([0, 10], [0, 10], mark: "x", color: true,
                                                **LIMITS)
        assert_match(/\e\[[0-9;]*mx/, chart.to_s)
        plain = AsciiArt.line([0, 10], [0, 10], mark: "x", **LIMITS)
        refute_includes(plain.to_s, "\e")
    end

    def test_ascii_true_with_an_ascii_mark_is_ascii_only
        chart = AsciiArt.line([1, 2, 3], ascii: true)
        chart.add([1, 3], [1, 3], mark: "o")
        assert(chart.to_s.ascii_only?)
    end

    def test_a_mark_of_other_than_one_character_is_refused
        ["", "ab", :x, 1].each do |mark|
            error = assert_raises(ArgumentError) do
                AsciiArt.line([1, 2]).add([1, 2], mark: mark)
            end
            assert_includes(error.message, "one character")
        end
    end

    def test_a_unicode_mark_under_ascii_is_refused
        error = assert_raises(ArgumentError) do
            AsciiArt.line([1, 2], ascii: true, mark: "●")
        end
        assert_includes(error.message, "ASCII")
    end

    def test_bar_kinds_take_no_mark
        assert_raises(ArgumentError) do
            AsciiArt.bar(%w[a], [1]).add(%w[b], [2], mark: "x")
        end
    end
end
