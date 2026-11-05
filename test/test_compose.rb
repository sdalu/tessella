# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Block, Borders and the five compositions (DESIGN.md, "Blocks and
# composition"): exact output on small blocks, display-width padding,
# and every refusal.
class TestBlock < Minitest::Test
    def test_trailing_blank_lines_are_dropped
        assert_equal(%w[AB CD],
                     Tessella::Block.new(["AB", "CD", "", " "]).lines)
    end

    def test_an_empty_block_is_refused
        assert_raises(ArgumentError) { Tessella::Block.new(["", ""]) }
    end

    def test_a_tab_is_refused_naming_the_line
        error = assert_raises(ArgumentError) do
            Tessella::Block.new(%W[ok a\tb])
        end
        assert_includes(error.message, "line 2")
    end

    def test_width_is_display_columns_and_ignores_colour
        block = Tessella::Block.new(["中文", "\e[31mab\e[0m"])
        assert_equal(4, block.width)
        assert_equal(2, Tessella::Width.of("\e[31mab\e[0m"))
    end

    def test_from_takes_a_chart
        block = Tessella::Block.from(Tessella.bar(%w[a], [1]))
        assert_operator(block.height, :>, 1)
    end

    def test_check_width_names_the_line_and_the_budget
        error = assert_raises(ArgumentError) do
            Tessella::Block.new(%w[ab abcd]).check_width!(3)
        end
        assert_equal("output is 4 columns on line 2 (max-width 3)",
                     error.message)
    end
end

class TestCompose < Minitest::Test
    AB = "AB\nCD\n"

    def test_frame_light
        assert_equal("┌────┐\n│ AB │\n│ CD │\n└────┘\n",
                     Tessella.frame(AB).to_s)
    end

    def test_frame_title_is_centred_in_the_top_edge
        assert_equal("┌─ T ─┐", Tessella.frame("X", title: "T").lines.first)
    end

    def test_every_style_draws_its_own_corners
        { light: "┌┐└┘", heavy: "┏┓┗┛", double: "╔╗╚╝", rounded: "╭╮╰╯",
          ascii: "++++" }.each do |style, corners|
            lines = Tessella.frame(AB, style: style).lines
            got = lines.first[0] + lines.first[-1] + lines.last[0] +
                  lines.last[-1]
            assert_equal(corners, got, style)
        end
    end

    def test_beside_pads_each_block_to_its_own_width
        assert_equal("AB X\nCD\n", Tessella.beside(AB, "X").to_s)
    end

    def test_beside_pads_cjk_and_braille_by_display_width
        assert_equal("中文 ⠉⠒\nAB   Y\n",
                     Tessella.beside("中文\nAB", "⠉⠒\nY").to_s)
    end

    def test_beside_align_bottom_fills_from_the_top
        assert_equal("AB
CD X
", Tessella.beside(AB, "X", align: :bottom).to_s)
    end

    def test_stack_with_a_rule
        assert_equal("AB\nCD\n==\nX\n", Tessella.stack(AB, "X", rule: "=").to_s)
    end

    def test_stack_center_shifts_a_narrower_block_as_a_whole
        assert_equal("ABC\n X\n", Tessella.stack("ABC", "X", center: true).to_s)
    end

    def test_indent_strips_the_prefix_blank_on_an_empty_line
        assert_equal("# AB\n#\n# CD\n",
                     Tessella.indent("AB\n\nCD", prefix: "# ").to_s)
    end

    def test_caption_above
        assert_equal("Fig\n\nAB\nCD\n",
                     Tessella.caption(AB, text: "Fig", above: true).to_s)
    end

    def test_ascii_draws_ascii_glyphs
        assert(Tessella.frame(AB, ascii: true).to_s.ascii_only?)
    end

    def test_ascii_refuses_another_style_and_non_ascii_content
        assert_raises(ArgumentError) do
            Tessella.frame(AB, style: :double, ascii: true)
        end
        assert_raises(ArgumentError) { Tessella.frame("é", ascii: true) }
        assert_raises(ArgumentError) do
            Tessella.frame(AB, title: "é", ascii: true)
        end
    end

    def test_refusals_name_what_they_refuse
        assert_raises(ArgumentError) { Tessella.beside(AB) }
        assert_raises(ArgumentError) { Tessella.stack(AB) }
        assert_raises(ArgumentError) { Tessella.frame(AB, style: :triangle) }
        assert_raises(ArgumentError) do
            Tessella.beside(AB, "X", align: :sideways)
        end
        assert_raises(ArgumentError) { Tessella.stack(AB, "X", rule: "==") }
        assert_raises(ArgumentError) { Tessella.frame(AB, pad: -1) }
    end

    def test_a_coloured_chart_frames_by_its_visible_width
        chart = Tessella.bar(%w[a b], [1, 2], color: true)
        framed = Tessella.frame(chart)
        plain = Tessella.frame(Tessella.bar(%w[a b], [1, 2]))
        assert_equal(plain.lines.first, framed.lines.first)
    end
end

class TestComposeCLI < Minitest::Test
    def run_cli(*argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["compose", *argv],
                                   stdin: StringIO.new(stdin),
                                   stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def with_files(files)
        Dir.mktmpdir do |dir|
            paths = files.to_h do |name, text|
                path = File.join(dir, name)
                File.write(path, text)
                [name, path]
            end
            yield paths
        end
    end

    def test_frame_from_stdin
        status, out, = run_cli("frame", "-", stdin: "AB\nCD\n")
        assert_equal(0, status)
        assert_equal("┌────┐\n│ AB │\n│ CD │\n└────┘\n", out)
    end

    def test_beside_two_files
        with_files("a" => "AB\nCD\n", "b" => "X\n") do |p|
            status, out, = run_cli("beside", p["a"], p["b"])
            assert_equal([0, "AB X\nCD\n"], [status, out])
        end
    end

    BAD = { "tab" => "A\tB\n", "empty" => "\n\n", "e" => "é\n" }.freeze

    def test_bad_input_exits_one_naming_the_block
        with_files(BAD) do |p|
            [[["frame", p["tab"]], "tab:1: tab character"],
             [["frame", p["empty"]], "empty: empty block"],
             [["frame", "--ascii", p["e"]], "e:1: non-ASCII byte"],
             [["frame", "#{p["tab"]}.missing"], "missing"]].each do |argv, msg|
                status, _, err = run_cli(*argv)
                assert_equal(1, status, err)
                assert_includes(err, msg)
            end
        end
    end

    def test_max_width_refuses_wider_output
        status, _, err = run_cli("frame", "--max-width", "3", "-",
                                 stdin: "AB\n")
        assert_equal(1, status)
        assert_includes(err, "max-width 3")
    end

    def test_usage_errors_exit_two
        [[], %w[sideways -], %w[beside -], %w[frame --style triangle -],
         %w[frame --ascii --style double -], %w[beside --align up - -],
         %w[beside - -], %w[indent -], %w[stack --rule == - -]]
            .each do |argv|
                status, _, err = run_cli(*argv, stdin: "AB\n")
                assert_equal(2, status, "#{argv.inspect}: #{err}")
            end
    end
end

# A custom border set: a Set, or six glyphs in Set order.
class TestFrameCustomBorders < Minitest::Test
    def test_a_glyph_string_or_a_set_draws_the_frame
        assert_equal("*==*\n!ab!\n*==*\n",
                     Tessella.frame("ab", style: "****=!", pad: 0).to_s)
        set = Tessella::Borders::Set.new("╓", "╖", "╙", "╜", "─", "║")
        assert_equal("╓──╖\n║ab║\n╙──╜\n",
                     Tessella.frame("ab", style: set, pad: 0).to_s)
    end

    def test_a_bad_set_is_refused_naming_it
        ["**=!", "****=\t", "****=漢"].each do |spec|
            assert_raises(ArgumentError, spec) do
                Tessella.frame("ab", style: spec)
            end
        end
    end

    def test_under_ascii_a_custom_set_must_be_ascii
        assert_equal("*==*\n!ab!\n*==*\n",
                     Tessella.frame("ab", style: "****=!", pad: 0,
                                          ascii: true).to_s)
        assert_raises(ArgumentError) do
            Tessella.frame("ab", style: "╒╕╘╛═│", ascii: true)
        end
    end
end

# stack's gap: N blank rows between blocks, or N on each side of a rule.
class TestStackGap < Minitest::Test
    def test_gap_without_a_rule_is_n_rows_between
        assert_equal(%w[a b], Tessella.stack("a", "b").lines)
        assert_equal(["a", "", "b"], Tessella.stack("a", "b", gap: 1).lines)
        assert_equal(["a", "", "", "b"],
                     Tessella.stack("a", "b", gap: 2).lines)
    end

    def test_gap_with_a_rule_is_n_rows_on_each_side
        assert_equal(["a", "", "=", "", "b"],
                     Tessella.stack("a", "b", gap: 1, rule: "=").lines)
    end
end

# shadow: ░ one column right of every row but the first, and a bottom
# bar from one column in to the shadow column -- the geometry the lint
# checks, so a shadowed frame lints clean.
class TestShadow < Minitest::Test
    def test_the_shadow_hangs_right_and_below
        assert_equal(["┌──┐", "│ab│░", "└──┘░", " ░░░░"],
                     Tessella.shadow(Tessella.frame("ab", pad: 0)).lines)
    end

    def test_a_shadowed_frame_lints_clean
        fig = Tessella.shadow(Tessella.frame("ab\ncd", title: "t"))
        assert_predicate(Tessella.lint(fig.to_s), :clean?)
    end

    def test_ascii_and_a_glyph_of_ones_own
        assert_equal("+-+\n|x|#\n+-+#\n ###\n",
                     Tessella.shadow("+-+\n|x|\n+-+", ascii: true).to_s)
        assert_includes(Tessella.shadow("ab\ncd", glyph: "▒").to_s, "▒")
        assert_raises(ArgumentError) { Tessella.shadow("ab", glyph: "░░") }
        assert_raises(ArgumentError) do
            Tessella.shadow("ab", glyph: "░", ascii: true)
        end
    end
end

# fill: a pattern in every enclosed blank cell -- inside a frame or any
# closed region -- tiled diagonally; text, lines and the outside stay.
class TestFill < Minitest::Test
    def test_a_frame_fills_its_blank_interior_around_the_text
        assert_equal(["┌───┐", "│░x░│", "└───┘"],
                     Tessella.frame("x", fill: :light, halo: false).lines)
    end

    def test_only_enclosed_regions_fill
        fig = Tessella.beside(Tessella.frame("a", pad: 1), "b c")
        assert_equal("┌───┐ b c\n│:a:│\n└───┘\n",
                     Tessella.fill(fig, pattern: ":", halo: false).to_s)
    end

    def test_a_pattern_tiles_diagonally
        assert_equal(["+---+", "|∴∵∴|", "|∵∴∵|", "+---+"],
                     Tessella.fill("+---+\n|   |\n|   |\n+---+",
                                   pattern: :stipple).lines)
    end

    def test_refusals
        assert_raises(ArgumentError) { Tessella.fill("+\n", pattern: "░▒") }
        assert_raises(ArgumentError) do
            Tessella.frame("x", fill: :light, ascii: true)
        end
        framed = Tessella.frame("x", ascii: true)
        assert_equal("+---+\n|:x:|\n+---+\n",
                     Tessella.fill(framed, ascii: true, halo: false).to_s)
    end
end

# The fill's halo -- blank cells kept beside text -- and frame(fill:),
# which fills only the background the frame adds.
class TestFillHalo < Minitest::Test
    BOX = "┌──────────┐\n│ Antenna  │\n│          │\n└──────────┘"

    def test_a_halo_keeps_the_pattern_off_text
        assert_equal("┌──────────┐\n│ Antenna ·│\n│··········│\n└──────────┘\n",
                     Tessella.fill(BOX, pattern: :sparse).to_s)
        assert_equal("┌──────────┐\n│ Antenna ·│\n│·       ··│\n└──────────┘\n",
                     Tessella.fill(BOX, pattern: :sparse, halo: :around).to_s)
        assert_includes(Tessella.fill(BOX, pattern: :sparse, halo: false).to_s,
                        "│·Antenna··│")
    end

    def test_a_frame_fills_only_its_own_background
        out = Tessella.frame(BOX, fill: :hatch).to_s
        assert_includes(out, "│╱│ Antenna  │╱│")
        assert_includes(out, "│╱│          │╱│")
    end

    def test_an_unknown_halo_is_refused
        assert_raises(ArgumentError) { Tessella.fill(BOX, halo: :wide) }
    end
end
