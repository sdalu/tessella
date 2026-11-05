# frozen_string_literal: true

module Tessella
    # `tessella compose` (DESIGN.md, "Command line"): one composition
    # per subcommand over blocks read from files ("-" for stdin, once).
    # Exit 0 drawn, 1 bad input (a missing file, an empty block, a tab,
    # non-ASCII under --ascii, output past --max-width), 2 usage.
    class ComposeCLI
        class UsageError < StandardError; end
        class DataError < StandardError; end

        USAGE = <<~TEXT
            Usage: tessella compose frame  [--title T] [--style S] [--pad N] BLOCK
                   tessella compose beside [--gap N] [--align A] BLOCK...
                   tessella compose stack  [--gap N] [--rule C] [--center] BLOCK...
                   tessella compose indent --prefix STR BLOCK
                   tessella compose caption --text T [--above] BLOCK
            Every subcommand also takes --ascii and --max-width N.
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

        def self.fail_with(stderr, message, status)
            stderr.puts("tessella compose: #{message}")
            stderr.print(USAGE) if status == 2
            status
        end

        def self.draw(argv, stdin)
            sub = argv.shift or raise UsageError, "missing subcommand"
            command = ComposeCommands.fetch(sub)
            opts, paths = ComposeOptions.parse(sub, argv)
            ComposeCommands.check_arity!(sub, paths)
            blocks = ComposeReader.blocks(paths, opts, stdin)
            finish(command, blocks, opts)
        end

        # Usage is settled by now; what the composition still refuses
        # (a non-ASCII title, output past --max-width) is bad input.
        def self.finish(command, blocks, opts)
            figure = command.call(blocks, opts)
            figure.check_width!(opts[:max_width]) if opts[:max_width]
            figure.to_s
        rescue ArgumentError => e
            raise DataError, e.message
        end
    end

    # The five subcommands: how many blocks each takes, and the call
    # that composes them.
    module ComposeCommands
        ARITY = { "frame" => 1, "indent" => 1, "caption" => 1,
                  "beside" => 2.., "stack" => 2.. }.freeze

        def self.fetch(sub)
            ARITY.fetch(sub) do
                raise ComposeCLI::UsageError, "unknown subcommand #{sub}"
            end
            method(:"#{sub}_call")
        end

        def self.check_arity!(sub, paths)
            arity = ARITY.fetch(sub)
            return if arity === paths.size # rubocop:disable Style/CaseEquality

            want = arity.is_a?(Integer) ? "exactly one" : "at least two"
            want += arity.is_a?(Integer) ? " BLOCK" : " BLOCKs"
            raise ComposeCLI::UsageError, "#{sub} takes #{want}"
        end

        def self.frame_call(blocks, o)
            Compose.frame(blocks.first, title: o[:title], style: o[:style],
                                        pad: o.fetch(:pad, 1), ascii: o[:ascii])
        end

        def self.beside_call(blocks, o)
            Compose.beside(*blocks, gap: o.fetch(:gap, 1),
                                    align: o.fetch(:align, :top),
                                    ascii: o[:ascii])
        end

        def self.stack_call(blocks, o)
            Compose.stack(*blocks, gap: o.fetch(:gap, 0), rule: o[:rule],
                                   center: o[:center], ascii: o[:ascii])
        end

        def self.indent_call(blocks, o)
            Compose.indent(blocks.first, prefix: o[:prefix], ascii: o[:ascii])
        end

        def self.caption_call(blocks, o)
            Compose.caption(blocks.first, text: o[:text], above: o[:above],
                                          ascii: o[:ascii])
        end
    end
end
