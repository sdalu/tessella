# frozen_string_literal: true

module Tessella
    # `tessella rule` (DESIGN.md, "Meters and rules"): one divider line.
    # Exit 0 drawn; 2 usage (a bad flag, an unknown style, an ornament
    # too wide, a non-ASCII ornament under --ascii, an argument).
    class RuleCLI
        # Raised by --help, carrying its text.
        class Help < StandardError; end

        BANNER = "Usage: tessella rule [options]\n"

        def self.run(argv, stdout:, stderr:, **)
            stdout.print(draw(argv))
            0
        rescue Help => e
            stdout.print(e.message)
            0
        rescue OptionParser::ParseError, ArgumentError => e
            stderr.puts("tessella rule: #{e.message}")
            2
        end

        def self.draw(argv)
            opts, args = parse(argv.dup)
            raise ArgumentError, "no argument expected: #{args.first}" if
                args.any?

            Tessella.rule(**opts).to_s
        end

        def self.parse(argv)
            opts = {}
            parser = OptionParser.new(BANNER)
            options(parser, opts)
            [opts, parser.parse!(argv)]
        end

        def self.options(parser, opts)
            parser.on("--width N", Integer, "columns (default 78)") do |n|
                opts[:width] = n
            end
            parser.on("--ornament T", "text centred in the line") do |t|
                opts[:ornament] = t
            end
            parser.on("--style S", Glyphs::RULES.keys.join(", ")) do |s|
                opts[:style] = s
            end
            flags(parser, opts)
        end

        def self.flags(parser, opts)
            parser.on("--ascii", "a line of -") { opts[:ascii] = true }
            parser.on("--help", "print this help") { raise Help, parser.to_s }
        end
    end
end
