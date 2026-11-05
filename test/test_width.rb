# frozen_string_literal: true

require_relative "test_helper"

# Width.of counts grapheme clusters: an emoji sequence joined by ZWJ,
# or skin-toned, is the one wide glyph a terminal draws, 2 columns;
# combining marks add nothing; other clusters sum their characters.
class TestWidth < Minitest::Test
    def width(text) = Tessella::Width.of(text)

    def test_emoji_sequences_are_one_wide_glyph
        assert_equal(2, width("👨‍👩‍👧"))
        assert_equal(2, width("👍🏽"))
        assert_equal(2, width("❤️‍🔥"))
        assert_equal(2, width("🇫🇷"))
        assert_equal(5, width("a👨‍👩‍👧 b"))
    end

    def test_other_clusters_sum_their_characters
        assert_equal(1, width("é"))
        assert_equal(4, width("日本"))
        assert_equal(2, width("कि"))
        assert_equal(3, width("\e[31mabc\e[0m"))
    end

    def test_a_frame_and_a_table_fit_an_emoji_sequence
        frame = Tessella::Compose.frame("👨‍👩‍👧 x").to_s.lines
        assert_equal(["┌──────┐\n", "│ 👨‍👩‍👧 x │\n", "└──────┘\n"], frame)
        table = Tessella.table([["👨‍👩‍👧", 1], %w[ab 2]]).to_s.lines
        assert_equal("│ 👨‍👩‍👧 │ 1 │\n", table[1])
    end

    # Compose.fill's cell grid: a cluster is one cell plus a tail cell
    # when wide, so every row is the block's width.
    def test_the_fill_grid_counts_clusters
        block = Tessella::Compose.frame("👨‍👩‍👧 é")
        grid = Tessella::Compose.cell_grid(block)
        assert(grid.all? { it.size == block.width })
    end
end
