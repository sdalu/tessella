# frozen_string_literal: true

module Tessella
    # `tessella bitfield` (ported byte for byte from the tessella
    # skill's scripts/bitfield.rb, minus its --no-lint: the lint pass
    # stays in the skill). Exit 0 drawn, 1 bad input (a missing file, a
    # bad line, a name too wide for its cell, output past --max-width),
    # 2 usage.
    class BitfieldCLI
        class UsageError < StandardError; end
        class DataError < StandardError; end

        USAGE = <<~TEXT
            Usage: tessella bitfield [options] [file]  (stdin if none)
                --word N          bits per row: 8, 16, 32 (default), 64
                --octets          byte-oriented: no bit ruler, a tick
                                  per octet
                --no-ruler        drop the two-row bit ruler
                --abbrev          truncate a name too wide for its cell
                --ascii           accepted; this command always draws
                                  ASCII
                --max-width N     error if a line exceeds N columns
        TEXT

        def self.run(argv, stdin:, stdout:, stderr:)
            return help(stdout) if %w[--help -h].include?(argv.first)

            stdout.print(draw(argv.dup, stdin))
            0
        rescue UsageError, OptionParser::ParseError => e
            fail_with(stderr, e.message, 2)
        rescue DataError => e
            fail_with(stderr, e.message, 1)
        end

        def self.help(stdout)
            stdout.print(USAGE)
            0
        end

        # No usage dump after the message (unlike compose's CLI): the
        # parity gate requires bitfield's stderr to match the script's
        # own, byte for byte but for the prefix.
        def self.fail_with(stderr, message, status)
            stderr.puts("tessella bitfield: #{message}")
            status
        end

        def self.draw(argv, stdin)
            opts, paths = BitfieldOptions.parse(argv)
            raise UsageError, "too many arguments" if paths.size > 1

            text = BitfieldReader.read(paths.first, stdin)
            finish(text, opts)
        end

        # Usage is settled by now; what drawing still refuses (a bad
        # line, a name too wide, output past --max-width) is bad input.
        def self.finish(text, opts)
            block = Tessella.bitfield(text, word: opts.fetch(:word, 32),
                                            octets: opts[:octets] || false,
                                            ruler: !opts[:no_ruler],
                                            abbrev: opts[:abbrev] || false)
            check_max_width!(block, opts[:max_width])
            block.to_s
        rescue ArgumentError => e
            raise DataError, e.message
        end

        def self.check_max_width!(block, max_width)
            return unless max_width

            block.lines.each do |line|
                width = Width.of(line)
                next if width <= max_width

                raise DataError, "a line is #{width} columns, over " \
                                 "--max-width #{max_width}"
            end
        end
    end

    # bitfield's options: --word validated immediately (a usage error,
    # as the script's own OptionParser block), the rest stored as-is.
    class BitfieldOptions
        def self.parse(argv)
            new.parse(argv)
        end

        def initialize
            @opts = {}
            @parser = OptionParser.new { |op| add(op) }
        end

        def parse(argv)
            @parser.parse!(argv)
            [@opts, argv]
        end

        private

        def add(op)
            add_word(op)
            op.on("--octets") { @opts[:octets] = true }
            op.on("--no-ruler") { @opts[:no_ruler] = true }
            op.on("--abbrev") { @opts[:abbrev] = true }
            op.on("--ascii") { @opts[:ascii] = true }
            op.on("--max-width N", Integer) { |n| @opts[:max_width] = n }
        end

        def add_word(op)
            op.on("--word N", Integer) do |n|
                unless Bitfield::WORD_SIZES.include?(n)
                    raise BitfieldCLI::UsageError,
                          "--word must be 8, 16, 32 or 64"
                end
                @opts[:word] = n
            end
        end
    end

    # The script's own input: one file argument, or stdin.
    module BitfieldReader
        def self.read(path, stdin)
            path ? File.read(path) : stdin.read
        rescue SystemCallError => e
            raise BitfieldCLI::DataError, e.message
        end
    end
end
