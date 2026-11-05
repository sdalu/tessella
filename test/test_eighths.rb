# frozen_string_literal: true

require_relative "test_helper"

# Eighth blocks for sub-cell values: an area on the eighths canvas
# (▁..█ up, ▏..█ sideways).
class TestEighths < Minitest::Test
    def body(chart) = chart.to_s.lines[1..-3].map { it[/│(.*)│/, 1] }

    def test_an_area_fills_by_eighths
        out = Tessella.line([0, 1], [0, 1], area: true, canvas: :eighths,
                                            width: 4, height: 1,
                                            ylim: [0, 1], xlim: [0, 1])
        assert_equal(["▁▃▅▇"], body(out))
    end

    def test_sideways_it_fills_across
        out = Tessella.line([0, 1], [0, 1], area: true, canvas: :eighths,
                                            width: 1, height: 4,
                                            xlim: [0, 1], ylim: [0, 1],
                                            orientation: :horizontal)
        assert_equal(%w[█ ▋ ▍ ▏], body(out))
    end

    def test_only_an_area_takes_the_eighths_canvas
        [{ canvas: :eighths }, { canvas: :half_wide },
         { area: true, canvas: :eighths, threshold: 1 }].each do |opts|
            assert_raises(ArgumentError) { Tessella.line([1, 2], **opts).to_s }
        end
    end
end
