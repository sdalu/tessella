# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

# Inkchart::Chart: option handling and defaults, add's series
# bookkeeping, colour cycling over Color::NAMES, canvas/frame assembly,
# to_s / render (DESIGN.md, "Chart and kinds"). Chart itself has no
# draw_series, so a minimal concrete subclass stands in for "any kind".
class TestChart < Minitest::Test
    class Dots < Inkchart::Chart
        private

        def draw_series(canvas, series)
            canvas.points(series.x, series.y, color: series.color)
        end
    end

    def test_default_canvas_is_braille
        assert_match(/[⠀-⣿]/, Dots.new.add([1, 2, 3]).to_s)
    end

    def test_default_width_and_height
        lines = Dots.new.add([1, 2, 3]).to_s.split("\n", -1)
        assert_includes(lines[0], "┌#{"─" * 40}┐")
        assert_equal(1 + 15 + 1 + 1, lines.size - 1)
    end

    def test_ascii_true_selects_ascii_canvas_and_frame
        out = Dots.new(ascii: true).add([1, 2, 3]).to_s
        refute_match(/[^\x00-\x7F]/, out)
        assert_includes(out, "+#{"-" * 40}+")
    end

    def test_width_and_height_options_are_honoured
        out = Dots.new(width: 10, height: 4).add([1, 2, 3]).to_s
        lines = out.split("\n", -1)
        assert_includes(lines[0], "┌#{"─" * 10}┐")
        assert_includes(lines[-3], "└#{"─" * 10}┘")
        assert_equal(1 + 4 + 1 + 1, lines.size - 1)
    end

    def test_canvas_option_overrides_the_default
        out = Dots.new(canvas: :dot).add([1, 2, 3]).to_s
        refute_match(/[⠀-⣿]/, out)
    end

    def test_color_false_never_emits_an_escape_even_with_a_colour
        out = Dots.new(color: false).add([1, 2, 3], color: :red).to_s
        refute_includes(out, "\e")
    end

    def test_color_cycles_over_color_names_unless_given
        chart = Dots.new(color: true, width: 30, height: 1,
                         xlim: [0.0, 30.0], ylim: [0.0, 1.0])
        chart.add([2.0], [0.5], color: :blue)
        chart.add([15.0], [0.5])
        chart.add([28.0], [0.5])
        out = chart.to_s
        assert_includes(out, "\e[34m")
        assert_includes(out, "\e[31m")
        assert_includes(out, "\e[32m")
    end

    def test_add_without_x_defaults_to_one_based_index
        chart = Dots.new(width: 10, height: 3).add([5, 6, 7])
        bottom = chart.to_s.split("\n", -1)[-2]
        assert_includes(bottom, "1")
        assert_includes(bottom, "3")
    end

    def test_add_returns_self_for_chaining
        chart = Dots.new
        assert_same(chart, chart.add([1, 2]).add([3, 4]))
    end

    def test_named_series_appear_as_a_legend_in_add_order
        out = Dots.new.add([1, 2], name: "first")
                  .add([3, 4], name: "second").to_s
        assert_match(/first.*\n.*second/m, out)
    end

    def test_unnamed_series_are_not_given_a_legend_entry
        unnamed = Dots.new.add([1, 2]).to_s
        named = Dots.new.add([1, 2], name: "s").to_s
        refute_includes(unnamed, "s")
        assert_includes(named, "s")
    end

    def test_y_axis_extremes_use_axis_tick_formatting
        out = Dots.new(ylim: [0.0, 10.0]).add([1, 2], [1, 2]).to_s
        lines = out.split("\n", -1)
        assert_includes(lines[1], "10 ")
        assert_includes(lines[-4], "0 ")
    end

    def test_xlim_and_ylim_options_are_honoured
        out = Dots.new(xlim: [0.0, 100.0]).add([1, 2], [1, 2]).to_s
        bottom = out.split("\n", -1)[-2]
        assert_includes(bottom, "0")
        assert_includes(bottom, "100")
    end

    def test_unknown_option_raises_naming_it
        error = assert_raises(ArgumentError) { Dots.new(bogus: 1) }
        assert_match(/bogus/, error.message)
    end

    def test_unknown_canvas_raises_argument_error_naming_it
        error = assert_raises(ArgumentError) do
            Dots.new(canvas: :nonexistent).add([1, 2]).to_s
        end
        assert_match(/nonexistent/, error.message)
    end

    def test_no_line_ends_in_a_blank
        out = Dots.new(title: "T", xlabel: "x", ylabel: "y")
                  .add([1, 2], name: "s").to_s
        lines = out.split("\n", -1)
        assert_equal("", lines.last)
        refute(lines[0..-2].any? { it.end_with?(" ") })
    end

    def test_render_writes_the_same_text_as_to_s
        chart = Dots.new.add([1, 2, 3])
        io = StringIO.new
        chart.render(io)
        assert_equal(chart.to_s, io.string)
    end
end

# What add and the common options refuse before anything is drawn.
class TestChartRefusals < Minitest::Test
    def test_width_and_height_must_be_positive_integers
        [{ width: 0 }, { width: -3 }, { height: 0 }, { width: 2.5 }]
            .each do |opts|
                error = assert_raises(ArgumentError) do
                    Inkchart.line([1, 2], **opts).to_s
                end
                assert_includes(error.message, opts.keys.first.to_s)
            end
    end

    def test_x_and_y_must_have_the_same_length
        error = assert_raises(ArgumentError) do
            Inkchart.line([1, 2, 3], [1, 2])
        end
        assert_includes(error.message, "3")
        assert_includes(error.message, "2")
    end

    def test_xscale_of_a_nonpositive_x_is_refused
        %i[ln log2 log10].each do |xscale|
            error = assert_raises(ArgumentError) do
                Inkchart.line([0, 1, 2], [1, 2, 3], xscale: xscale)
            end
            assert_includes(error.message, "finite")
        end
    end

    def test_a_non_finite_value_is_refused_by_every_kind
        bad = [1, Float::INFINITY]
        [-> { Inkchart.line(bad) }, -> { Inkchart.scatter(bad, [1, 2]) },
         -> { Inkchart.density([1, Float::NAN]) },
         -> { Inkchart.bar(%w[a b], bad) }, -> { Inkchart.histogram(bad) },
         -> { Inkchart.box(["a"], [bad]) }].each do |build|
            assert_raises(ArgumentError) { build.call.to_s }
        end
    end

    def test_a_nil_or_string_value_is_refused_naming_it
        [[1, nil], [1, "x"]].each do |values|
            error = assert_raises(ArgumentError) do
                Inkchart.bar(%w[a b], values)
            end
            assert_includes(error.message, values.last.inspect)
        end
    end

    def test_bar_and_box_names_must_match_their_values
        assert_raises(ArgumentError) { Inkchart.bar(%w[a b], [1]) }
        assert_raises(ArgumentError) { Inkchart.box(%w[a b], [[1]]) }
    end
end
