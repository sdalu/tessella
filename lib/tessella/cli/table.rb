# frozen_string_literal: true

module Tessella
    # `tessella table` options (ported from the ascii-art skill's
    # scripts/table.rb): everything a usage error can be -- an
    # unknown --style, a malformed --align, a negative --max-width,
    # more than one file -- is settled here, before any row is read.
    class TableOptions
        def self.parse(argv)
            new.parse(argv)
        end

        def initialize
            @opts = { ascii: Target.ascii?, tsv: false, no_header: false }
            @parser = build_parser
        end

        def parse(argv)
            @parser.parse!(argv)
            raise TableCLI::UsageError, "too many arguments" if argv.size > 1

            check_custom_style!
            [@opts, argv]
        end

        private

        def usage!(message) = raise(TableCLI::UsageError, message)

        def build_parser
            OptionParser.new do |op|
                op.banner = TableCLI::BANNER
                add_input(op)
                add_style(op)
                add_output(op)
            end
        end

        def add_input(op)
            op.on("--tsv") { @opts[:tsv] = true }
            op.on("--no-header") { @opts[:no_header] = true }
            op.on("--align SPEC") { |s| @opts[:align] = align!(s) }
        end

        # A name, or a glyph set checked as a table's (11 glyphs).
        def style!(spec, names)
            name = Borders.name(spec)
            return name if names.include?(name.to_s)

            usage!("unknown --style #{spec}") unless Borders.custom?(spec)
            Table::Glyphs.custom(spec)
            spec
        rescue ArgumentError => e
            usage!(e.message)
        end

        def check_custom_style!
            style = @opts[:style]
            Borders.custom(style, ascii: @opts[:ascii]) if
                Borders.custom?(style)
        rescue ArgumentError => e
            usage!(e.message)
        end

        def align!(spec)
            usage!("--align must be letters l, r or c") unless
                /\A[lrc]+\z/i.match?(spec)
            spec.downcase
        end

        def add_style(op)
            names = Table::STYLE_NAMES.map(&:to_s)
            op.on("--style S", "#{names.join(", ")},",
                  "or 11 glyphs: tl tr bl br h v top_t bot_t",
                  "sep_l sep_t sep_r") do |s|
                @opts[:style] = style!(s, names)
            end
            op.on("--ascii") { @opts[:ascii] = true }
            op.on("--title TEXT") { |t| @opts[:title] = t }
        end

        def add_output(op)
            op.on("--max-width N", Integer) do |n|
                usage!("--max-width must be >= 1") if n < 1
                @opts[:max_width] = n
            end
            op.on("-h", "--help") do
                @opts[:help] = true
            end
        end
    end

    # `tessella table` (DESIGN.md, "Command line"): one table from
    # one CSV/TSV file argument ("-" or none for stdin). Exit 0 drawn,
    # 1 bad input (a ragged row, no rows, malformed CSV, output past
    # --max-width), 2 usage. The script's --no-lint has no equivalent
    # here: the artlint.rb pass stays in the skill.
    class TableCLI
        class UsageError < StandardError; end
        class DataError < StandardError; end

        BANNER = <<~TEXT
            Usage: tessella table [options] [file]  (stdin if none)
                --tsv --no-header --align SPEC --style NAME|GLYPHS --ascii
                --title TEXT --max-width N
        TEXT

        def self.run(argv, stdin:, stdout:, stderr:)
            opts, paths = TableOptions.parse(argv.dup)
            return help(stdout) if opts[:help]

            stdout.print(draw(paths.first, opts, stdin))
            0
        rescue UsageError, OptionParser::ParseError => e
            fail_with(stderr, e.message, 2)
        rescue DataError => e
            fail_with(stderr, e.message, 1)
        end

        def self.help(stdout)
            stdout.print(BANNER)
            0
        end

        def self.fail_with(stderr, message, status)
            stderr.puts("tessella table: #{message}")
            stderr.print(BANNER) if status == 2
            status
        end

        def self.draw(path, opts, stdin)
            rows = Table.parse(read(path, stdin), tsv: opts[:tsv])
            header = !opts[:no_header]
            block = build(rows, header, opts)
            check_max_width!(block, opts[:max_width])
            block.to_s
        rescue ArgumentError => e
            raise DataError, e.message
        end

        def self.build(rows, header, opts)
            head, body = Table.split(rows, header)
            check_align_length!(opts[:align], (head || body.first).size)
            Tessella.table(rows, header: header, style: opts[:style],
                                 ascii: opts[:ascii], align: opts[:align],
                                 title: opts[:title])
        end

        def self.read(path, stdin)
            path ? File.read(path) : stdin.read
        rescue SystemCallError => e
            raise DataError, CLI.cannot_read(path, e)
        end

        def self.check_align_length!(align, ncols)
            return unless align && align.length != ncols

            raise UsageError,
                  "--align has #{align.length} letters, #{ncols} columns"
        end

        def self.check_max_width!(block, max_width)
            return unless max_width

            over = block.lines.map(&:rstrip).find { Width.of(it) > max_width }
            return unless over

            raise DataError, "output is #{Width.of(over)} columns, over " \
                             "--max-width #{max_width}"
        end
    end
end
