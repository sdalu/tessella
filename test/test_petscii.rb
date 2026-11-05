# frozen_string_literal: true

require_relative "test_helper"

# Tessella.image(style: :petscii): each cell drawn with the glyph whose
# shape fits its 4x8 tones best -- halves, quadrants, diagonals, line
# pieces, shades.
class TestPetscii < Minitest::Test
    # A 16x16 picture, one cell: bright where the block says so.
    def cell(&ink)
        vals = (0...16).flat_map do |y|
            (0...16).map { |x| ink.call(x / 16.0, y / 16.0) ? 255 : 0 }
        end
        pgm = "P5\n16 16\n255\n#{vals.pack("C*")}"
        Tessella.image(pgm, style: :petscii, width: 1).to_s.chomp
    end

    def test_shapes_find_their_glyph
        assert_equal("▐", cell { |x, _| x >= 0.5 })
        assert_equal("▄", cell { |_, y| y >= 0.5 })
        assert_equal("▗", cell { |x, y| x >= 0.5 && y >= 0.5 })
        assert_equal("◢", cell { |x, y| x + y >= 1 })
        assert_equal("█", cell { true })
    end

    # An edge a quarter of the way in is a three-quarter block, not a
    # line piece whose stem happens to cover it.
    def test_quarter_edges_find_three_quarter_blocks
        assert_equal("\u{1FB8A}", cell { |x, _| x >= 0.25 })
        assert_equal("▊", cell { |x, _| x < 0.75 })
        assert_equal("▆", cell { |_, y| y >= 0.25 })
    end

    def test_a_flat_tone_finds_a_shade
        pgm = "P5\n16 16\n255\n#{([128] * 256).pack("C*")}"
        assert_equal("▒", Tessella.image(pgm, style: :petscii, width: 1)
                                  .to_s.chomp)
    end

    def test_every_glyph_is_one_column_and_listed
        glyphs = Tessella::Image::PETSCII.keys
        assert(glyphs.all? { Tessella::Width.of(it) == 1 })
        assert_includes(Tessella::Image::STYLES, :petscii)
        assert_raises(ArgumentError) do
            Tessella.image("P5\n1 1\n255\n\xFF".b, style: :petscii,
                                                   ascii: true)
        end
    end
end
