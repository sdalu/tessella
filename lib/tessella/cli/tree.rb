# frozen_string_literal: true

module Tessella
    # `tessella tree` (DESIGN.md, "Command line"): draws one tree from
    # a file argument or stdin. Same options as the ascii-art skill's
    # scripts/tree.rb minus --no-lint (its lint pass stays in the
    # skill) plus --help; messages are prefixed "tessella tree: ".
    # Exit 0 drawn; 1 bad input, an ArgumentError from Tree itself
    # (a tab, a bad indent, a skipped level, an unknown style, a
    # render past --max-width); 2 usage (an unknown option, more than
    # one file argument, or a missing file, as tree.rb itself exits
    # for the last of those).
    class TreeCLI
        class UsageError < StandardError; end
        class Help < StandardError; end

        USAGE_ERRORS = [OptionParser::ParseError, UsageError].freeze

        USAGE = <<~TEXT
            Usage: tessella tree [--style S] [--ascii] [--root NAME]
                                 [--max-width N] [file]  (stdin if none)
        TEXT

        def self.run(argv, stdin:, stdout:, stderr:)
            opts, paths = TreeOptions.parse(argv.dup)
            check_arity!(paths)
            stdout.print(draw(read(paths.first, stdin), opts))
            0
        rescue Help
            help(stdout)
        rescue *USAGE_ERRORS => e
            fail_with(stderr, e.message, 2)
        rescue ArgumentError => e
            fail_with(stderr, e.message, 1)
        end

        def self.help(stdout)
            stdout.print(USAGE)
            0
        end

        def self.fail_with(stderr, message, status)
            stderr.puts("tessella tree: #{message}")
            status
        end

        def self.check_arity!(paths)
            raise UsageError, "too many arguments" if paths.size > 1
        end

        def self.read(path, stdin)
            path ? File.read(path) : stdin.read
        rescue SystemCallError => e
            raise ArgumentError, CLI.cannot_read(path, e)
        end

        # Usage is settled by now; style is ignored under --ascii, as
        # tree.rb itself ignores it rather than refusing the conflict
        # (Tree.render's own refusal is for a direct Tessella.tree
        # call made with both; this CLI never reaches it, since it
        # drops style whenever --ascii is given, same as the script).
        def self.draw(text, opts)
            style = opts[:ascii] ? nil : opts[:style]
            result = Tree.render(text, style: style, ascii: opts[:ascii],
                                       root: opts[:root])
            Tree.check_max_width!(result, opts[:max_width])
            Block.new(result.lines).to_s
        end
    end

    # `tessella tree`'s options: --style (one of STYLE_NAMES; another
    # value is OptionParser's own usage error, as tree.rb's own
    # `--style S, STYLES.keys` is), --ascii, --root NAME, --max-width
    # N, and -h/--help, which raises immediately on being parsed (as
    # tree.rb's own `-h`/`--help` prints its usage and exits on the
    # spot, so an error in an option before it on the line still wins).
    class TreeOptions
        STYLE_NAMES = %w[light heavy rounded].freeze

        def self.parse(argv)
            opts = { style: nil, ascii: false, root: nil, max_width: nil }
            build_parser(opts).parse!(argv)
            [opts, argv]
        end

        def self.build_parser(opts)
            OptionParser.new do |op|
                op.banner = TreeCLI::USAGE
                add_options(op, opts)
            end
        end

        def self.add_options(op, opts)
            op.on("--style S", STYLE_NAMES) { |s| opts[:style] = s.to_sym }
            op.on("--ascii") { opts[:ascii] = true }
            op.on("--root NAME") { |n| opts[:root] = n }
            op.on("--max-width N", Integer) { |n| opts[:max_width] = n }
            op.on("-h", "--help") { raise TreeCLI::Help }
        end
    end
end
