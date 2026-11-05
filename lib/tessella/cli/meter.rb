# frozen_string_literal: true

module Tessella
    # `tessella meter` (DESIGN.md, "Meters and rules"): one meter line
    # for FRACTION (0..1, or 45%). Exit 0 drawn; 2 usage (a bad flag,
    # an unknown style, a mixed-class pair, a fraction out of range).
    class MeterCLI
        class UsageError < StandardError; end
        # Raised by --help, carrying its text.
        class Help < StandardError; end

        BANNER = "Usage: tessella meter [options] FRACTION  (0..1, or 45%)\n"

        def self.run(argv, stdout:, stderr:, **)
            stdout.print(draw(argv))
            0
        rescue Help => e
            stdout.print(e.message)
            0
        rescue OptionParser::ParseError, UsageError, ArgumentError => e
            stderr.puts("tessella meter: #{e.message}")
            2
        end

        def self.draw(argv)
            opts, args = parse(argv.dup)
            raise UsageError, "one FRACTION, got #{args.size}" unless
                args.size == 1

            Tessella.meter(args.first, **opts).to_s
        end

        def self.parse(argv)
            opts = {}
            parser = OptionParser.new(BANNER)
            options(parser, opts)
            [opts, parser.parse!(argv)]
        end

        def self.options(parser, opts)
            styles = Glyphs::METERS.keys.each_slice(4)
                                   .map { "#{it.join(", ")}," }
            parser.on("--style S", *styles,
                      "or a fill and a track glyph") { opts[:style] = it }
            parser.on("--width N", Integer, "bar cells (default 20)") do |n|
                opts[:width] = n
            end
            titles(parser, opts)
            flags(parser, opts)
        end

        def self.titles(parser, opts)
            parser.on("--title T", "text before the bar") { opts[:title] = it }
            parser.on("--title-width N", Integer, "pad the title to N " \
                                                  "columns") do |n|
                opts[:title_width] = n
            end
        end

        def self.flags(parser, opts)
            parser.on("--no-label", "no percentage") { opts[:label] = false }
            parser.on("--no-brackets", "no [ ]") { opts[:brackets] = false }
            parser.on("--ascii", "the classic style: [=====     ]") do
                opts[:ascii] = true
            end
            parser.on("--help", "print this help") { raise Help, parser.to_s }
        end
    end
end
