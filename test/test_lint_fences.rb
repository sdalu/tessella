# frozen_string_literal: true

require_relative "test_lint"

# fences: true and geometry: true, the two checks added with the port:
# a Markdown file linted one fenced block at a time, with the file's
# line numbers, and box sides and connectors measured in display
# columns.
class TestLintFences < Minitest::Test
    include LintHelper

    DOC = "Prose\twith a tab.\n\n```text\n┌──┐\n│ab│ \n└──┘\n```\n" \
          "\n| a | b |\n|---|---|\n"

    def test_only_fenced_blocks_are_linted_with_the_files_lines
        assert_equal(["5: trailing whitespace"], findings(DOC, fences: true))
    end

    def test_a_tilde_fence_and_an_unclosed_fence
        assert_equal([2, 6], lines_of("~~~\na\t\n~~~\n\n```\nb\t\n",
                                      /tab/, fences: true))
    end

    def test_a_marker_before_the_fence_exempts_that_block
        block = "```\n┌──┐\n+--+\n```\n"
        text = "<!-- artlint: allow-mixed -->\n\n#{block}\n#{block}"
        assert_equal([10], lines_of(text, /ASCII structure/, fences: true))
    end

    def test_a_longer_fence_closes_only_on_as_long_a_run
        text = "````\n```\na\t\n````\nb\t\n"
        assert_equal([3], lines_of(text, /tab/, fences: true))
    end
end

# geometry: true -- check-readme.py's box and connector checks.
class TestLintGeometry < Minitest::Test
    include LintHelper

    def geometry(text)
        findings(text, geometry: true)
            .grep(/box|connector/)
    end

    def test_a_sound_box_and_its_stem_are_clean
        assert_empty(geometry("┌──┐\n│ab│\n└┬─┘\n │\n ▼\n"))
    end

    # The shifted side is also a vertical with nothing above it.
    def test_a_side_one_column_off
        assert_equal(["3: side of box opened at line 1 col 1 is off at " \
                      "col 4", "3: connector '│' at col 5 hangs from ' '"],
                     geometry("┌──┐\n│ab│\n│ab │\n└──┘\n"))
    end

    def test_a_bottom_edge_that_does_not_close
        assert_equal(["3: box opened at line 1 col 1 does not close at " \
                      "col 4 (found '─')"], geometry("┌──┐\n│ab│\n└───\n"))
    end

    def test_a_box_with_no_bottom_edge
        assert_equal(["1: box opened at col 1 has no bottom edge"],
                     geometry("┌──┐\n│ab│\n"))
    end

    def test_an_ascii_box_side_off
        assert_equal(["3: side of box opened at line 1 col 1 is off at " \
                      "col 4", "3: connector '|' at col 5 hangs from ' '"],
                     geometry("+--+\n|ab|\n|ab |\n+--+\n"))
    end

    def test_a_connector_hanging_from_blank_space
        assert_equal(["3: connector '│' at col 6 hangs from ' '"],
                     geometry("┌──┐\n└──┘\n     │\n"))
    end

    def test_a_lifeline_crossed_by_an_arrow_is_not_hanging
        assert_empty(geometry("│   │\n│──▸│\n│   │\n"))
    end

    def test_columns_are_display_columns
        assert_empty(geometry("┌────┐\n│漢字│\n└────┘\n"))
    end

    def test_geometry_is_off_by_default
        assert_empty(findings("┌──┐\n│ab│\n"))
    end
end

# geometry: true on every box-drawing set (glyphs read by their arms)
# and on custom border sets declared with borders:.
class TestLintGeometryVariants < Minitest::Test
    include LintHelper

    def geometry(text, **)
        findings(text, geometry: true, **)
            .grep(/box|connector/)
    end

    SHIFTED = { heavy: "┏━━┓\n┃ab┃\n┃ab ┃\n┗━━┛\n",
                double: "╔══╗\n║ab║\n║ab ║\n╚══╝\n",
                rounded: "╭──╮\n│ab│\n│ab │\n╰──╯\n",
                dashed: "┌┄┄┐\n┆ab┆\n┆ab ┆\n└┄┄┘\n" }.freeze

    def test_a_shifted_side_is_found_in_every_set
        SHIFTED.each do |set, text|
            assert_equal(1, geometry(text).grep(/side of box/).size, set)
        end
    end

    def test_sound_boxes_of_every_set_are_clean
        SHIFTED.each do |set, text|
            sound = text.lines.reject { it.include?("ab ") }.join
            assert_empty(geometry(sound), set)
        end
    end

    def test_mixed_junctions_are_sides_and_edges
        grid = "╔═╤═╗\n║a│b║\n╟─┼─╢\n║c│d║\n╚═╧═╝\n"
        assert_empty(geometry(grid))
    end

    def test_a_custom_set_is_read_by_its_roles
        box = "*====*\n! hi !\n! hi  !\n*====*\n"
        assert_empty(geometry(box))
        assert_equal(["3: side of box opened at line 1 col 1 is off at " \
                      "col 6", "3: connector '!' at col 7 hangs from ' '"],
                     geometry(box, borders: ["****=!"]))
    end

    def test_a_custom_connector_must_hang_from_a_junction
        assert_equal(["4: connector '!' at col 3 hangs from '='"],
                     geometry("*====*\n! hi !\n*====*\n  !\n",
                              borders: ["****=!"]))
    end

    def test_borders_takes_names_sets_and_glyph_strings
        set = Tessella::Borders::Set.new("╓", "╖", "╙", "╜", "─", "║")
        assert_predicate(Tessella.lint("", borders: [:heavy, set, "****=!"]),
                         :clean?)
        assert_raises(ArgumentError) { Tessella.lint("", borders: ["xx"]) }
    end

    # Whatever tessella draws passes its own geometry check.
    def test_every_frame_and_table_tessella_draws_is_clean
        styles = Tessella::Borders::STYLES.keys + ["╒╕╘╛═│╤╧╞╪╡"]
        styles.each do |style|
            [Tessella.frame("ab\ncd", style: style, title: "t"),
             Tessella.table([%w[a b], %w[1 2]], style: style)].each do |fig|
                assert_empty(geometry(fig.to_s, borders: [style]), style)
            end
        end
    end
end
