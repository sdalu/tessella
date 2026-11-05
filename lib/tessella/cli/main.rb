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
            "glyphs" => GlyphsCLI, "meter" => MeterCLI, "rule" => RuleCLI
        }.freeze

        USAGE = <<~TEXT
            Usage: tessella COMMAND [options] [file]

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

            tessella COMMAND --help shows a command's options;
            tessella --version prints the version.
        TEXT

        def self.run(argv, stdin:, stdout:, stderr:)
            command, *rest = argv
            return meta(command, stdout) if %w[--help -h --version]
                                            .include?(command)

            klass = COMMANDS[command]
            return refuse(command, stderr) unless klass

            klass.run(rest, stdin: stdin, stdout: stdout, stderr: stderr)
        end

        # "cannot read PATH: reason" for a file a command cannot open,
        # the reason in the system's own words (ENOENT's "No such file
        # or directory"), not Ruby's "... @ rb_sysopen - PATH".
        def self.cannot_read(path, error)
            "cannot read #{path || "stdin"}: #{error.class.new(nil).message}"
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
