# frozen_string_literal: true

require "open3"
require "stringio"

require_relative "test_helper"

# Shared by both CLI test classes below: Inkchart::CLI.run, in process,
# against StringIO rather than real files or a real stdin.
module CLIHelper
    def run_cli(argv, input = "")
        out = StringIO.new
        err = StringIO.new
        status = Inkchart::CLI.run(
            argv, stdin: StringIO.new(input), stdout: out, stderr: err
        )
        [status, out.string, err.string]
    end
end

# Inkchart::CLI (DESIGN.md, "Command line"): every kind drawn through
# CLI.run on a small data set, and the header row naming columns.
class TestCLIKinds < Minitest::Test
    include CLIHelper

    def test_line_draws_x_y_from_two_columns
        status, out, = run_cli(["--kind", "line"], "0 0\n1 1\n2 4\n")
        assert_equal(0, status)
        assert_includes(out, "┌")
    end

    def test_scatter_draws_unconnected_points
        status, out, = run_cli(["--kind", "scatter"], "1 2\n2 3\n3 1\n")
        assert_equal(0, status)
        assert_includes(out, "┌")
    end

    def test_stairs_draws_a_step_path
        status, out, =
            run_cli(["--kind", "stairs", "--style", "pre"], "1 2\n2 3\n3 1\n")
        assert_equal(0, status)
        assert_includes(out, "┌")
    end

    def test_density_draws_hit_count_shading
        status, out, =
            run_cli(["--kind", "density"], "1 2\n2 3\n3 1\n1 2\n2 2\n")
        assert_equal(0, status)
        assert_includes(out, "┌")
    end

    def test_bar_draws_label_value_rows
        status, out, = run_cli(["--kind", "bar"], "a 1\nb 2\nc 3\n")
        assert_equal(0, status)
        assert_includes(out, "a")
        assert_includes(out, "█")
    end

    def test_histogram_draws_bins_over_one_column_of_samples
        status, out, = run_cli(
            ["--kind", "histogram", "--bins", "4"], "1\n2\n2\n3\n3\n3\n4\n"
        )
        assert_equal(0, status)
        assert_includes(out, "█")
    end

    def test_box_draws_one_box_per_column
        status, out, = run_cli(["--kind", "box"], "1,5\n2,6\n3,7\n")
        assert_equal(0, status)
        assert_includes(out, "┌")
    end

    def test_stem_draws_a_single_sample
        status, out, = run_cli(["--kind", "stem"], "12\n23\n45\n")
        assert_equal(0, status)
        assert_includes(out, "Key:")
    end

    def test_stem_back_to_back_takes_two_columns
        status, out, = run_cli(["--kind", "stem"], "12 10\n23 21\n")
        assert_equal(0, status)
        assert_match(/\|.*\|/, out.lines.first)
    end

    def test_header_row_names_box_columns
        status, out, = run_cli(["--kind", "box"], "apples,pears\n1,5\n2,6\n")
        assert_equal(0, status)
        assert_includes(out, "apples")
        assert_includes(out, "pears")
    end

    def test_header_row_names_a_further_line_series
        status, out, =
            run_cli(["--kind", "line"], "t,sin,cos\n0,0,1\n1,1,0\n2,0,-1\n")
        assert_equal(0, status)
        assert_includes(out, "cos")
    end
end

# Inkchart::CLI, continued: every exit status, a usage error per class
# (unknown option, an option the kind does not take, a bad value), and
# exe/inkchart end to end as a subprocess.
class TestCLIErrors < Minitest::Test
    include CLIHelper

    def test_exit_0_when_drawn
        status, = run_cli(["--kind", "line"], "1\n2\n3\n")
        assert_equal(0, status)
    end

    def test_exit_1_on_bad_input
        status, _out, err = run_cli(["--kind", "line"], "1 2\nx 3\n")
        assert_equal(1, status)
        assert_match(/row 2/, err)
    end

    def test_exit_2_on_usage_error
        status, = run_cli(["--bogus"], "1\n2\n")
        assert_equal(2, status)
    end

    def test_unknown_option_is_a_usage_error_naming_it
        status, _out, err = run_cli(["--bogus"], "1\n2\n")
        assert_equal(2, status)
        assert_match(/bogus/, err)
    end

    def test_an_option_the_kind_does_not_take_names_both
        status, _out, err =
            run_cli(["--kind", "line", "--bins", "4"], "1\n2\n")
        assert_equal(2, status)
        assert_match(/--bins/, err)
        assert_match(/line/, err)
    end

    def test_a_bad_value_is_a_usage_error
        status, _out, err = run_cli(
            ["--kind", "histogram", "--closed", "bogus"], "1\n2\n3\n"
        )
        assert_equal(2, status)
        assert_match(/bogus/, err)
    end

    def test_bad_input_names_the_row_and_the_field
        status, _out, err = run_cli(["--kind", "bar"], "a,1\nb,x\n")
        assert_equal(1, status)
        assert_match(/row 2/, err)
        assert_match(/value/, err)
    end

    def test_help_exits_0_and_prints_usage
        status, out, = run_cli(["--help"])
        assert_equal(0, status)
        assert_includes(out, "Usage")
    end

    def test_version_exits_0_and_prints_the_version
        status, out, = run_cli(["--version"])
        assert_equal(0, status)
        assert_includes(out, Inkchart::VERSION)
    end

    def test_exe_inkchart_runs_end_to_end
        exe = File.expand_path("../exe/inkchart", __dir__)
        out, status = Open3.capture2(
            RbConfig.ruby, exe, "--kind", "line", "--width", "10",
            stdin_data: "0 0\n1 1\n2 4\n"
        )
        assert(status.success?)
        assert_includes(out, "┌")
    end
end

# A header names every series, the first included.
class TestCLIHeaderNames < Minitest::Test
    def test_every_series_named
        input = "x sin cos\n0 0 1\n1 0.8 0.5\n2 0.9 -0.4\n"
        out = StringIO.new
        status = Inkchart::CLI.run([], stdin: StringIO.new(input),
                                       stdout: out, stderr: StringIO.new)
        assert_equal 0, status
        assert_includes out.string, "sin"
        assert_includes out.string, "cos"
    end
end

# Reader's field splitting: a CSV line splits on commas only, so a
# label may hold spaces; a tab line on tabs; only a line with neither
# splits on runs of spaces.
class TestCLIFields < Minitest::Test
    include CLIHelper

    def test_a_csv_label_with_a_space_is_one_field
        status, out, = run_cli(["--kind", "bar"],
                               "New York,8\nParis,2\nRome,3\n")
        assert_equal(0, status)
        assert_includes(out, "New York ┤")
        assert_equal(3, out.lines.count { it.include?("┤") })
    end

    def test_a_csv_header_then_spaced_labels_draws_every_row
        status, out, = run_cli(["--kind", "bar"],
                               "city,pop\nNew York,8\nLos Angeles,4\n")
        assert_equal(0, status)
        assert_includes(out, "Los Angeles ┤")
    end

    def test_a_tab_separated_label_with_a_space_is_one_field
        status, out, = run_cli(["--kind", "bar"], "New York\t8\nParis\t2\n")
        assert_equal(0, status)
        assert_includes(out, "New York ┤")
    end

    def test_a_log_xscale_over_a_zero_x_is_a_usage_error
        status, _, err = run_cli(["--xscale", "log10"], "0 1\n1 2\n10 3\n")
        assert_equal(2, status)
        assert_includes(err, "finite")
    end

    def test_a_zero_width_is_a_usage_error
        status, _, err = run_cli(["--width", "0"], "1\n2\n")
        assert_equal(2, status)
        assert_includes(err, "width")
    end
end
