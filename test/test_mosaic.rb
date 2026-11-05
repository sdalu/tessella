# frozen_string_literal: true

require_relative "test_helper"

# Teletext sextants (2x3) and octants (2x4, Unicode 16) as chart
# canvases and bar blocks, with Image's glyph tables.
class TestMosaic < Minitest::Test
    def canvas(type, cols, rows)
        Tessella::Canvas.build(type, width: cols, height: rows,
                                     xlim: [0, 1], ylim: [0, 1])
    end

    def test_a_sextant_cell_packs_two_by_three
        c = canvas(:sextant, 1, 1)
        c.column_bar(0, 3)
        assert_equal("▌", c.rows.first.first.char)
        c.column_bar(1, 1)
        assert_equal("\u{1FB32}", c.rows.first.first.char)
    end

    def test_an_octant_cell_packs_two_by_four
        c = canvas(:octant, 1, 1)
        c.column_bar(0, 4)
        c.column_bar(1, 4)
        assert_equal("█", c.rows.first.first.char)
        dot = canvas(:octant, 1, 1)
        dot.row_bar(0, 1)
        assert_equal(Tessella::Image::OCTANT[1], dot.rows.first.first.char)
    end

    def test_a_line_chart_takes_either_canvas
        %i[sextant octant].each do |type|
            out = Tessella.line([0, 1, 0], canvas: type, width: 6,
                                           height: 2).to_s
            refute_includes(out, "⠀")
            assert(out.lines.all? { Tessella::Width.of(it.chomp) <= 14 })
        end
    end

    # A text row holds as many bars as the cell has pixel rows.
    def test_bars_pack_by_the_cell_height
        out = Tessella.bar(%w[a b c d], [3, 5, 2, 4], blocks: :sextant,
                                                      width: 10).to_s
        assert_match(/a\.\.c │/, out)
        out = Tessella.bar(%w[a b c d e], [1] * 5, blocks: :octant,
                                                   width: 10).to_s
        assert_match(/a\.\.d │/, out)
    end
end
