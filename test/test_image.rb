# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Tessella.image (DESIGN.md, "Images"): a picture as text, ported
# from the ascii-art skill's scripts/img2art.rb -- every style and
# dither mode, invert, gamma, threshold, a custom ramp, edges, and
# ASCII, on small hand-made PGM/PPM rasters, plus a case per refusal.
class TestImage < Minitest::Test
    GRADIENT = "P2\n4 4\n255\n0 85 170 255\n85 170 255 170\n" \
               "170 255 170 85\n255 170 85 0\n"

    def checker_pgm(w, h, bright: 240, dark: 10)
        vals = (0...h).flat_map do |y|
            (0...w).map { |x| (x + y).even? ? bright : dark }
        end
        "P5\n#{w} #{h}\n255\n#{vals.pack("C*")}"
    end

    def test_ramp_is_the_default_style
        blk = Tessella.image(GRADIENT, width: 4)
        assert_equal(":+##\n##+:\n", blk.to_s)
    end

    def test_blocks_style_uses_the_shade_ladder
        blk = Tessella.image(GRADIENT, width: 4, style: :blocks)
        assert_equal("░▒▓▓\n▓▓▒░\n", blk.to_s)
    end

    def test_half_style_draws_two_pixels_per_cell
        blk = Tessella.image(checker_pgm(8, 8), width: 8, style: :half)
        assert_equal("▀▄▀▄▀▄▀▄\n" * 4, blk.to_s)
    end

    def test_quadrant_style_draws_four_pixels_per_cell
        blk = Tessella.image(checker_pgm(8, 8), width: 8, style: :quadrant)
        assert_equal("▀▄▀▄▀▄▀▄\n" * 4, blk.to_s)
    end

    def test_sextant_style_draws_six_pixels_per_cell
        blk = Tessella.image(checker_pgm(8, 8), width: 8, style: :sextant)
        assert_equal("🬎🬭🬎🬭🬎🬭🬎🬭\n" * 4, blk.to_s)
    end

    def test_braille_style_draws_eight_pixels_per_cell
        blk = Tessella.image(checker_pgm(8, 8), width: 8, style: :braille)
        assert_equal("⠛⣤⠛⣤⠛⣤⠛⣤\n" * 4, blk.to_s)
    end

    def test_a_blank_braille_cell_is_a_space_never_u2800
        vals = [0] * 32
        vals[0] = 255
        pgm = "P5\n4 8\n255\n#{vals.pack("C*")}"
        blk = Tessella.image(pgm, width: 2, style: :braille)
        refute_includes(blk.to_s, "⠀")
        assert_equal(1, blk.lines.size, "the blank trailing row is dropped")
    end

    def test_a_leading_blank_braille_cell_stays_a_literal_space
        vals = (0...4).flat_map { |_y| (0...8).map { |x| x < 2 ? 0 : 255 } }
        pgm = "P5\n8 4\n255\n#{vals.pack("C*")}"
        blk = Tessella.image(pgm, width: 4, style: :braille)
        assert_equal(" ⣿⣿⣿\n", blk.to_s)
    end

    def test_returns_a_tessella_block
        assert_kind_of(Tessella::Block, Tessella.image(GRADIENT, width: 4))
    end
end

# Tessella.image's numeric and source options, split out from
# TestImage to keep each class under the house size limit.
class TestImageOptions < Minitest::Test
    GRADIENT = TestImage::GRADIENT

    def gradient_row_pgm(w, h)
        vals = (0...h).flat_map { |_| (0...w).map { |x| x * 255 / (w - 1) } }
        "P5\n#{w} #{h}\n255\n#{vals.pack("C*")}"
    end

    def test_dither_none_is_a_flat_threshold
        blk = Tessella.image(gradient_row_pgm(16, 4), width: 8, style: :half,
                                                      dither: :none)
        assert_equal("    ████\n", blk.to_s)
    end

    def test_dither_fs_diffuses_the_error
        blk = Tessella.image(gradient_row_pgm(16, 4), width: 8, style: :half,
                                                      dither: :fs)
        assert_equal("   █ ███\n", blk.to_s)
    end

    def test_dither_atkinson_diffuses_the_error
        blk = Tessella.image(gradient_row_pgm(16, 4), width: 8, style: :half,
                                                      dither: :atkinson)
        assert_equal("   ▄█▀██\n", blk.to_s)
    end

    def test_dither_bayer_is_an_ordered_matrix
        blk = Tessella.image(gradient_row_pgm(16, 4), width: 8, style: :half,
                                                      dither: :bayer)
        assert_equal("▀ ▀▄▀█▀█\n", blk.to_s)
    end

    def test_invert_flips_the_polarity
        blk = Tessella.image(GRADIENT, width: 4, invert: true)
        assert_equal("%+::\n::+%\n", blk.to_s)
    end

    def test_gamma_bends_the_tone_curve
        blk = Tessella.image(GRADIENT, width: 4, gamma: 2.0)
        assert_equal(" :**\n**:\n", blk.to_s)
    end

    def test_threshold_moves_the_binary_cut
        blk = Tessella.image(gradient_row_pgm(16, 4), width: 8, style: :half,
                                                      threshold: 0.9)
        assert_equal("   ▄▄▀▄█\n", blk.to_s)
    end

    def test_a_custom_ramp_replaces_the_default_one
        blk = Tessella.image(GRADIENT, width: 4, ramp: " #")
        assert_equal(" ###\n###\n", blk.to_s)
    end

    def test_edges_style_draws_a_vertical_boundary
        vals = (0...4).flat_map { |_| (0...8).map { |x| x < 4 ? 0 : 255 } }
        pgm = "P5\n8 4\n255\n#{vals.pack("C*")}"
        blk = Tessella.image(pgm, width: 8, style: :edges)
        assert_equal("   ││\n" * 2, blk.to_s)
    end

    def test_ascii_true_with_the_default_ramp_style_is_ascii_only
        blk = Tessella.image(GRADIENT, width: 4, ascii: true)
        assert_equal(":+##\n##+:\n", blk.to_s)
        assert(blk.to_s.ascii_only?)
    end

    def test_a_raster_already_decoded_is_accepted_directly
        raster = Tessella::Raster.decode(GRADIENT)
        assert_equal(Tessella.image(GRADIENT, width: 4).to_s,
                     Tessella.image(raster, width: 4).to_s)
    end

    def test_an_io_source_is_read_as_image_bytes
        blk = Tessella.image(StringIO.new(GRADIENT), width: 4)
        assert_equal(":+##\n##+:\n", blk.to_s)
    end

    def test_a_p3_color_source_converts_to_luma
        ppm = "P3\n2 2\n255\n255 255 255  0 0 0\n0 0 0  255 255 255\n"
        blk = Tessella.image(ppm, width: 2, style: :ramp)
        assert_kind_of(Tessella::Block, blk)
    end
end

# Tessella.image's refusals (DESIGN.md): every bad-input case raises
# ArgumentError naming what it refused.
class TestImageRefusals < Minitest::Test
    GRADIENT = TestImage::GRADIENT

    def test_an_unknown_style_names_it
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, style: :bogus)
        end
        assert_equal("unknown style: :bogus", error.message)
    end

    def test_an_unknown_dither_names_it
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, dither: :bogus)
        end
        assert_equal("unknown dither: :bogus", error.message)
    end

    def test_a_width_below_one_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, width: 0)
        end
        assert_equal("width must be a positive Integer: 0", error.message)
    end

    def test_a_non_ramp_style_under_ascii_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, style: :half, ascii: true)
        end
        assert_equal("ascii: true allows only style: :ramp, not :half",
                     error.message)
    end

    def test_a_non_ascii_ramp_under_ascii_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, ramp: "·#", ascii: true)
        end
        assert_match(/needs an ASCII ramp/, error.message)
    end

    def test_an_empty_ramp_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, ramp: "")
        end
        assert_equal("ramp must not be empty", error.message)
    end

    def test_a_non_positive_gamma_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, gamma: -1)
        end
        assert_equal("gamma must be positive: -1", error.message)
    end

    def test_a_nan_gamma_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, gamma: Float::NAN)
        end
        assert_equal("gamma must be a finite number: NaN", error.message)
    end

    def test_an_infinite_threshold_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, threshold: Float::INFINITY)
        end
        assert_equal("threshold must be a finite number: Infinity",
                     error.message)
    end

    def test_a_nan_edge_threshold_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image(GRADIENT, edge_threshold: Float::NAN)
        end
        assert_equal("edge_threshold must be a finite number: NaN",
                     error.message)
    end

    def test_a_source_that_is_none_of_raster_io_or_string_is_refused
        error = assert_raises(ArgumentError) { Tessella.image(42) }
        assert_match(/source must be a Raster, IO, or String/,
                     error.message)
    end

    def test_a_malformed_pnm_header_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image("P5\nnotanumber\n")
        end
        assert_match(/not a PGM.PPM/, error.message)
    end

    def test_a_raster_shorter_than_its_header_is_refused
        error = assert_raises(ArgumentError) do
            Tessella.image("P5\n4 4\n255\n\x01\x02")
        end
        assert_match(/raster too short/, error.message)
    end

    def test_a_render_with_no_cell_on_at_all_is_refused_as_blank
        blank = "P2\n2 2\n255\n0 0\n0 0\n"
        error = assert_raises(Tessella::Image::Blank) { Tessella.image(blank) }
        assert_includes(error.message, "renders blank at style ramp")
    end
end

# `tessella image` (DESIGN.md, "Command line"): options, exit status
# and the prefixed error messages. A bad file or a malformed image is
# bad input (1); an unknown flag, or an option value Tessella.image
# itself refuses once the image has decoded, is usage (2).
class TestImageCLI < Minitest::Test
    GRADIENT = TestImage::GRADIENT

    def run_cli(*argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::ImageCLI.run(argv, stdin: StringIO.new(stdin),
                                              stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def test_draws_from_stdin
        status, out, = run_cli("--width", "4", stdin: GRADIENT)
        assert_equal(0, status)
        assert_equal(":+##\n##+:\n", out)
    end

    def test_draws_from_a_file
        Dir.mktmpdir do |dir|
            path = File.join(dir, "img.pgm")
            File.binwrite(path, GRADIENT)
            status, out, = run_cli("--width", "4", path)
            assert_equal([0, ":+##\n##+:\n"], [status, out])
        end
    end

    def test_style_and_dither_and_ramp_flags_reach_the_renderer
        status, out, = run_cli("--width", "4", "--style", "blocks",
                               stdin: GRADIENT)
        assert_equal(0, status)
        assert_equal("░▒▓▓\n▓▓▒░\n", out)
    end

    def test_ascii_flag_through_the_cli
        status, out, = run_cli("--width", "4", "--ascii", stdin: GRADIENT)
        assert_equal(0, status)
        assert_equal(":+##\n##+:\n", out)
    end

    def test_an_unknown_flag_is_a_usage_error
        status, _, err = run_cli("--bogus", stdin: GRADIENT)
        assert_equal(2, status)
        assert_includes(err, "tessella image: ")
    end

    def test_an_unknown_style_value_is_a_usage_error
        status, _, err = run_cli("--style", "bogus", stdin: GRADIENT)
        assert_equal(2, status)
        assert_includes(err, "tessella image: ")
    end

    def test_an_ascii_style_conflict_is_a_usage_error
        status, _, err = run_cli("--style", "half", "--ascii",
                                 stdin: GRADIENT)
        assert_equal(2, status)
        assert_includes(err, "allows only style: :ramp")
    end

    def test_a_width_below_one_is_a_usage_error
        status, _, err = run_cli("--width", "0", stdin: GRADIENT)
        assert_equal(2, status)
        assert_includes(err, "width must be a positive Integer")
    end

    def test_a_malformed_image_is_bad_input
        status, _, err = run_cli(stdin: "P5\nnotanumber\n")
        assert_equal(1, status)
        assert_includes(err, "tessella image: ")
    end

    def test_a_missing_file_is_bad_input
        status, _, err = run_cli("/no/such/image/file")
        assert_equal(1, status)
        assert_includes(err, "tessella image: ")
    end

    def test_max_width_passes_under_the_limit
        status, _, err = run_cli("--width", "4", "--max-width", "10",
                                 stdin: GRADIENT)
        assert_equal(0, status, err)
    end

    def test_max_width_refuses_over_the_limit_naming_the_width
        status, _, err = run_cli("--width", "4", "--max-width", "1",
                                 stdin: GRADIENT)
        assert_equal(1, status)
        assert_includes(err, "exceeds --max-width 1")
    end

    def test_too_many_arguments_is_a_usage_error
        status, = run_cli("a", "b", stdin: "")
        assert_equal(2, status)
    end

    def test_help_prints_usage_and_exits_zero
        status, out, = run_cli("--help")
        assert_equal(0, status)
        assert_includes(out, "Usage: tessella image")
    end

    def test_the_command_is_registered_on_the_main_cli
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["image", "--width", "4"],
                                   stdin: StringIO.new(GRADIENT),
                                   stdout: out, stderr: err)
        assert_equal(0, status)
        assert_equal(":+##\n##+:\n", out.string)
    end
end

# A picture that renders blank is refused, naming what to change, and
# is bad input (exit 1) on the command line, not a usage error.
class TestImageBlank < Minitest::Test
    FLAT = "P2 4 4 255\n#{"128 " * 16}\n".freeze

    def test_a_blank_render_is_refused_naming_the_knob
        error = assert_raises(Tessella::Image::Blank) do
            Tessella.image(FLAT, style: :edges, width: 8)
        end
        assert_includes(error.message, "edge_threshold")
    end

    def test_a_blank_render_exits_one
        err = StringIO.new
        status = Tessella::CLI.run(%w[image --style edges --width 8],
                                   stdin: StringIO.new(FLAT),
                                   stdout: StringIO.new, stderr: err)
        assert_equal(1, status, err.string)
    end
end
