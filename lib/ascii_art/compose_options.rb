# frozen_string_literal: true

module AsciiArt
    # `ascii-art compose` options, per subcommand: everything a usage
    # error can be (an unknown style or align, a style against --ascii,
    # a negative count, a missing --prefix or --text) is settled here.
    class ComposeOptions
        FLAGS = {
            "frame" => %i[title style pad], "beside" => %i[gap align],
            "stack" => %i[gap rule center], "indent" => %i[prefix],
            "caption" => %i[text above]
        }.freeze
        REQUIRED = { "indent" => :prefix, "caption" => :text }.freeze

        def self.parse(sub, argv)
            new(sub).parse(argv)
        end

        def initialize(sub)
            @sub = sub
            @opts = {}
            @parser = OptionParser.new
            FLAGS.fetch(sub).each { send(:"add_#{it}") }
            add_common
        end

        def parse(argv)
            @parser.parse!(argv)
            check_required!
            check_style!
            [@opts, argv]
        end

        private

        def usage!(message) = raise(ComposeCLI::UsageError, message)

        def add_common
            @parser.on("--ascii") { @opts[:ascii] = true }
            @parser.on("--max-width N", Integer) do |n|
                usage!("--max-width must be >= 1") if n < 1
                @opts[:max_width] = n
            end
        end

        def add_title = @parser.on("--title T") { @opts[:title] = it }
        def add_style = @parser.on("--style S") { @opts[:style] = it.to_sym }
        def add_pad = add_count("--pad", :pad)
        def add_gap = add_count("--gap", :gap)
        def add_center = @parser.on("--center") { @opts[:center] = true }
        def add_prefix = @parser.on("--prefix STR") { @opts[:prefix] = it }
        def add_text = @parser.on("--text T") { @opts[:text] = it }
        def add_above = @parser.on("--above") { @opts[:above] = true }

        def add_count(flag, key)
            @parser.on("#{flag} N", Integer) do |n|
                usage!("#{flag} must be >= 0") if n.negative?
                @opts[key] = n
            end
        end

        def add_align
            @parser.on("--align A") do |a|
                usage!("unknown --align #{a}") unless
                    Compose::ALIGNS.include?(a.to_sym)
                @opts[:align] = a.to_sym
            end
        end

        def add_rule
            @parser.on("--rule C") do |c|
                usage!("--rule must be exactly one character") unless
                    c.length == 1
                @opts[:rule] = c
            end
        end

        def check_required!
            key = REQUIRED[@sub]
            usage!("#{@sub} requires --#{key}") if key && !@opts[key]
        end

        def check_style!
            style = @opts[:style]
            return unless style

            usage!("unknown --style #{style}") unless
                Borders::STYLES.key?(style)
            usage!("--style #{style} conflicts with --ascii") if
                @opts[:ascii] && style != :ascii
        end
    end

    # Blocks for `ascii-art compose`, one per file argument ("-" is
    # stdin, at most once), each refused as bad input, naming the file
    # and line, when it is missing, empty, holds a tab, or holds a
    # non-ASCII byte under --ascii.
    module ComposeReader
        def self.blocks(paths, opts, stdin)
            if paths.count("-") > 1
                raise ComposeCLI::UsageError, "'-' given more than once"
            end

            paths.map { block(it, opts[:ascii], stdin) }
        end

        def self.block(path, ascii, stdin)
            lines = read(path, stdin).lines(chomp: true)
            check!(path, lines, ascii)
            Block.new(lines)
        rescue ArgumentError
            raise ComposeCLI::DataError, "#{path}: empty block"
        end

        def self.read(path, stdin)
            path == "-" ? stdin.read : File.read(path)
        rescue SystemCallError => e
            raise ComposeCLI::DataError, "#{path}: #{e.message}"
        end

        def self.check!(path, lines, ascii)
            lines.each_with_index do |line, i|
                where = "#{path}:#{i + 1}"
                raise ComposeCLI::DataError, "#{where}: tab character" if
                    line.include?("\t")
                raise ComposeCLI::DataError, "#{where}: non-ASCII byte" if
                    ascii && !line.ascii_only?
            end
        end
    end
end
