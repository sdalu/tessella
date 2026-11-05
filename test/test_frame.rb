# frozen_string_literal: true

require_relative "test_helper"

# Tessella::Frame: border, labels, title, legend, render (DESIGN.md,
# "Frame and Color"). Frame knows nothing of data; every case below
# hands it a body and labels built by hand.
class TestFrame < Minitest::Test
    def test_every_assembled_part_at_once
        frame = Tessella::Frame.new(**fixture_options)
        assert_equal(fixture_expected, frame.to_s)
    end

    def test_no_line_ends_in_a_blank
        frame = Tessella::Frame.new(
            body: solid_body(3, 2, "#"), title: "T", xlabel: "x",
            left: { 0 => "a" }, right: { 0 => "bb" }, bottom: %w[lo hi]
        )
        lines = frame.to_s.split("\n", -1)
        assert_equal("", lines.last, "ends in exactly one newline")
        refute(lines[0..-2].any? { |line| line.end_with?(" ") })
    end

    def test_box_border_draws_a_full_frame
        out = Tessella::Frame.new(body: solid_body(2, 1, "#")).to_s
        assert_includes(out, "┌──┐")
        assert_includes(out, "└──┘")
        assert_includes(out, "│##│")
    end

    def test_bar_border_ticks_every_row_with_no_right_edge
        frame = Tessella::Frame.new(body: solid_body(2, 2, "#"), border: :bar)
        rows = frame.to_s.split("\n")[1..2]
        assert(rows.all? { |row| row.include?("┤") })
        refute(rows.any? { |row| row.include?("│") })
    end

    def test_none_border_draws_no_border_at_all
        frame = Tessella::Frame.new(body: solid_body(2, 1, "#"), border: :none)
        refute_match(/[┌┐└┘│┤+\-|]/, frame.to_s)
        assert_includes(frame.to_s, "##")
    end

    def test_ascii_draws_plus_dash_pipe_and_nothing_non_ascii
        frame = Tessella::Frame.new(body: solid_body(2, 1, "#"), ascii: true,
                                    title: "T")
        assert_includes(frame.to_s, "+--+")
        assert_includes(frame.to_s, "|##|")
        refute_match(/[^\x00-\x7F]/, frame.to_s)
    end

    def test_ascii_bar_tick_is_a_pipe
        frame = Tessella::Frame.new(body: solid_body(2, 1, "#"), border: :bar,
                                    ascii: true)
        assert_includes(frame.to_s, "|##")
        refute_match(/[^\x00-\x7F]/, frame.to_s)
    end

    def test_color_false_never_emits_an_escape
        body = [[Tessella::Cell.new(char: "a", color: :red)]]
        frame = Tessella::Frame.new(body: body, color: false)
        refute_includes(frame.to_s, "\e")
    end

    def test_color_true_wraps_each_run_and_resets
        frame = Tessella::Frame.new(body: [mixed_color_row], color: true,
                                    border: :none)
        assert_includes(frame.to_s, "\e[31mab\e[0mc\e[34md\e[0m")
    end

    def test_title_is_centred_over_the_frame
        # width 10, "Hi": offset = (10/2.0 - 2/2.0).round = 4, over a
        # border that itself starts 4 columns in (no left labels).
        frame = Tessella::Frame.new(body: solid_body(10, 1, "#"), title: "Hi")
        title_line, border_line = frame.to_s.split("\n")
        assert_equal(4, border_line.index("┌"))
        assert_equal(8, title_line.index("Hi"))
    end

    private

    def solid_body(width, height, char)
        Array.new(height) do
            Array.new(width) { Tessella::Cell.new(char: char, color: nil) }
        end
    end

    def mixed_color_row
        [
            Tessella::Cell.new(char: "a", color: :red),
            Tessella::Cell.new(char: "b", color: :red),
            Tessella::Cell.new(char: "c", color: nil),
            Tessella::Cell.new(char: "d", color: :blue)
        ]
    end

    def fixture_options
        { body: solid_body(4, 2, "#"), title: "Hi", xlabel: "X",
          ylabel: "Y", left: { 0 => "L0", 1 => "L1" }, right: { 0 => "R" },
          bottom: %w[lo hi] }
    end

    def fixture_expected
        lines = [
            "#{" " * 9}Hi", "#{" " * 8}┌────┐",
            "   Y L0 │####│ R", "     L1 │####│",
            "#{" " * 8}└────┘", "#{" " * 8}lo  hi", "#{" " * 10}X"
        ]
        "#{lines.join("\n")}\n"
    end
end

# The oracle half: a Frame built around unicode_plot's own canvas and
# labels must lay out line for line the same way unicode_plot does
# (DESIGN.md's layout note), modulo trailing blanks and U+2800.
class TestFrameOracle < Minitest::Test
    include Oracle::Test

    def test_oracle_lineplot_layout_matches_unicode_plot
        need_oracle
        plot = UnicodePlot.lineplot([1, 2, 3, 4, 5],
                                    [1.0, 4.0, 9.0, 16.0, 25.0],
                                    title: "Line", xlabel: "x",
                                    ylabel: "y", name: "series1")
        assert_oracle_match(plot, :box)
    end

    def test_oracle_barplot_layout_matches_unicode_plot
        need_oracle
        plot = UnicodePlot.barplot(
            ["Paris", "New York", "Moskau", "Madrid"],
            [2.244, 8.406, 11.92, 3.165],
            xlabel: "population"
        )
        assert_oracle_match(plot, :bar)
    end

    private

    def assert_oracle_match(plot, border)
        frame = Tessella::Frame.new(**frame_options(plot, border))
        assert_equal(normalize(Oracle.render(plot)), normalize(frame.to_s))
    end

    def frame_options(plot, border)
        {
            body: oracle_body(plot), border: border, title: plot.title,
            xlabel: plot.xlabel, ylabel: plot.ylabel,
            left: plot.labels_left, right: plot.labels_right,
            bottom: [plot.decorations[:bl], plot.decorations[:br]]
        }
    end

    def oracle_body(plot)
        (0...plot.n_rows).map { |row| oracle_row_cells(plot, row) }
    end

    def oracle_row_cells(plot, row)
        io = StringIO.new
        plot.print_row(UnicodePlot::IOContext.new(io, color: false), row)
        io.string.each_char.map { |c| Tessella::Cell.new(char: c, color: nil) }
    end

    def normalize(text)
        text.gsub("⠀", " ").split("\n", -1).map(&:rstrip)
    end
end

# Labels in East Asian wide characters take two columns each, as a
# terminal draws them, so the frame stays aligned.
class TestFrameWideLabels < Minitest::Test
    def test_a_wide_character_label_keeps_the_frame_aligned
        lines = Tessella.bar(%w[日本 b], [1, 2]).to_s.lines
        columns = lines.map { Tessella::Width.of(it[/\A[^┤┌└]*/]) }
        assert_equal(1, columns.uniq.size, lines.join)
    end

    def test_a_wide_title_is_centred_by_its_columns
        chart = Tessella.line([1, 2], title: "温度温度", width: 20)
        title, top = chart.to_s.lines
        offset = title.index("温") - top.index("┌")
        assert_equal(6, offset) # (20 - 8 columns) / 2
    end

    def test_width_counts_wide_characters_as_two
        assert_equal(6, Tessella::Width.of("日本ab"))
        assert_equal(1, Tessella::Width.of("é"))
    end
end

# Width's tables are the ascii-art skill's (artlint.rb's, generated from
# Unicode 15.1 East Asian Width): spot checks where a hand-made table
# goes wrong.
class TestWidthTables < Minitest::Test
    def test_wide_emoji_outside_the_cjk_blocks_take_two
        assert_equal(2, Tessella::Width.of("⌚"))   # U+231A
        assert_equal(2, Tessella::Width.of("⭐"))   # U+2B50
    end

    def test_neutral_symbols_inside_cjk_neighbourhoods_take_one
        assert_equal(1, Tessella::Width.of("䷀"))   # U+4DC0, a hexagram
    end

    def test_invisible_format_characters_take_none
        assert_equal(0, Tessella::Width.of("⁠")) # word joiner
        assert_equal(0, Tessella::Width.of("﻿")) # zero-width no-break
    end
end
