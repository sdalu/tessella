# frozen_string_literal: true

require_relative "test_helper"

# The optional rmagick path (DESIGN.md, "Images"): without the gem, an
# image tessella cannot decode itself is refused with a message saying
# what to do; with it (GEM_PATH pointing at an rmagick install), any
# format ImageMagick reads becomes a Raster, alpha over black.
class TestRMagickReader < Minitest::Test
    READER = Tessella::RMagickReader

    def without_rmagick
        saved = READER.instance_variable_get(:@available)
        READER.instance_variable_set(:@available, false)
        yield
    ensure
        READER.instance_variable_set(:@available, saved)
    end

    def test_without_rmagick_another_format_is_refused_saying_what_to_do
        without_rmagick do
            error = assert_raises(ArgumentError) do
                Tessella::Raster.decode("GIF89a\x01\x00\x01\x00")
            end
            assert_includes(error.message, "rmagick gem is not installed")
            assert_includes(error.message, "pgm:-")
        end
    end

    def test_pnm_needs_no_rmagick
        without_rmagick do
            raster = Tessella::Raster.decode("P2 2 1 255 0 255\n")
            assert_equal([0.0, 1.0], raster.luma)
        end
    end

    def need_rmagick = (skip "rmagick not installed" unless READER.available?)

    def blob(format, color, alpha = 1.0)
        image = ::Magick::Image.new(2, 1) { |o| o.background_color = color }
        image.alpha(::Magick::ActivateAlphaChannel) if alpha < 1.0
        image.format = format
        image.to_blob
    end

    def test_with_rmagick_a_jpeg_decodes
        need_rmagick
        raster = Tessella::Raster.decode(blob("JPEG", "white"))
        assert_equal([2, 1], [raster.width, raster.height])
        assert_in_delta(1.0, raster.luma.first, 0.01)
    end

    def test_with_rmagick_alpha_is_composited_over_black
        need_rmagick
        raster = Tessella::Raster.decode(blob("TIFF", "rgba(255,0,0,0.5)", 0.5))
        assert_in_delta(0.299 * 0.5, raster.luma.first, 0.01)
    end

    def test_with_rmagick_garbage_is_an_unreadable_image
        need_rmagick
        error = assert_raises(ArgumentError) { READER.decode("garbage") }
        assert_includes(error.message, "unreadable image")
    end
end
