# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# area: true (DESIGN.md, "Chart and kinds"): the region under a line
# filled from the canvas floor, btop-style -- two independent bars per
# braille or block cell -- with a gradient by height under color: true
# and plain glyphs without it.
class TestCanvasArea < Minitest::Test
    def canvas(type, ylim)
        Tessella::Canvas.build(type, width: 1, height: 1, xlim: [0, 2],
                                     ylim: ylim)
    end

    def glyph(canvas) = canvas.rows.first.first.char

    # Left column 4 dots high, right column 2: dots 1 2 3 7 and 6 8.
    def test_a_braille_cell_holds_two_bars
        c = canvas(:braille, [0, 4])
        c.area([0.5, 1.5], [4, 2])
        assert_equal("⣧", glyph(c))
    end

    # Left column full, right column half: three quadrants.
    def test_a_block_cell_holds_two_bars
        c = canvas(:block, [0, 2])
        c.area([0.5, 1.5], [2, 1])
        assert_equal("▙", glyph(c))
    end

    def test_a_peak_narrower_than_a_column_is_kept
        c = canvas(:braille, [0, 4])
        c.area([0.1, 0.2, 0.3], [0, 4, 0])
        assert_equal("⡇", glyph(c))
    end

    def test_a_cell_takes_its_rows_colour
        c = Tessella::Canvas.build(:braille, width: 1, height: 2,
                                             xlim: [0, 2], ylim: [0, 8])
        c.area([0.5, 1.5], [8, 8], color: ->(row) { row.zero? ? :red : :green })
        assert_equal(%i[red green], c.rows.map { it.first.color })
    end
end

# Tessella.line(area: true, gradient:) and `tessella chart --area`.
class TestLineArea < Minitest::Test
    Y = [1, 3, 5, 3, 1, 6].freeze

    def area(**) = Tessella.line(Y, area: true, width: 6, height: 3, **)

    def test_the_area_is_measured_from_zero
        assert_equal("0", area.to_s.lines[3].strip.split.first)
    end

    def test_without_colour_no_escape_is_drawn
        refute_includes(area.to_s, "\e[")
        refute_includes(area(gradient: %i[red]).to_s, "\e[")
    end

    def test_under_colour_the_bands_run_bottom_up
        rows = area(color: true).to_s.lines[1, 3]
        assert_includes(rows[0], "\e[31m")
        assert_includes(rows[1], "\e[33m")
        assert_includes(rows[2], "\e[32m")
    end

    def test_gradient_false_keeps_the_series_colour
        rows = area(color: true, gradient: false).to_s.lines[1, 3]
        assert(rows.all? { !it.include?("\e[3") || it.include?("\e[31m") })
    end

    def test_ascii_draws_ascii
        assert_predicate(area(ascii: true).to_s, :ascii_only?)
    end

    def test_gradient_is_refused_without_area_or_with_a_bad_name
        assert_raises(ArgumentError) { Tessella.line(Y, gradient: %i[red]) }
        assert_raises(ArgumentError) { area(gradient: %i[pink]) }
        assert_raises(ArgumentError) { area(gradient: []) }
    end

    def cli(argv) = run_command(["chart", *argv], "1\n2\n3\n").first

    def test_the_command_takes_area_for_line_and_stairs_only
        assert_equal(0, cli(%w[--area --gradient blue,red]))
        assert_equal(0, cli(%w[--kind stairs --area --gradient none]))
        assert_equal(2, cli(%w[--kind scatter --area]))
        assert_equal(2, cli(%w[--gradient red]))
    end
end

# Colours past the eight names (a 256-colour index, a truecolor
# #rrggbb) and the gradient that maps them onto rows.
class TestColorGradient < Minitest::Test
    G = Tessella::Color::Gradient

    def test_a_colour_is_a_name_an_index_or_a_hex
        assert_equal("\e[31mx\e[0m", Tessella::Color.wrap("x", :red))
        assert_equal("\e[38;5;208mx\e[0m", Tessella::Color.wrap("x", 208))
        assert_equal("\e[38;2;255;128;0mx\e[0m",
                     Tessella::Color.wrap("x", "#ff8000"))
        [:pink, 256, "#ff80"].each do |bad|
            assert_raises(ArgumentError) { Tessella::Color.code(bad) }
        end
    end

    def test_named_or_indexed_stops_make_equal_bands_bottom_up
        three = %i[green yellow red]
        assert_equal(three, (0..2).map { G.at(three, it, 3) })
        assert_equal([46, 46, 196, 196], (0..3).map { G.at([46, 196], it, 4) })
    end

    def test_hex_stops_blend_from_the_bottom_row_to_the_top
        assert_equal(%w[#000000 #555555 #aaaaaa #ffffff],
                     (0..3).map { G.at(%w[#000000 #ffffff], it, 4) })
    end

    def cli(argv)
        run_command(["chart", "--area", "--color", *argv], "1\n2\n3\n")
            .first(2)
    end

    def test_the_command_takes_indexes_and_hex_stops
        status, out = cli(%w[--gradient #000000,#ffffff])
        assert_equal(0, status)
        assert_includes(out, "\e[38;2;255;255;255m")
        assert_includes(cli(%w[--gradient 46,196]).last, "\e[38;5;196m")
        assert_equal(2, cli(%w[--gradient #zz0000]).first)
    end
end
