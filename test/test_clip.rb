# frozen_string_literal: true

require_relative "test_helper"

# A segment far past the limits (a spike under ylim:) draws where it
# crosses the plot, at once: stepping it all took minutes.
class TestClip < Minitest::Test
    def test_a_far_spike_draws_quickly
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        out = Tessella.line([1, 2], [0, 1e9], ylim: [0, 1], width: 20,
                                              height: 5).to_s
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        assert_operator(elapsed, :<, 2)
        assert_equal(5, out.lines.count { it.include?("⡇") })
    end
end
