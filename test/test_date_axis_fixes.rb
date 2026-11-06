# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Date-axis regressions from the blind bug hunt: one date, a file after
# --xdate or --halo, and a first row of dates.
class TestDateAxisFixes < Minitest::Test
    def cli(argv, input = "") = run_command(argv, input)

    def test_one_date_spans_a_day_either_side
        t = Time.utc(2026, 11, 5)
        out = Tessella.scatter([t], [3], width: 20, height: 3).to_s
        assert_includes(out, "2026-11-04")
        assert_includes(out, "2026-11-06")
        assert(Tessella.line([t, t], [3, 4], width: 20, height: 3).to_s)
    end

    def test_a_file_after_xdate_is_the_file
        Dir.mktmpdir do |dir|
            path = File.join(dir, "d.txt")
            File.write(path, "2026-11-01 1\n2026-11-02 3\n")
            status, out, = cli(["chart", "--xdate", path])
            assert_equal(0, status)
            assert_includes(out, "2026-11-01")
        end
        _, out, = cli(%w[chart --xdate %d/%m], "2026-11-01 1\n2026-11-05 2\n")
        assert_includes(out, "01/11")
    end

    def test_a_row_of_dates_is_data_not_a_header
        _, out, = cli(%w[chart --xdate], "2026-11-01 1\n2026-11-05 2\n")
        assert_includes(out, "2026-11-01")
    end

    def test_a_block_after_halo_is_the_block
        status, out, = cli(%w[compose frame --halo -], "hi\n")
        assert_equal(0, status)
        assert_includes(out, "│ hi │")
    end
end
