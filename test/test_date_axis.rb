# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# The date axis: times on x, labelled by span (or xdate:), in UTC,
# spanning the data exactly; and `chart --xdate` reading ISO 8601.
class TestDateAxis < Minitest::Test
    T0 = Time.utc(2026, 11, 1)

    def axis(xs, **)
        Tessella.line(xs, Array.new(xs.size) { it % 3 }, width: 24,
                                                         height: 3, **)
                .to_s.lines.last.split
    end

    def test_the_format_follows_the_span
        assert_equal(%w[2026-11-01 2026-11-05],
                     axis((0..4).map { T0 + (it * 86_400) }))
        assert_equal(["11-01", "00:00", "11-01", "04:00"],
                     axis((0..4).map { T0 + (it * 3600) }))
        assert_equal(%w[00:00:00 00:04:00],
                     axis((0..4).map { T0 + (it * 60) }))
    end

    def test_a_format_of_ones_own_and_utc
        local = Time.new(2026, 11, 1, 10, 0, 0, "+02:00")
        assert_equal(%w[08:00 09:00],
                     axis([local, local + 3600], xdate: "%H:%M"))
    end

    def test_sideways_the_dates_label_the_rows
        out = Tessella.line([T0, T0 + 86_400], [1, 2], width: 10, height: 3,
                                                       orientation: :horizontal)
                      .to_s
        assert_match(/^\s+2026-11-02 │/, out)
        assert_match(/^\s+2026-11-01 │/, out)
    end

    def test_no_xscale_on_a_date_axis
        assert_raises(ArgumentError) { Tessella.line([T0], [1], xscale: :ln) }
    end

    def test_iso_times
        assert_equal(T0, Tessella::IsoTime.parse("2026-11-01"))
        assert_equal(Time.utc(2026, 11, 1, 8, 30),
                     Tessella::IsoTime.parse("2026-11-01T10:30+02:00"))
        assert_nil(Tessella::IsoTime.parse("yesterday"))
        assert_nil(Tessella::IsoTime.parse("2026-13-40"))
    end

    def test_the_command
        out = StringIO.new
        status = Tessella::CLI.run(
            %w[chart --xdate --width 24 --height 3],
            stdin: StringIO.new("d v\n2026-11-01 1\n2026-11-03 2\n"),
            stdout: out, stderr: StringIO.new
        )
        assert_equal([0, %w[2026-11-01 2026-11-03]],
                     [status, out.string.lines.last.split])
    end
end
