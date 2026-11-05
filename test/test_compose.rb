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
                     AsciiArt::Block.new(["AB", "CD", "", " "]).lines)
    end

    def test_an_empty_block_is_refused
        assert_raises(ArgumentError) { AsciiArt::Block.new(["", ""]) }
    end

    def test_a_tab_is_refused_naming_the_line
        error = assert_raises(ArgumentError) do
            AsciiArt::Block.new(%W[ok a\tb])
        end
        assert_includes(error.message, "line 2")
    end

    def test_width_is_display_columns_and_ignores_colour
        block = AsciiArt::Block.new(["中文", "\e[31mab\e[0m"])
        assert_equal(4, block.width)
        assert_equal(2, AsciiArt::Width.of("\e[31mab\e[0m"))
    end

    def test_from_takes_a_chart
        block = AsciiArt::Block.from(AsciiArt.bar(%w[a], [1]))
        assert_operator(block.height, :>, 1)
    end

    def test_check_width_names_the_line_and_the_budget
        error = assert_raises(ArgumentError) do
            AsciiArt::Block.new(%w[ab abcd]).check_width!(3)
        end
        assert_equal("output is 4 columns on line 2 (max-width 3)",
                     error.message)
    end
end

class TestCompose < Minitest::Test
    AB = "AB\nCD\n"

    def test_frame_light
        assert_equal("┌────┐\n│ AB │\n│ CD │\n└────┘\n",
                     AsciiArt.frame(AB).to_s)
    end

    def test_frame_title_is_centred_in_the_top_edge
        assert_equal("┌─ T ─┐", AsciiArt.frame("X", title: "T").lines.first)
    end

    def test_every_style_draws_its_own_corners
        { light: "┌┐└┘", heavy: "┏┓┗┛", double: "╔╗╚╝", rounded: "╭╮╰╯",
          ascii: "++++" }.each do |style, corners|
            lines = AsciiArt.frame(AB, style: style).lines
            got = lines.first[0] + lines.first[-1] + lines.last[0] +
                  lines.last[-1]
            assert_equal(corners, got, style)
        end
    end

    def test_beside_pads_each_block_to_its_own_width
        assert_equal("AB X\nCD\n", AsciiArt.beside(AB, "X").to_s)
    end

    def test_beside_pads_cjk_and_braille_by_display_width
        assert_equal("中文 ⠉⠒\nAB   Y\n",
                     AsciiArt.beside("中文\nAB", "⠉⠒\nY").to_s)
    end

    def test_beside_align_bottom_fills_from_the_top
        assert_equal("AB
CD X
", AsciiArt.beside(AB, "X", align: :bottom).to_s)
    end

    def test_stack_with_a_rule
        assert_equal("AB\nCD\n==\nX\n", AsciiArt.stack(AB, "X", rule: "=").to_s)
    end

    def test_stack_center_shifts_a_narrower_block_as_a_whole
        assert_equal("ABC\n X\n", AsciiArt.stack("ABC", "X", center: true).to_s)
    end

    def test_indent_strips_the_prefix_blank_on_an_empty_line
        assert_equal("# AB\n#\n# CD\n",
                     AsciiArt.indent("AB\n\nCD", prefix: "# ").to_s)
    end

    def test_caption_above
        assert_equal("Fig\n\nAB\nCD\n",
                     AsciiArt.caption(AB, text: "Fig", above: true).to_s)
    end

    def test_ascii_draws_ascii_glyphs
        assert(AsciiArt.frame(AB, ascii: true).to_s.ascii_only?)
    end

    def test_ascii_refuses_another_style_and_non_ascii_content
        assert_raises(ArgumentError) do
            AsciiArt.frame(AB, style: :double, ascii: true)
        end
        assert_raises(ArgumentError) { AsciiArt.frame("é", ascii: true) }
        assert_raises(ArgumentError) do
            AsciiArt.frame(AB, title: "é", ascii: true)
        end
    end

    def test_refusals_name_what_they_refuse
        assert_raises(ArgumentError) { AsciiArt.beside(AB) }
        assert_raises(ArgumentError) { AsciiArt.stack(AB) }
        assert_raises(ArgumentError) { AsciiArt.frame(AB, style: :triangle) }
        assert_raises(ArgumentError) do
            AsciiArt.beside(AB, "X", align: :sideways)
        end
        assert_raises(ArgumentError) { AsciiArt.stack(AB, "X", rule: "==") }
        assert_raises(ArgumentError) { AsciiArt.frame(AB, pad: -1) }
    end

    def test_a_coloured_chart_frames_by_its_visible_width
        chart = AsciiArt.bar(%w[a b], [1, 2], color: true)
        framed = AsciiArt.frame(chart)
        plain = AsciiArt.frame(AsciiArt.bar(%w[a b], [1, 2]))
        assert_equal(plain.lines.first, framed.lines.first)
    end
end

class TestComposeCLI < Minitest::Test
    def run_cli(*argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = AsciiArt::CLI.run(["compose", *argv],
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
