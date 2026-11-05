# frozen_string_literal: true

module Tessella
    # `tessella seq`: reads one file or stdin, draws a sequence
    # diagram via Tessella.seq, and prints it. Exit 0 drawn, 1 bad
    # input (an unrecognised statement, a non-ASCII name under
    # --ascii, no statements or participants, output past
    # --max-width), 2 usage. The artlint pass the skill's seq.rb runs
    # by default stays in the skill; there is no --no-lint here.
    class SeqCLI
        class Error < StandardError; end
        class UsageError < Error; end
        class DataError < Error; end

        # Raised by --help to short-circuit parsing with a message
        # and a status already decided.
        class Halt < StandardError
            attr_reader :status, :text

            def initialize(status, text)
                @status = status
                @text = text
                super(text)
            end
        end

        BANNER = "Usage: tessella seq [options] [file]"

        def self.run(argv, stdin:, stdout:, stderr:)
            draw(argv, stdin, stdout)
        rescue Halt => e
            halt(e, stdout, stderr)
        rescue OptionParser::ParseError, UsageError => e
            usage_error(e, stderr)
        rescue DataError, ArgumentError => e
            data_error(e, stderr)
        end

        def self.draw(argv, stdin, stdout)
            opts, path = Options.parse(argv.dup)
            text = Reader.text(path, stdin)
            block = Tessella.seq(text, ascii: opts[:ascii],
                                       numbered: opts[:numbered],
                                       footer: opts[:footer])
            check_max_width!(block, opts[:max_width])
            stdout.print(block.to_s)
            0
        end

        def self.check_max_width!(block, max_width)
            return unless max_width

            w = block.lines.map { Width.of(it.rstrip) }.max
            return if w <= max_width

            raise DataError,
                  "output is #{w} columns, over --max-width #{max_width}"
        end

        def self.halt(error, stdout, stderr)
            (error.status.zero? ? stdout : stderr).print(error.text)
            error.status
        end

        def self.usage_error(error, stderr)
            stderr.puts("tessella seq: #{error.message}")
            stderr.puts(BANNER)
            2
        end

        def self.data_error(error, stderr)
            stderr.puts("tessella seq: #{error.message}")
            1
        end
    end

    # Parses argv into { ascii:, numbered:, footer:, max_width: } plus
    # at most one file argument; raises Halt for --help, or lets
    # OptionParser::ParseError escape for a bad flag or value.
    class SeqCLI
        class Options
            def self.parse(argv)
                new.parse(argv)
            end

            def initialize
                @opts = { ascii: Target.ascii? }
                @parser = OptionParser.new
                @parser.banner = SeqCLI::BANNER
                build
            end

            def parse(argv)
                @parser.parse!(argv)
                raise SeqCLI::UsageError, "one file argument at most" if
                    argv.size > 1

                [@opts, argv.first]
            end

            private

            def build
                @parser.on("--[no-]ascii") { @opts[:ascii] = it }
                @parser.on("--numbered") { @opts[:numbered] = true }
                @parser.on("--footer") { @opts[:footer] = true }
                add_max_width
                add_help
            end

            def add_max_width
                @parser.on("--max-width N", Integer) { @opts[:max_width] = it }
            end

            def add_help
                @parser.on("-h", "--help") do
                    raise SeqCLI::Halt.new(0, @parser.to_s)
                end
            end
        end
    end

    # Reads the file argument, or stdin when none; a file that cannot
    # be read is bad input (exit 1, as in every tessella command),
    # named by the system error's message.
    class SeqCLI
        module Reader
            def self.text(path, stdin)
                CLI.utf8!(path ? File.read(path) : stdin.read,
                          SeqCLI::DataError)
            rescue SystemCallError => e
                raise SeqCLI::DataError, CLI.cannot_read(path, e)
            end
        end
    end
end
