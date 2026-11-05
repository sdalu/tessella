# frozen_string_literal: true

require_relative "test_helper"

# Tessella::Png (DESIGN.md, "Images"): the pure-Ruby PNG decoder --
# every colour type x bit depth it allows, all five filter types,
# Adam7 interlacing, tRNS, multiple IDAT chunks, odd (bit-packed)
# widths, 1x1, and the refusals a malformed stream must trigger.
#
# Fixtures are tiny PNGs built from a known pixel grid, embedded here
# as base64. Filtering and interlacing round-trip losslessly, so a
# fixture's expected luma is simply Raster.luma over the grid it was
# built from -- independent of which filter or interlace choice
# happened to package it.
module PngFixture
    # unpack1("m") is core Ruby's base64; the base64 library is a
    # bundled gem in Ruby 3.4, not something the suite may need.
    def decode(base64) = Tessella::Png.decode(base64.unpack1("m").b)

    def assert_png(base64, width, height, expected)
        raster = decode(base64)
        assert_equal([width, height], [raster.width, raster.height])
        raster.luma.each_with_index do |v, i|
            assert_in_delta(expected[i], v, 1e-9)
        end
    end
end

# Colour types 0 (grey) and 2 (RGB), every bit depth each allows.
class TestPngGreyAndRgb < Minitest::Test
    include PngFixture

    B64_GREY1 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAADAQAAAACRkeMsAAAADklEQVR4nGNw" \
                "YGhgYAAAAsYAwcduY0IAAAAASUVORK5CYII="
    B64_GREY2 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAADAgAAAADWMZn8AAAADklEQVR4nGMQ" \
                "YNjAkAAAAsYBIaj8O4sAAAAASUVORK5CYII="
    B64_GREY4 = "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACBAAAAAB979THAAAADklEQVR4nGNg" \
                "/cDwlQEABckB64QAcR0AAAAASUVORK5CYII="
    B64_GREY8 = "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAAAAAC4HznGAAAAEElEQVR4nGNg" \
                "aPjP4HCACwAKTQKK3+KFegAAAABJRU5ErkJggg=="
    B64_GREY16 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACEAAAAAAHTY67AAAAEklEQVR4" \
                 "nGNgYPj/n6GBwcASAA+WAuj39QeGAAAAAElFTkSuQmCC"
    B64_RGB8 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAE0lEQVR4nGP4" \
               "z8DAAMIM/7lE5AAaWAM6VmOiPAAAAABJRU5ErkJggg=="
    B64_RGB16 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACEAIAAACtREYwAAAAF0lEQVR4nGP4" \
                "/58BDGA0kMH8gv0C9w4AaK0IgP0jnksAAAAASUVORK5CYII="

    def test_grey_depth1
        g = [0, 1, 1, 0, 0, 0]
        expected = g.map { |v| Tessella::Raster.luma(v, v, v) }
        assert_png(B64_GREY1, 2, 3, expected)
    end

    def test_grey_depth2
        g = [0, 1, 2, 3, 1, 2]
        expected = g.map do |v|
            v /= 3.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_GREY2, 2, 3, expected)
    end

    def test_grey_depth4
        g = [0, 5, 15, 15, 5, 0]
        expected = g.map do |v|
            v /= 15.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_GREY4, 3, 2, expected)
    end

    def test_grey_depth8
        g = [0, 128, 255, 64, 192, 10]
        expected = g.map do |v|
            v /= 255.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_GREY8, 3, 2, expected)
    end

    def test_grey_depth16
        g = [0, 65_535, 32_768, 12_345]
        expected = g.map do |v|
            v /= 65_535.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_GREY16, 2, 2, expected)
    end

    def test_rgb_depth8
        g = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [10, 20, 30]]
        expected = g.map do |r, gr, b|
            Tessella::Raster.luma(r / 255.0, gr / 255.0, b / 255.0)
        end
        assert_png(B64_RGB8, 2, 2, expected)
    end

    def test_rgb_depth16
        g = [[65_535, 0, 0], [0, 65_535, 0], [0, 0, 65_535],
             [1000, 2000, 3000]]
        expected = g.map do |r, gr, b|
            Tessella::Raster.luma(r / 65_535.0, gr / 65_535.0, b / 65_535.0)
        end
        assert_png(B64_RGB16, 2, 2, expected)
    end
end

# Colour type 3 (palette), every bit depth it allows.
class TestPngPalette < Minitest::Test
    include PngFixture

    B64_PAL1 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACAQMAAABIeJ9nAAAABlBMVEUKFB7I" \
               "0tyCjXXdAAAADElEQVR4nGNwYGgAAAFEAME6ehxWAAAAAElFTkSuQmCC"
    B64_PAL2 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACAgMAAAAP2OW3AAAADFBMVEUAAABV" \
               "VVWqqqr////Bf2LRAAAADElEQVR4nGMQYNgAAADkAMEnqOhXAAAAAElFTkSu" \
               "QmCC"
    B64_PAL4 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACBAMAAACAmBAXAAAAMFBMVEUAAAAR" \
               "EREiIiIzMzNERERVVVVmZmZ3d3eIiIiZmZmqqqq7u7vMzMzd3d3u7u7///97" \
               "EBgKAAAADElEQVR4nGOwZPgAAAGfASpGILe4AAAAAElFTkSuQmCC"
    B64_PAL8 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAMAAABFaP0WAAACWFBMVEUA/4AB" \
               "/oAC/YAD/IAE+4AF+oAG+YAH+IAI94AJ9oAK9YAL9IAM84AN8oAO8YAP8IAQ" \
               "74AR7oAS7YAT7IAU64AV6oAW6YAX6IAY54AZ5oAa5YAb5IAc44Ad4oAe4YAf" \
               "4IAg34Ah3oAi3YAj3IAk24Al2oAm2YAn2IAo14Ap1oAq1YAr1IAs04At0oAu" \
               "0YAv0IAwz4AxzoAyzYAzzIA0y4A1yoA2yYA3yIA4x4A5xoA6xYA7xIA8w4A9" \
               "woA+wYA/wIBAv4BBvoBCvYBDvIBEu4BFuoBGuYBHuIBIt4BJtoBKtYBLtIBM" \
               "s4BNsoBOsYBPsIBQr4BRroBSrYBTrIBUq4BVqoBWqYBXqIBYp4BZpoBapYBb" \
               "pIBco4BdooBeoYBfoIBgn4BhnoBinYBjnIBkm4BlmoBmmYBnmIBol4BploBq" \
               "lYBrlIBsk4BtkoBukYBvkIBwj4BxjoByjYBzjIB0i4B1ioB2iYB3iIB4h4B5" \
               "hoB6hYB7hIB8g4B9goB+gYB/gICAf4CBfoCCfYCDfICEe4CFeoCGeYCHeICI" \
               "d4CJdoCKdYCLdICMc4CNcoCOcYCPcICQb4CRboCSbYCTbICUa4CVaoCWaYCX" \
               "aICYZ4CZZoCaZYCbZICcY4CdYoCeYYCfYICgX4ChXoCiXYCjXICkW4ClWoCm" \
               "WYCnWICoV4CpVoCqVYCrVICsU4CtUoCuUYCvUICwT4CxToCyTYCzTIC0S4C1" \
               "SoC2SYC3SIC4R4C5RoC6RYC7RIC8Q4C9QoC+QYC/QIDAP4DBPoDCPYDDPIDE" \
               "O4DFOoDGOYDHOIBL4tqaAAAADklEQVR4nGNgSGE4bgQAA1YBXujY488AAAAA" \
               "SUVORK5CYII="

    def test_depth1
        colours = [[10, 20, 30], [200, 210, 220]]
        g = [0, 1, 1, 0].map { |i| colours[i] }
        expected = g.map do |r, gr, b|
            Tessella::Raster.luma(r / 255.0, gr / 255.0, b / 255.0)
        end
        assert_png(B64_PAL1, 2, 2, expected)
    end

    def test_depth2
        expected = [0, 1, 2, 3].map do |i|
            v = i * 85 / 255.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_PAL2, 2, 2, expected)
    end

    def test_depth4
        expected = [3, 9, 15, 0].map do |i|
            v = (i * 17) / 255.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_PAL4, 2, 2, expected)
    end

    def test_depth8
        expected = [0, 100, 199, 50].map do |i|
            Tessella::Raster.luma(i / 255.0, (255 - i) / 255.0, 128 / 255.0)
        end
        assert_png(B64_PAL8, 2, 2, expected)
    end
end

# Colour types 4 (grey+alpha) and 6 (RGBA), every bit depth each
# allows.
class TestPngAlpha < Minitest::Test
    include PngFixture

    B64_GA8 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAQAAADYv8WvAAAAEklEQVR4nGM4" \
              "8T+lgcGI4b8DABfMBB294CYNAAAAAElFTkSuQmCC"
    B64_GA16 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACEAQAAACILxnsAAAAGElEQVR4nGN4" \
               "lfD/f6kB8wsGEPj/v4EBAEvaB1crISpOAAAAAElFTkSuQmCC"
    B64_RGBA8 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFklEQVR4nGP4" \
                "z8DwHwgbGEA0l4jcfwA3gAW4iq3uIgAAAABJRU5ErkJggg=="
    B64_RGBA16 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACEAYAAAAiJtFnAAAAHklEQVR4" \
                 "nGP4/58BCEAkCDcwMMC4zC/YL3Dv+P8fANLjDPwdsJyQAAAAAElFTkSuQmCC"

    def test_grey_alpha_depth8
        g = [[200, 255], [100, 128], [50, 0], [255, 64]]
        expected = g.map do |gg, a|
            gg /= 255.0
            Tessella::Raster.luma(gg, gg, gg, a / 255.0)
        end
        assert_png(B64_GA8, 2, 2, expected)
    end

    def test_grey_alpha_depth16
        g = [[60_000, 65_535], [30_000, 1000], [0, 0], [65_535, 32_768]]
        expected = g.map do |gg, a|
            gg /= 65_535.0
            Tessella::Raster.luma(gg, gg, gg, a / 65_535.0)
        end
        assert_png(B64_GA16, 2, 2, expected)
    end

    def test_rgba_depth8
        g = [[255, 0, 0, 255], [0, 255, 0, 128], [0, 0, 255, 0],
             [10, 20, 30, 255]]
        expected = g.map do |r, gr, b, a|
            Tessella::Raster.luma(r / 255.0, gr / 255.0, b / 255.0,
                                  a / 255.0)
        end
        assert_png(B64_RGBA8, 2, 2, expected)
    end

    def test_rgba_depth16
        g = [[65_535, 0, 0, 65_535], [0, 65_535, 0, 32_768], [0, 0, 65_535, 0],
             [1000, 2000, 3000, 65_535]]
        expected = g.map do |r, gr, b, a|
            Tessella::Raster.luma(r / 65_535.0, gr / 65_535.0, b / 65_535.0,
                                  a / 65_535.0)
        end
        assert_png(B64_RGBA16, 2, 2, expected)
    end
end

# All five filter types (None/Sub/Up/Average/Paeth), same pixel grid.
class TestPngFilters < Minitest::Test
    include PngFixture

    GRID = [[10, 20, 30], [40, 50, 60], [70, 80, 90], [90, 80, 70],
            [60, 50, 40], [30, 20, 10], [1, 2, 3], [250, 251, 252],
            [100, 101, 102]].freeze
    EXPECTED = GRID.map do |r, g, b|
        Tessella::Raster.luma(r / 255.0, g / 255.0, b / 255.0)
    end.freeze

    B64 = {
        0 => "iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAJklEQVR4nGPg" \
             "EpHTMLJxC4hiiApwszHSkBPhYmBkYv71+09KahoAV6sHqwy2K1cAAAAASUVO" \
             "RK5CYII=",
        1 => "iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAHklEQVR4nGPk" \
             "EpGDAMaoALdHYMDIyMT88+fPrKwsAIETC18rsLjXAAAAAElFTkSuQmCC",
        2 => "iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAJ0lEQVR4nGPi" \
             "EpHTMLJxC4hiCrDREGF4c+PIBqblm/buO3nFLTAGAH77Cy2XF7evAAAAAElF" \
             "TkSuQmCC",
        3 => "iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAKUlEQVR4nAEe" \
             "AOH/AwoUHiMoLTI3PANVRjf78efd08kD1Nrg3OHn2N7jnucPTPJa10UAAAAA" \
             "SUVORK5CYII=",
        4 => "iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAI0lEQVR4nGPh" \
             "EpGDAJYAG41Hjx7dOHKOZfmmvT9//szKygIAi0kNAI99VocAAAAASUVORK5C" \
             "YII="
    }.freeze

    def test_filter_none     = assert_png(B64[0], 3, 3, EXPECTED)
    def test_filter_sub      = assert_png(B64[1], 3, 3, EXPECTED)
    def test_filter_up       = assert_png(B64[2], 3, 3, EXPECTED)
    def test_filter_average  = assert_png(B64[3], 3, 3, EXPECTED)
    def test_filter_paeth    = assert_png(B64[4], 3, 3, EXPECTED)
end

# Adam7 interlacing, for a grey and an RGBA image.
class TestPngInterlace < Minitest::Test
    include PngFixture

    B64_GREY = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAAAAAGWY9HBAAAAJUlEQVR4nGNg" \
               "YGgAIYcDIMTg0AAlFBIWPEAnGBQcEhoWHMDHAADa/BwBMVezpQAAAABJRU5E" \
               "rkJggg=="
    B64_RGBA = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAAGzCI4dAAAAd0lEQVR4nBXM" \
               "oREEQQhEUfRoNBrdGo2+IDaIC2Jznv0t3lQN9SEidKP9xE+3EclvPEl+40m0" \
               "bqIx7cGfARqDOPQFYb17yArCeuVwqCCsjx72CsL6RqTuQaLQEAabDoYAiUJD" \
               "GOw4eAiQKDSEwT4OXgIkCg1hsPgA9BZmgSccFzcAAAAASUVORK5CYII="

    def test_grey
        g = (0...8).flat_map { |_y| (0...8).map { |x| (x * 32) % 256 } }
        expected = g.map do |v|
            v /= 255.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_GREY, 8, 8, expected)
    end

    def test_rgba
        g = (0...8).flat_map do |y|
            (0...8).map { |x| [(x * 10) % 256, (y * 20) % 256, 50, 255] }
        end
        expected = g.map do |r, gr, b, a|
            Tessella::Raster.luma(r / 255.0, gr / 255.0, b / 255.0,
                                  a / 255.0)
        end
        assert_png(B64_RGBA, 8, 8, expected)
    end
end

# tRNS, for the three colour types it applies to.
class TestPngTrns < Minitest::Test
    include PngFixture

    B64_GREY = "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAAAAAC4HznGAAAAAnRSTlMAgJsr" \
               "ThgAAAAQSURBVHicY2Bo+M/wv4EBAAwAAv+qDn6+AAAAAElFTkSuQmCC"
    B64_RGB = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAABnRSTlMA/wAA" \
              "AACkwsAdAAAAEklEQVR4nGP4z8DAAMIM/4EkABzxA/0tEma7AAAAAElFTkSu" \
              "QmCC"
    B64_PAL = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACBAMAAACAmBAXAAAADFBMVEUKFB7I" \
              "ZDIA/wD/AADkKJHuAAAABHRSTlP/AP//07BylAAAAAxJREFUeJxjYGRQBgAA" \
              "KgAlArf/2wAAAABJRU5ErkJggg=="

    def test_grey
        g = [0, 128, 255, 255, 128, 0]
        expected = g.map do |v|
            a = v == 128 ? 0.0 : 1.0
            vv = v / 255.0
            Tessella::Raster.luma(vv, vv, vv, a)
        end
        assert_png(B64_GREY, 3, 2, expected)
    end

    def test_rgb
        g = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 0, 0]]
        expected = g.map do |r, gr, b|
            a = [r, gr, b] == [255, 0, 0] ? 0.0 : 1.0
            Tessella::Raster.luma(r / 255.0, gr / 255.0, b / 255.0, a)
        end
        assert_png(B64_RGB, 2, 2, expected)
    end

    def test_palette
        colours = [[10, 20, 30], [200, 100, 50], [0, 255, 0], [255, 0, 0]]
        alphas = [255, 0, 255, 255]
        expected = [0, 1, 2, 3].map do |i|
            r, g, b = colours[i]
            Tessella::Raster.luma(r / 255.0, g / 255.0, b / 255.0,
                                  alphas[i] / 255.0)
        end
        assert_png(B64_PAL, 2, 2, expected)
    end
end

# Multiple IDAT chunks, odd (bit-packed) widths, and a 1x1 image.
class TestPngEdgeCases < Minitest::Test
    include PngFixture

    B64_MULTI_IDAT = "iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAAAAADFp7CUAAAADklEQ" \
                     "VR4nAEqANX/AAAHDhUcI1OG678AAAAOSURBVAAqMTg/Rk0AVFtiaX" \
                     "B3cm9sUQAAAA5JREFUAH6FjJOaoQCor7a9xMsI4j62AAAAC0lEQV" \
                     "QA0tng5+717ncRO+PoDJkAAAAASUVORK5CYII="
    B64_ODD1 = "iVBORw0KGgoAAAANSUhEUgAAAAUAAAABAQAAAAA+hVleAAAACklEQVR4" \
               "nGOIAAAAWgBZf//qzwAAAABJRU5ErkJggg=="
    B64_ODD4 = "iVBORw0KGgoAAAANSUhEUgAAAAMAAAABBAMAAADpzgmHAAAAMFBMVEUA" \
               "AAAREREiIiIzMzNERERVVVVmZmZ3d3eIiIiZmZmqqqq7u7vMzMzd3d3u" \
               "7u7///97EBgKAAAAC0lEQVR4nGMQnQAAAL0AppYmFbsAAAAASUVORK5C" \
               "YII="
    B64_ONE_PX = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQV" \
                 "R4nGPgUbIAAACkAGeY0OCYAAAAAElFTkSuQmCC"

    def test_multiple_idat_chunks
        g = (0...6).flat_map { |y| (0...6).map { |x| (x + (y * 6)) * 7 } }
        expected = g.map do |v|
            v = (v % 256) / 255.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_MULTI_IDAT, 6, 6, expected)
    end

    def test_odd_width_1_bit
        g = [0, 1, 0, 1, 1]
        expected = g.map { |v| Tessella::Raster.luma(v, v, v) }
        assert_png(B64_ODD1, 5, 1, expected)
    end

    def test_odd_width_4_bit
        expected = [1, 5, 9].map do |i|
            v = (i * 17) / 255.0
            Tessella::Raster.luma(v, v, v)
        end
        assert_png(B64_ODD4, 3, 1, expected)
    end

    def test_one_by_one
        expected = [Tessella::Raster.luma(12 / 255.0, 34 / 255.0,
                                          56 / 255.0)]
        assert_png(B64_ONE_PX, 1, 1, expected)
    end
end

# Every refusal: a bad signature, a bad CRC, a truncated stream, an
# unknown critical chunk, an invalid colour type/bit depth, a missing
# PLTE/IDAT/IHDR, a bad filter type, and a zlib error.
class TestPngRefusals < Minitest::Test
    def chunk(type, data)
        [data.bytesize].pack("N") + type + data +
            [Zlib.crc32(type + data)].pack("N")
    end

    def ihdr(width: 2, height: 2, depth: 8, colour: 2, interlace: 0)
        [width, height, depth, colour, 0, 0, interlace].pack("NNC5")
    end

    def minimal_idat(colour, depth, width, height)
        channels = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.fetch(colour)
        rowbytes = ((width * channels * depth) + 7) / 8
        Zlib::Deflate.deflate("\x00#{"\x00" * rowbytes}" * height)
    end

    def refused(bytes)
        assert_raises(ArgumentError) { Tessella::Png.decode(bytes) }
    end

    def test_bad_signature
        error = refused("not a png at all".b)
        assert_includes(error.message, "signature")
    end

    def test_bad_crc
        good = chunk("IHDR", ihdr)
        bad = good[0...-1] + (good[-1].ord ^ 0xff).chr
        error = refused(Tessella::Png::SIGNATURE + bad + chunk("IEND", ""))
        assert_includes(error.message, "CRC")
    end

    def test_truncated_stream
        bytes = Tessella::Png::SIGNATURE + chunk("IHDR", ihdr)[0, 4]
        assert_includes(refused(bytes).message, "truncated")
    end

    def test_unknown_critical_chunk
        bytes = Tessella::Png::SIGNATURE + chunk("IHDR", ihdr) +
                chunk("FOOX", "") + chunk("IEND", "")
        assert_includes(refused(bytes).message, "FOOX")
    end

    def test_invalid_colour_type_bit_depth
        bytes = Tessella::Png::SIGNATURE +
                chunk("IHDR", ihdr(colour: 2, depth: 4)) +
                chunk("IDAT", minimal_idat(2, 8, 2, 2)) + chunk("IEND", "")
        assert_includes(refused(bytes).message, "2/4")
    end

    def test_missing_plte
        bytes = Tessella::Png::SIGNATURE +
                chunk("IHDR", ihdr(colour: 3, depth: 8)) +
                chunk("IDAT", minimal_idat(3, 8, 2, 2)) + chunk("IEND", "")
        assert_includes(refused(bytes).message, "PLTE")
    end

    def test_missing_idat
        bytes = Tessella::Png::SIGNATURE + chunk("IHDR", ihdr) +
                chunk("IEND", "")
        assert_includes(refused(bytes).message, "IDAT")
    end

    def test_missing_ihdr
        bytes = Tessella::Png::SIGNATURE + chunk("IDAT", "") +
                chunk("IEND", "")
        assert_includes(refused(bytes).message, "IHDR")
    end

    def test_bad_filter_type
        raw = "\x07#{"\x00" * 6}"
        bytes = Tessella::Png::SIGNATURE + chunk("IHDR", ihdr) +
                chunk("IDAT", Zlib::Deflate.deflate(raw)) + chunk("IEND", "")
        assert_includes(refused(bytes).message, "filter")
    end

    def test_zlib_error
        bytes = Tessella::Png::SIGNATURE + chunk("IHDR", ihdr) +
                chunk("IDAT", "not zlib data") + chunk("IEND", "")
        assert_includes(refused(bytes).message, "zlib")
    end
end
