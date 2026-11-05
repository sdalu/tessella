# frozen_string_literal: true

module Tessella
    # `tessella sparkline` (DESIGN.md, "Meters and rules"): one line
    # from the VALUES given, or read from stdin (split on blanks and
    # commas). Exit 0 drawn; 1 bad input (no value, a non-number); 2
    # usage.
    class SparklineCLI
        class DataError < StandardError; end
        # Raised by --help, carrying its text.
        class Help < StandardError; end

        BANNER = "Usage: tessella sparkline [options] [VALUE ...]  " \
                 "(stdin if none)\n"

        def self.run(argv, stdin:, stdout:, stderr:)
            stdout.print(draw(argv, stdin))
            0
        rescue Help => e
            stdout.print(e.message)
            0
        rescue DataError => e
            fail_with(stderr, e.message, 1)
        rescue OptionParser::ParseError, ArgumentError => e
            fail_with(stderr, e.message, 2)
        end

        def self.draw(argv, stdin)
            opts, words = parse(argv.dup)
            source = words.empty? ? stdin.read : words.join(" ")
            Tessella.sparkline(numbers(source), **opts).to_s
        end

        def self.fail_with(stderr, message, status)
            stderr.puts("tessella sparkline: #{message}")
            status
        end

        def self.numbers(text)
            fields = text.split(/[\s,]+/).reject(&:empty?)
            raise DataError, "no value" if fields.empty?

            fields.map do |f|
                Float(f, exception: false) or
                    raise DataError, "not a number: #{f.inspect}"
            end
        end

        def self.parse(argv)
            opts = {}
            parser = OptionParser.new(BANNER)
            options(parser, opts)
            [opts, parser.parse!(argv)]
        end

        def self.options(parser, opts)
            parser.on("--width N", Integer, "cells (one a value)") do |n|
                opts[:width] = n
            end
            parser.on("--min A", Float, "range bottom") { opts[:min] = it }
            parser.on("--max B", Float, "range top") { opts[:max] = it }
            parser.on("--[no-]ascii", "eight ASCII levels: _.-:=+*#") do |v|
                opts[:ascii] = v
            end
            parser.on("--help", "print this help") { raise Help, parser.to_s }
        end
    end
end
