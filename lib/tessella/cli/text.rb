# frozen_string_literal: true

module Tessella
    # `tessella text` (DESIGN.md, "Text styles"): TEXT (the words given,
    # or stdin when none) in a style. A letter or digit with no form in
    # it passes through, named on stderr; --strict makes that exit 1.
    # --plain turns any style back to plain text. Exit 0; 1 under
    # --strict when a character has no form; 2 usage (no --style, an
    # unknown style, --ascii).
    class TextCLI
        class UsageError < StandardError; end
        class DataError < StandardError; end
        # Raised by --help, carrying its text.
        class Help < StandardError; end

        BANNER = "Usage: tessella text --style S [--strict] [TEXT ...]  " \
                 "(stdin if none)\n       tessella text --plain [TEXT ...]\n"

        def self.run(argv, stdin:, stdout:, stderr:)
            opts, words = parse(argv.dup)
            convert(input(words, stdin), opts, stdout, stderr)
        rescue Help => e
            stdout.print(e.message)
            0
        rescue DataError, OptionParser::ParseError, UsageError,
               ArgumentError => e
            stderr.puts("tessella text: #{e.message}")
            e.is_a?(DataError) ? 1 : 2
        end

        # The words given, or stdin; UTF-8 either way.
        def self.input(words, stdin)
            text = words.empty? ? stdin.read : "#{words.join(" ")}\n"
            CLI.utf8!(text, DataError)
        end

        def self.convert(text, opts, stdout, stderr)
            style = opts[:style] or raise UsageError, "--style S or --plain"
            raise UsageError, "text styles are not ASCII" if opts[:ascii]

            missing = Text.unmapped(text, style)
            stdout.print(Tessella.text(text, style: style)) unless
                opts[:strict] && missing.any?
            return 0 if missing.empty?

            name = Text.dashed(Borders.name(style))
            stderr.puts("tessella text: no #{name} form for: " \
                        "#{missing.join(" ")}")
            opts[:strict] ? 1 : 0
        end

        def self.parse(argv)
            opts = {}
            parser = OptionParser.new(BANNER)
            options(parser, opts)
            [opts, parser.parse!(argv)]
        end

        def self.options(parser, opts)
            names = (Text::STYLES - [:plain]).map { Text.dashed(it) }
            lines = names.each_slice(3).map { "#{it.join(", ")}," }
            parser.on("--style S", *lines) { opts[:style] = it }
            parser.on("--plain", "any style back to plain") do
                opts[:style] = "plain"
            end
            flags(parser, opts)
        end

        def self.flags(parser, opts)
            parser.on("--strict", "exit 1 when a letter or digit has no " \
                                  "form") { opts[:strict] = true }
            parser.on("--ascii", "refused: every style is non-ASCII") do
                opts[:ascii] = true
            end
            parser.on("--help", "print this help") { raise Help, parser.to_s }
        end
    end
end
