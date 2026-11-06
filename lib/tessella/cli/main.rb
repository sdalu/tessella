# frozen_string_literal: true

module Tessella
    # The tessella command (DESIGN.md, "Command line"): `tessella
    # COMMAND [options]`, one command per drawing module, each with its
    # own options and --help. The command is the first argument, so a
    # module's options never collide with another's.
    class CLI
        COMMANDS = {
            "chart" => ChartCLI, "compose" => ComposeCLI, "tree" => TreeCLI,
            "table" => TableCLI, "bitfield" => BitfieldCLI, "wave" => WaveCLI,
            "seq" => SeqCLI, "image" => ImageCLI, "lint" => LintCLI,
            "glyphs" => GlyphsCLI, "meter" => MeterCLI, "rule" => RuleCLI,
            "text" => TextCLI, "sparkline" => SparklineCLI
        }.freeze

        USAGE = <<~TEXT
            Usage: tessella [--target T] COMMAND [options] [file]

            Commands:
              chart     line, scatter, stairs, density, bar, histogram,
                        box and stem charts
              compose   frame, beside, stack, indent, caption: assemble
                        blocks into one figure
              tree      an indented outline as a box-drawing tree
              table     CSV or TSV rows as a framed table
              bitfield  an RFC-style packet / bit-field diagram
              wave      a timing diagram from WaveDrom-like signals
              seq       a sequence diagram from "A -> B: msg" lines
              image     a picture as text: tones, blocks, braille, edges
              lint      check text figures: tabs, widths, invisible
                        glyphs, mixed or misaligned structure
              glyphs    the named glyph sets and their width classes
              meter     a one-line progress bar or gauge
              rule      a divider line, with an optional ornament
              text      text in a Unicode style: bold, script, small
                        caps, circled, fullwidth, ...
              sparkline one line of values, ▁ to █

            --target term|cjk|web (or TESSELLA_TARGET) names where the
            figure is read: term (default); cjk, a CJK terminal, whose
            ambiguous glyphs (box drawing, blocks) are two columns, so
            structure is ASCII; web, a browser, where emoji-capable
            glyphs are kept as text with U+FE0E.

            tessella COMMAND --help shows a command's options;
            tessella --version prints the version.
        TEXT

        # A --target or TESSELLA_TARGET that names no target: usage.
        class TargetError < ArgumentError; end

        META = %w[--help -h --version].freeze

        def self.run(argv, stdin:, stdout:, stderr:, env: ENV)
            target, argv = target(argv, env)
            command, *rest = argv
            return meta(command, stdout) if META.include?(command)

            klass = COMMANDS[command] or return refuse(command, stderr)
            Target.with(target) do
                klass.run(rest, stdin: stdin, stdout: stdout, stderr: stderr)
            end
        rescue TargetError => e
            usage_error(e, stderr)
        end

        def self.usage_error(error, stderr)
            stderr.puts("tessella: #{error.message}")
            2
        end

        # A leading --target T (or --target=T), else TESSELLA_TARGET
        # (set and not empty), else term -- checked before anything
        # runs, --help and --version included; and the arguments after.
        def self.target(argv, env)
            name, rest = given_target(argv)
            name ||= env["TESSELLA_TARGET"].to_s
            [check_target!(name.empty? ? "term" : name), rest]
        end

        def self.given_target(argv)
            first, *rest = argv
            if first == "--target"
                raise TargetError, "--target needs term, cjk or web" if
                    rest.empty?

                return [rest.first, rest.drop(1)]
            end
            return [first.delete_prefix("--target="), rest] if
                first&.start_with?("--target=")

            [nil, argv]
        end

        def self.check_target!(name)
            Target.check!(name)
        rescue ArgumentError => e
            raise TargetError, e.message
        end

        def self.meta(flag, stdout)
            stdout.print(flag == "--version" ? "#{VERSION}\n" : USAGE)
            0
        end

        def self.refuse(command, stderr)
            what = command ? "unknown command: #{command}" : "no command"
            stderr.puts("tessella: #{what}")
            stderr.print(USAGE)
            2
        end
    end
end
