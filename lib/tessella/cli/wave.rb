# frozen_string_literal: true

module Tessella
    # `tessella wave` (DESIGN.md, "Command line"): draws one timing
    # diagram from a file or stdin, ported from the ascii-art skill's
    # scripts/wave.rb (minus its --no-lint: the lint pass stays in the
    # skill). Exit 0 drawn, 1 bad input (a bad signal line, an unknown
    # wave character, missing or leftover labels, a label too wide,
    # output past --max-width), 2 usage (a bad option, too many file
    # arguments, a file that cannot be opened).
    class WaveCLI
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

        BANNER = "Usage: tessella wave [options] [file]  " \
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
            block = build(opts, CLI.read_text(path, stdin, DataError))
            Overflow.check!(block, opts[:max_width]) if opts[:max_width]
            stdout.print(block.to_s)
            0
        end

        def self.build(opts, text)
            Tessella.wave(text, period: opts[:period], ascii: opts[:ascii],
                                ruler: opts[:ruler])
        rescue ArgumentError => e
            raise DataError, e.message
        end

        def self.halt(error, stdout, stderr)
            (error.status.zero? ? stdout : stderr).print(error.text)
            error.status
        end

        def self.fail_with(stderr, message, status)
            stderr.puts("tessella wave: #{message}")
            status
        end
    end

    # Parses argv into opts (:period, :ascii, :max_width, :ruler) plus
    # the one file argument, or nil for stdin. Raises Halt for --help,
    # or lets OptionParser::ParseError escape for a bad flag, missing
    # argument, or disallowed value.
    class WaveCLI
        class Options
            def self.parse(argv)
                new.parse(argv)
            end

            def initialize
                @opts = { period: 4, ascii: Target.ascii?, ruler: false }
                @parser = OptionParser.new
                @parser.banner = WaveCLI::BANNER
                build
            end

            def parse(argv)
                @parser.parse!(argv)
                raise WaveCLI::UsageError, "too many arguments" if argv.size > 1

                [@opts, argv.first]
            end

            private

            def build
                add_period
                add_ascii
                add_max_width
                add_ruler
                add_help
            end

            def add_period
                @parser.on("--period N", Integer,
                           "columns per time step (default 4)") do |n|
                    raise WaveCLI::UsageError, "--period must be >= 2" if
                        n < 2
                    @opts[:period] = n
                end
            end

            def add_ascii
                @parser.on("--[no-]ascii", "pure ASCII output") do |v|
                    @opts[:ascii] = v
                end
            end

            def add_max_width
                @parser.on("--max-width N", Integer,
                           "error if output exceeds N columns") do |n|
                    @opts[:max_width] = n
                end
            end

            def add_ruler
                @parser.on("--ruler", "add a time-step index row") do
                    @opts[:ruler] = true
                end
            end

            def add_help
                @parser.on("--help", "print this help") do
                    raise WaveCLI::Halt.new(0, @parser.to_s)
                end
            end
        end
    end

    # --max-width, after the diagram is drawn: the first line over it
    # refuses the whole figure, naming the line and its width, exactly
    # as wave.rb's own check does.
    class WaveCLI
        module Overflow
            def self.check!(block, max)
                block.lines.each_with_index do |line, i|
                    w = Width.of(line.rstrip)
                    next if w <= max

                    raise WaveCLI::DataError,
                          "line #{i + 1}: #{w} columns exceeds " \
                          "--max-width #{max}"
                end
            end
        end
    end
end
