# frozen_string_literal: true

require_relative "test_helper"

# Composition regressions from the blind bug hunt: fill on a coloured
# block, the cjk target's free text and ASCII structure, grid's ascii:,
# a wide rule, a line break in a title.
class TestComposeFixes < Minitest::Test
    T = Tessella::Target

    def test_fill_measures_a_coloured_block_by_what_it_shows
        chart = Tessella.bar(%w[a b], [3, 5], color: true, width: 10)
        out = Tessella.frame(chart, fill: :light).to_s
        assert_includes(out, "\e[31m")
        widths = out.lines.map { Tessella::Width.of(it.chomp) }
        assert_equal(1, widths.uniq.size)
        box = Tessella.fill("+----+\n|\e[31mX\e[0m   |\n+----+").to_s
        assert_includes(box, "░")
    end

    def test_cjk_composes_its_own_tables
        table = [%w[名 x], %w[1 2]]
        out = T.with(:cjk) { Tessella.frame(Tessella.table(table)) }
        assert_includes(out.to_s, "名")
    end

    def test_grid_passes_its_ascii_down
        out = T.with(:cjk) { Tessella.grid("é", "b", ascii: false).to_s }
        assert_equal("é  b\n", out)
    end

    def test_structure_stays_ascii_under_cjk
        assert_raises(ArgumentError) do
            T.with(:cjk) { Tessella.stack("ab", "b", rule: "─", ascii: true) }
        end
    end

    def test_a_wide_rule_is_as_wide_as_the_blocks
        s = Tessella.stack("ab", "cd", rule: "＝")
        assert_equal([2, 2, 2], s.lines.map { Tessella::Width.of(it) })
    end

    def test_a_title_is_one_line
        assert_raises(ArgumentError) { Tessella.frame("abc", title: "a\nb") }
        assert_raises(ArgumentError) do
            Tessella.table([%w[a b], %w[1 2]], title: "a\nb")
        end
    end
end
