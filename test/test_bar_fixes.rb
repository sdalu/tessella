# frozen_string_literal: true

require_relative "test_helper"

# Bar and box regressions from the blind bug hunt: xscale: with series,
# empty data, a label per group, the wrapped legend, an empty sample.
class TestBarFixes < Minitest::Test
    def test_xscale_takes_one_series
        assert_raises(ArgumentError) do
            Tessella.bar(%w[x y], [[1, 10], [100, 1000]], xscale: :log10)
        end
    end

    def test_empty_data_is_refused_by_every_layout
        [{ orientation: :vertical }, { blocks: :braille }].each do |opts|
            assert_raises(ArgumentError) { Tessella.bar([], [], **opts).to_s }
        end
    end

    def test_every_group_needs_its_label
        assert_raises(ArgumentError) do
            Tessella.bar(%w[a b c], [[1, 2], [3, 4]])
        end
    end

    def test_an_empty_box_sample_is_refused
        assert_raises(ArgumentError) { Tessella.box(%w[e f], [[], [1, 2]]) }
    end

    # The legend after an x label, each line indented under the body.
    def test_a_wrapped_legend_follows_the_x_label
        names = %w[one two three four five]
        out = Tessella.bar(%w[a], [[1, 2, 3, 4, 5]], orientation: :vertical,
                                                     width: 10, height: 2,
                                                     series: names,
                                                     xlabel: "quarter").to_s
        assert_includes(out, "quarter")
        assert_includes(out, "╳ five")
        assert(out.lines.last.start_with?("  "))
    end
end
