# frozen_string_literal: true

module AsciiArt
    # The ascii-art command (DESIGN.md, "Command line"): `ascii-art
    # COMMAND [options]`, one command per drawing module, each with its
    # own options and --help. The command is the first argument, so a
    # module's options never collide with another's.
    class CLI
        COMMANDS = {
            "chart" => ChartCLI, "compose" => ComposeCLI, "tree" => TreeCLI,
            "table" => TableCLI, "bitfield" => BitfieldCLI, "wave" => WaveCLI,
            "seq" => SeqCLI
        }.freeze

        USAGE = <<~TEXT
            Usage: ascii-art COMMAND [options] [file]

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

            ascii-art COMMAND --help shows a command's options;
            ascii-art --version prints the version.
        TEXT

        def self.run(argv, stdin:, stdout:, stderr:)
            command, *rest = argv
            return meta(command, stdout) if %w[--help -h --version]
                                            .include?(command)

            klass = COMMANDS[command]
            return refuse(command, stderr) unless klass

            klass.run(rest, stdin: stdin, stdout: stdout, stderr: stderr)
        end

        def self.meta(flag, stdout)
            stdout.print(flag == "--version" ? "#{VERSION}\n" : USAGE)
            0
        end

        def self.refuse(command, stderr)
            what = command ? "unknown command: #{command}" : "no command"
            stderr.puts("ascii-art: #{what}")
            stderr.print(USAGE)
            2
        end
    end
end
