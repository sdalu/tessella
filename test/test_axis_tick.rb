# frozen_string_literal: true

require_relative "test_helper"

# Axis.tick, the axis-extreme label (DESIGN.md): a whole Float prints as
# an integer, anything else as Axis.label does.
class TestAxisTick < Minitest::Test
    def test_whole_float_drops_its_point
        assert_equal "10", Tessella::Axis.tick(10.0)
        assert_equal "-1", Tessella::Axis.tick(-1.0)
        assert_equal "0", Tessella::Axis.tick(0.0)
    end

    def test_fraction_and_integer_as_label
        assert_equal "0.25", Tessella::Axis.tick(0.25)
        assert_equal "12", Tessella::Axis.tick(12)
    end
end
