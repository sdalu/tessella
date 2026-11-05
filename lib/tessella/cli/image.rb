# frozen_string_literal: true

module Tessella
    # `tessella image` (DESIGN.md): draws a picture as text -- tones,
    # blocks, half/quadrant/sextant/braille pixels, or edges -- from a
    # file or stdin, ported from the ascii-art skill's
    # scripts/img2art.rb. Its --pad is dropped: composition pads a
    # block itself. Exit 0 drawn; 1 bad input (an unreadable file, a
    # malformed or unsupported image, output past --max-width); 2
    # usage (a bad flag, an unknown --style/--dither, or any other bad
    # option value -- an ArgumentError Tessella.image raises once the
    # image itself has decoded cleanly).
    class ImageCLI
        class UsageError < StandardError; end
        class DataError < StandardError; end

        # Raised by --help to short-circuit parsing with the text and
        # status already decided.
        class Halt < StandardError
            attr_reader :status, :text

            def initialize(status, text)
                @status = status
                @text = text
                super(text)
            end
        end

        BANNER = "Usage: tessella image [options] [file]  " \
                 "(stdin if no file)\n"

        def self.run(argv, stdin:, stdout:, stderr:)
            draw(argv, stdin, stdout)
        rescue Halt => e
            halt(e, stdout, stderr)
        rescue OptionParser::ParseError, UsageError => e
            fail_with(stderr, e.message, 2)
        rescue DataError => e
            fail_with(stderr, e.message, 1)
        end

        def self.draw(argv, stdin, stdout)
            opts, path = Options.parse(argv.dup)
            raster = decode(Reader.bytes(path, stdin))
            block = render(raster, opts)
            Overflow.check!(block, opts[:max_width]) if opts[:max_width]
            stdout.print(block.to_s)
            0
        end

        # A bad file is bad input, before any option is judged: the
        # image itself never decoded, so there is nothing to draw.
        def self.decode(bytes)
            Raster.decode(bytes)
        rescue ArgumentError => e
            raise DataError, e.message
        end

        # Past this point the source is a Raster, so Tessella.image
        # can only still refuse an option's own value -- usage, not
        # bad input.
        def self.render(raster, opts)
            Tessella.image(raster, **opts.except(:max_width))
        rescue Image::Blank => e
            raise DataError, e.message
        rescue ArgumentError => e
            raise UsageError, e.message
        end

        def self.halt(error, stdout, stderr)
            (error.status.zero? ? stdout : stderr).print(error.text)
            error.status
        end

        def self.fail_with(stderr, message, status)
            stderr.puts("tessella image: #{message}")
            status
        end
    end

    # `tessella image`'s numeric options, kept apart so Options stays
    # under budget.
    class ImageCLI
        module NumericOptions
            private

            def add_width
                @parser.on("--width N", Integer, "columns (default 78)") do |n|
                    @opts[:width] = n
                end
            end

            def add_gamma
                @parser.on("--gamma F", Float,
                           "tone curve (default 1.0)") do |f|
                    @opts[:gamma] = f
                end
            end

            def add_threshold
                @parser.on("--threshold F", Float,
                           "on/off cut, 0..1 (default 0.5)") do |f|
                    @opts[:threshold] = f
                end
            end

            def add_edge_threshold
                @parser.on("--edge-threshold F", Float,
                           "edge strength to draw (default 0.3)") do |f|
                    @opts[:edge_threshold] = f
                end
            end
        end
    end

    # Parses argv into Tessella.image's options plus :max_width and
    # the one file argument, or nil for stdin. Raises Halt for
    # --help, or lets OptionParser::ParseError escape for a bad flag,
    # missing argument, or disallowed --style/--dither value.
    class ImageCLI
        class Options
            include NumericOptions

            STYLES = %w[ramp blocks half quadrant sextant braille edges]
                     .freeze
            DITHERS = %w[none fs atkinson bayer].freeze

            def self.parse(argv)
                new.parse(argv)
            end

            def initialize
                @opts = { style: :ramp, width: 78, ramp: nil, gamma: 1.0,
                          threshold: 0.5, dither: :fs, invert: false,
                          edge_threshold: 0.3, ascii: false }
                @parser = OptionParser.new
                @parser.banner = ImageCLI::BANNER
                build
            end

            def parse(argv)
                @parser.parse!(argv)
                raise ImageCLI::UsageError, "too many arguments" if
                    argv.size > 1

                [@opts, argv.first]
            end

            private

            def build
                add_style
                add_dither
                add_numeric_opts
                add_ramp
                add_flags
            end

            def add_numeric_opts
                add_width
                add_gamma
                add_threshold
                add_edge_threshold
            end

            def add_flags
                add_invert
                add_ascii
                add_max_width
                add_help
            end

            def add_style
                @parser.on("--style S", STYLES,
                           "ramp, blocks, half, quadrant,",
                           "sextant, braille or edges") do |s|
                    @opts[:style] = s.to_sym
                end
            end

            def add_dither
                @parser.on("--dither M", DITHERS, "none, fs (Floyd-Steinberg),",
                           "atkinson or bayer") do |m|
                    @opts[:dither] = m.to_sym
                end
            end

            def add_ramp
                @parser.on("--ramp STR", "tone glyphs, light to dense") do |r|
                    @opts[:ramp] = r
                end
            end

            def add_invert
                @parser.on("--invert", "for a light background") do
                    @opts[:invert] = true
                end
            end

            def add_ascii
                @parser.on("--ascii", "ASCII only (ramp style, ASCII ramp)") do
                    @opts[:ascii] = true
                end
            end

            def add_max_width
                @parser.on("--max-width N", Integer,
                           "refuse lines wider than N") do |n|
                    @opts[:max_width] = n
                end
            end

            def add_help
                @parser.on("--help", "print this help") do
                    raise ImageCLI::Halt.new(0, @parser.to_s)
                end
            end
        end
    end

    # The file argument, or stdin when there is none, read as binary
    # bytes. Errors opening it (a missing file, a directory) are bad
    # input, named by the system error's message.
    class ImageCLI
        module Reader
            def self.bytes(path, stdin)
                path ? File.binread(path) : stdin.binmode.read
            rescue SystemCallError => e
                raise ImageCLI::DataError, CLI.cannot_read(path, e)
            end
        end
    end

    # --max-width, after the image is drawn: the first line over it
    # refuses the whole figure, naming the line and its width.
    class ImageCLI
        module Overflow
            def self.check!(block, max)
                block.lines.each_with_index do |line, i|
                    w = Width.of(line.rstrip)
                    next if w <= max

                    raise ImageCLI::DataError,
                          "line #{i + 1}: #{w} columns exceeds " \
                          "--max-width #{max}"
                end
            end
        end
    end
end
