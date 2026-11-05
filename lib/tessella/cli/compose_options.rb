# frozen_string_literal: true

module Tessella
    # `tessella compose` options, per subcommand: everything a usage
    # error can be (an unknown style or align, a style against --ascii,
    # a negative count, a missing --prefix or --text) is settled here.
    # --style's checks for `tessella compose frame`: a known name (not
    # another style against --ascii) or a valid custom set. Kept apart
    # so ComposeOptions stays under budget.
    module ComposeStyleCheck
        private

        def check_style!
            style = @opts[:style]
            return unless style
            return check_custom_style!(style) if Borders.custom?(style)

            usage!("unknown --style #{style}") unless
                Borders::STYLES.key?(style)
            usage!(ascii_conflict(style)) if @opts[:ascii] && style != :ascii
        end

        # Named for where ASCII came from: the flag, or the cjk
        # target's default, which --no-ascii lifts.
        def ascii_conflict(style)
            return "--style #{style} conflicts with --ascii" if @ascii_flag

            "--style #{style} needs --no-ascii under target cjk"
        end

        def check_custom_style!(style)
            Borders.custom(style, ascii: @opts[:ascii])
        rescue ArgumentError => e
            usage!(e.message)
        end
    end

    # The flags of `tessella compose`'s subcommands, one definer per
    # flag (ComposeOptions::FLAGS names which a subcommand takes).
    # Kept apart so ComposeOptions stays under budget.
    module ComposeFlags
        HALO = { "sides" => true, "around" => :around, "none" => false }.freeze

        private

        def add_title
            @parser.on("--title T", "a title in the top edge") do |t|
                @opts[:title] = t
            end
        end

        def add_style
            @parser.on("--style S", "a border style, or six glyphs") do |s|
                @opts[:style] = Borders.custom?(s) ? s : Borders.name(s)
            end
        end

        def add_pad = add_count("--pad", :pad, "blank columns inside each side")
        def add_gap = add_count("--gap", :gap, "blank columns (rows) between")

        def add_center
            @parser.on("--center", "centre narrower blocks") do
                @opts[:center] = true
            end
        end

        def add_prefix
            @parser.on("--prefix STR", "the text before every line") do |p|
                @opts[:prefix] = p
            end
        end

        def add_text = @parser.on("--text T", "caption") { @opts[:text] = it }

        def add_glyph
            @parser.on("--glyph G", "shadow glyph (░; # with --ascii)") do |g|
                @opts[:glyph] = g
            end
        end

        def add_fill
            @parser.on("--fill P", "fill the inside: a pattern name or " \
                                   "glyphs") { @opts[:fill] = it }
        end

        # --halo sides|around|none, or --no-halo for none.
        def add_halo
            @parser.on("--[no-]halo [H]", "blanks kept by text: sides,",
                       "around or none") do |h|
                @opts[:halo] = h == false ? false : (h || "sides")
            end
        end

        # --halo's optional H took the word after it: one that names no
        # halo is the block, given back.
        def unhalo!(argv)
            mode = @opts[:halo]
            return unless mode.is_a?(String)

            unless HALO.key?(mode)
                argv.unshift(mode)
                mode = "sides"
            end
            @opts[:halo] = HALO[mode]
        end

        def add_columns
            @parser.on("--columns N", Integer, "figures a row (2)") do |n|
                usage!("--columns must be >= 1") if n < 1
                @opts[:columns] = n
            end
        end

        def add_row_gap = add_count("--row-gap", :row_gap, "blank rows apart")

        def add_pattern
            @parser.on("--pattern P", "pattern name or glyphs (light)") do |p|
                @opts[:pattern] = p
            end
        end

        def add_above
            @parser.on("--above", "caption above, not below") do
                @opts[:above] = true
            end
        end

        def add_count(flag, key, text)
            @parser.on("#{flag} N", Integer, text) do |n|
                usage!("#{flag} must be >= 0") if n.negative?
                @opts[key] = n
            end
        end

        def add_align
            @parser.on("--align A", "top, middle or bottom") do |a|
                usage!("unknown --align #{a}") unless
                    Compose::ALIGNS.include?(a.to_sym)
                @opts[:align] = a.to_sym
            end
        end

        def add_rule
            @parser.on("--rule C", "a rule of C between blocks") do |c|
                usage!("--rule must be exactly one character") unless
                    c.length == 1
                @opts[:rule] = c
            end
        end
    end

    class ComposeOptions
        include ComposeStyleCheck
        include ComposeFlags

        FLAGS = {
            "frame" => %i[title style pad fill halo],
            "beside" => %i[gap align],
            "stack" => %i[gap rule center], "indent" => %i[prefix],
            "caption" => %i[text above], "shadow" => %i[glyph],
            "fill" => %i[pattern halo],
            "grid" => %i[columns gap row_gap align]
        }.freeze
        REQUIRED = { "indent" => :prefix, "caption" => :text }.freeze

        def self.parse(sub, argv)
            new(sub).parse(argv)
        end

        def initialize(sub)
            @sub = sub
            @opts = { ascii: Target.ascii? }
            @parser = OptionParser.new
            @parser.banner = ComposeCLI.usage_line(sub)
            FLAGS.fetch(sub).each { send(:"add_#{it}") }
            add_common
        end

        def parse(argv)
            @parser.parse!(argv)
            unhalo!(argv)
            check_required!
            check_style!
            [@opts, argv]
        end

        private

        def usage!(message) = raise(ComposeCLI::UsageError, message)

        def add_common
            add_ascii
            @parser.on("--max-width N", Integer,
                       "refuse a figure wider than N columns") do |n|
                usage!("--max-width must be >= 1") if n < 1
                @opts[:max_width] = n
            end
            add_help
        end

        def add_ascii
            @parser.on("--[no-]ascii",
                       "ASCII glyphs; refuse non-ASCII text") do |v|
                @opts[:ascii] = v
                @ascii_flag = v
            end
        end

        def add_help
            @parser.on("--help", "print this help") do
                raise ComposeCLI::Help, @parser.to_s
            end
        end

        def check_required!
            key = REQUIRED[@sub]
            usage!("#{@sub} requires --#{key}") if key && !@opts[key]
        end
    end

    # Blocks for `tessella compose`, one per file argument ("-" is
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
            raise ComposeCLI::DataError, CLI.cannot_read(path, e)
        end

        def self.check!(path, lines, ascii)
            lines.each_with_index do |line, i|
                where = "#{path}:#{i + 1}"
                raise ComposeCLI::DataError, "#{where}: tab character" if
                    line.include?("\t")
                raise ComposeCLI::DataError, "#{where}: non-ASCII byte" if
                    ascii && !line.ascii_only? && !Target.text_free?
            end
        end
    end
end
