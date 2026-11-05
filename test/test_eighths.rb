# frozen_string_literal: true

require_relative "test_helper"

# Eighth blocks for sub-cell values: an area on the eighths canvas
# (▁..█ up, ▏..█ sideways), and stacked bars under colour, where a
# boundary inside a cell is an eighths glyph on the next series'
# background.
class TestEighths < Minitest::Test
    def body(chart) = chart.to_s.lines[1..-3].map { it[/│(.*)│/, 1] }

    def test_an_area_fills_by_eighths
        out = Tessella.line([0, 1], [0, 1], area: true, canvas: :eighths,
                                            width: 4, height: 1,
                                            ylim: [0, 1], xlim: [0, 1])
        assert_equal(["▁▃▅▇"], body(out))
    end

    def test_sideways_it_fills_across
        out = Tessella.line([0, 1], [0, 1], area: true, canvas: :eighths,
                                            width: 1, height: 4,
                                            xlim: [0, 1], ylim: [0, 1],
                                            orientation: :horizontal)
        assert_equal(%w[█ ▋ ▍ ▏], body(out))
    end

    def test_only_an_area_takes_the_eighths_canvas
        [{ canvas: :eighths }, { canvas: :half_wide },
         { area: true, canvas: :eighths, threshold: 1 }].each do |opts|
            assert_raises(ArgumentError) { Tessella.line([1, 2], **opts).to_s }
        end
    end

    def test_a_stacked_boundary_splits_its_cell_under_colour
        out = Tessella.bar(%w[a], [[1.3, 1.7]], stacked: true, color: true,
                                                width: 13).to_s
        assert_includes(out, "█\e[0m\e[31;42m▌\e[0m\e[32m▓")
        plain = Tessella.bar(%w[a], [[1.3, 1.7]], stacked: true, width: 13)
        refute_includes(plain.to_s, "▌")
    end

    def test_a_stacked_column_splits_its_cell_under_colour
        opts = { stacked: true, color: true, height: 3, width: 1,
                 orientation: :vertical }
        out = Tessella.bar(%w[a], [[1.5, 1.5]], **opts).to_s
        assert_includes(out, "\e[31;42m▄\e[0m")
    end

    def test_a_background_colour
        color = Tessella::Color
        assert_equal("\e[31;42mx\e[0m", color.wrap("x", %i[red green]))
        assert_equal("\e[38;5;9;48;5;10mx\e[0m",
                     Tessella::Color.wrap("x", [9, 10]))
    end
end
