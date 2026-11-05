# frozen_string_literal: true

module Inkchart
    # The command line (DESIGN.md, "Command line"): parses argv, reads
    # a file or stdin, calls one Inkchart.<kind>, and prints. Split
    # into the small classes and modules below (each kept under the
    # ruby skill's size budget); every reopening of CLI adds one.
    class CLI
        # The family of refusals CLI.run turns into an exit status
        # rather than letting bubble past it. UsageError (exit 2) is a
        # bad invocation; DataError (exit 1) is input that cannot
        # become a chart.
        class Error < StandardError; end
        class UsageError < Error; end
        class DataError < Error; end

        # Raised by --help and --version to short-circuit parsing with
        # a message and a status already decided.
        class Halt < StandardError
            attr_reader :status, :text

            def initialize(status, text)
                @status = status
                @text = text
                super(text)
            end
        end

        BANNER = "Usage: inkchart [options] [file]"

        # argv is read, never mutated; the kind's one Inkchart.<kind>
        # call draws the chart, printed to stdout. Returns the exit
        # status: 0 drawn, 1 bad input, 2 usage.
        def self.run(argv, stdin:, stdout:, stderr:)
            draw(argv, stdin, stdout)
        rescue Halt => e
            halt(e, stdout, stderr)
        rescue OptionParser::ParseError, UsageError, ArgumentError => e
            usage_error(e, stderr)
        rescue DataError => e
            data_error(e, stderr)
        end

        def self.draw(argv, stdin, stdout)
            opts, path = Options.parse(argv.dup)
            KindOptions.check!(opts)
            chart = Kinds.build(opts, Reader.rows(path, stdin))
            stdout.print(chart.to_s)
            0
        end

        def self.halt(error, stdout, stderr)
            (error.status.zero? ? stdout : stderr).print(error.text)
            error.status
        end

        def self.usage_error(error, stderr)
            stderr.puts("inkchart: #{error.message}")
            stderr.puts(BANNER)
            2
        end

        def self.data_error(error, stderr)
            stderr.puts("inkchart: #{error.message}")
            1
        end
    end

    # Integer-or-Float parsing that keeps a number's own kind
    # (DESIGN.md: "A number keeps its kind"), shared by option values
    # and data fields. nil when neither parses.
    class CLI
        module Num
            def self.parse(raw)
                Integer(raw, 10, exception: false) ||
                    Float(raw, exception: false)
            end
        end
    end

    # Parses argv into the options CLI.run acts on: :kind plus every
    # key ChartOpts and KindOptions know about. Raises Halt for
    # --help/--version, or lets OptionParser::ParseError escape for a
    # bad flag, missing argument, or disallowed value.
    class CLI
        class Options
            KINDS = %w[line scatter stairs density bar histogram box
                       stem].freeze

            def self.parse(argv)
                new.parse(argv)
            end

            def initialize
                @opts = { kind: :line }
                @parser = OptionParser.new
                @parser.banner = CLI::BANNER
                build
            end

            def parse(argv)
                @parser.parse!(argv)
                raise CLI::UsageError, "one file argument at most" if
                    argv.size > 1

                [@opts, argv.first]
            end

            private

            def build
                add_kind_and_dims
                add_labels
                add_ranges
                add_render
                add_kind_specific
                add_bar_specific
                add_meta
            end

            def add_kind_and_dims
                @parser.on("--kind KIND", KINDS) { |v| @opts[:kind] = v.to_sym }
                @parser.on("--width N", Integer) { |v| @opts[:width] = v }
                @parser.on("--height N", Integer) { |v| @opts[:height] = v }
            end

            def add_labels
                @parser.on("--title S") { |v| @opts[:title] = v }
                @parser.on("--xlabel S") { |v| @opts[:xlabel] = v }
                @parser.on("--ylabel S") { |v| @opts[:ylabel] = v }
            end

            def add_ranges
                @parser.on("--xlim A,B", Array) { |v| @opts[:xlim] = range(v) }
                @parser.on("--ylim A,B", Array) { |v| @opts[:ylim] = range(v) }
            end

            def add_render
                @parser.on("--canvas C") { |v| @opts[:canvas] = v.to_sym }
                @parser.on("--ascii") { @opts[:ascii] = true }
                @parser.on("--color") { @opts[:color] = true }
            end

            def add_kind_specific
                add_histogram_specific
                @parser.on("--style C") { |v| @opts[:style] = v.to_sym }
                @parser.on("--scale N") { |v| @opts[:scale] = num(v) }
                @parser.on("--xscale C") { |v| @opts[:xscale] = v.to_sym }
            end

            def add_histogram_specific
                @parser.on("--bins N", Integer) { |v| @opts[:bins] = v }
                @parser.on("--closed C") { |v| @opts[:closed] = v.to_sym }
            end

            def add_bar_specific
                @parser.on("--fill G") { |v| @opts[:fill] = v }
                @parser.on("--no-eighths") { @opts[:eighths] = false }
                @parser.on("--track G") do |v|
                    @opts[:track] = v == "none" ? nil : v
                end
            end

            def add_meta
                @parser.on("--help") { raise CLI::Halt.new(0, @parser.to_s) }
                @parser.on("--version") do
                    raise CLI::Halt.new(0, "#{Inkchart::VERSION}\n")
                end
            end

            def range(values)
                return values.map { num(it) } if values.size == 2

                raise OptionParser::InvalidArgument, values.join(",")
            end

            def num(raw)
                Num.parse(raw) || (raise OptionParser::InvalidArgument, raw)
            end
        end
    end

    # One numeric column out of parsed rows, naming the row and the
    # field in any refusal (DESIGN.md's CLI input rules: "the message
    # naming the row number and the field").
    class CLI
        module Columns
            def self.numeric(rows, index, name)
                rows.each_with_index.map { |row, i| field(row, index, name, i) }
            end

            def self.field(row, index, name, row_no)
                raw = row[index]
                raise DataError, "row #{row_no + 1} has no #{name}" if
                    raw.nil?

                Num.parse(raw) || bad_number(raw, name, row_no)
            end

            def self.bad_number(raw, name, row_no)
                raise DataError,
                      "row #{row_no + 1}: #{name} is not a number: " \
                      "#{raw.inspect}"
            end
        end
    end

    # Splits a header row from the data (DESIGN.md: "a first row that
    # is not all numbers names the columns"; bar looks only at the
    # value field).
    class CLI
        module Header
            def self.split(rows, bar_like: false)
                return [nil, rows] unless header?(rows.first, bar_like)

                [rows.first, rest(rows)]
            end

            def self.rest(rows)
                data = rows.drop(1)
                raise DataError, "no data after the header" if data.empty?

                data
            end

            def self.header?(row, bar_like)
                return !numeric?(row[1]) if bar_like

                !row.all? { numeric?(it) }
            end

            def self.numeric?(field) = !field.nil? && !Num.parse(field).nil?
        end
    end

    # The subset of parsed options forwarded to Inkchart.<kind>: the
    # options common to every kind, plus the ones its own kind takes
    # (DESIGN.md's "Command line" and "Chart and kinds").
    class CLI
        module ChartOpts
            COMMON = %i[title xlabel ylabel width height xlim ylim canvas
                        ascii color xscale].freeze

            EXTRA = {
                stairs: %i[style],
                bar: %i[fill eighths track],
                histogram: %i[fill eighths track bins closed],
                stem: %i[scale]
            }.freeze

            def self.for(opts)
                opts.slice(*(COMMON + EXTRA.fetch(opts[:kind], [])))
            end
        end
    end

    # An option a kind does not take is a usage error naming both
    # (DESIGN.md's "Command line"): --style, --scale, --bins,
    # --closed, and bar's own --fill/--no-eighths/--track only fit
    # certain kinds.
    class CLI
        module KindOptions
            FLAG = { style: "--style", scale: "--scale", bins: "--bins",
                     closed: "--closed", fill: "--fill",
                     eighths: "--no-eighths", track: "--track" }.freeze

            def self.check!(opts)
                allowed = ChartOpts::EXTRA.fetch(opts[:kind], [])
                (FLAG.keys - allowed).each { refuse!(opts, it, opts[:kind]) }
            end

            def self.refuse!(opts, key, kind)
                return unless opts.key?(key)

                raise UsageError,
                      "#{FLAG[key]} is not valid with --kind #{kind}"
            end
        end
    end

    # Lines from a file or stdin into fields: CSV, tabs or runs of
    # spaces; blank lines and # comments skipped (DESIGN.md's CLI
    # input rules, as the ascii-art skill's plot.rb helper reads
    # them too).
    class CLI
        class Reader
            FIELD_SPLIT = /\s*,\s*|\s+/

            def self.rows(path, stdin)
                rows = text(path, stdin).each_line.filter_map { line(it) }
                raise DataError, "no data" if rows.empty?

                rows
            end

            def self.text(path, stdin)
                path ? File.read(path) : stdin.read
            rescue SystemCallError => e
                raise DataError, "cannot read #{path}: #{e.message}"
            end

            def self.line(raw)
                stripped = raw.strip
                return nil if stripped.empty? || stripped.start_with?("#")

                stripped.split(FIELD_SPLIT)
            end
        end
    end

    # Dispatches to the one builder for opts[:kind] (DESIGN.md's CLI
    # input rules: the column shape differs by kind).
    class CLI
        module Kinds
            SERIES = %i[line scatter stairs density].freeze
            BARLIKE = %i[bar histogram].freeze

            def self.build(opts, rows)
                kind = opts[:kind]
                return SeriesKind.build(kind, opts, rows) if
                    SERIES.include?(kind)
                return BarKind.build(kind, opts, rows) if
                    BARLIKE.include?(kind)
                return BoxKind.build(opts, rows) if kind == :box

                StemKind.build(opts, rows)
            end
        end
    end

    # line, scatter, stairs, density: one column is y against 1..n,
    # two are x y, more are x and one series per further column
    # (DESIGN.md's CLI input rules). The one Inkchart.<kind> call
    # below makes the first series, named by its header field, and
    # chart.add the rest, each named the same way.
    class CLI
        class SeriesKind
            def self.build(kind, opts, rows)
                header, data = Header.split(rows)
                ncols = (header || data.first).size
                columns = (0...ncols).map { column(data, header, it, ncols) }
                chart = first_call(kind, opts, columns, header)
                add_rest(chart, columns, header)
                chart
            end

            def self.column(data, header, i, ncols)
                Columns.numeric(data, i, field_name(header, i, ncols))
            end

            def self.field_name(header, i, ncols)
                return "y" if ncols == 1
                return "x" if i.zero?

                header ? header[i] : "y#{i}"
            end

            def self.first_call(kind, opts, columns, header)
                args = columns.size == 1 ? [columns[0]] : columns[0, 2]
                name = header && header[columns.size == 1 ? 0 : 1]
                Inkchart.public_send(kind, *args, name: name,
                                                  **ChartOpts.for(opts))
            end

            def self.add_rest(chart, columns, header)
                columns[2..].to_a.each_with_index do |y, j|
                    chart.add(columns[0], y, name: header && header[j + 2])
                end
            end
        end
    end

    # bar: label value; histogram: one column of samples, over
    # Stats.histogram's bins (DESIGN.md's CLI input rules).
    class CLI
        class BarKind
            def self.build(kind, opts, rows)
                _header, data = Header.split(rows, bar_like: kind == :bar)
                kind == :bar ? bar(opts, data) : histogram(opts, data)
            end

            def self.bar(opts, data)
                labels = data.map { it[0] }
                values = Columns.numeric(data, 1, "value")
                Inkchart.bar(labels, values, **ChartOpts.for(opts))
            end

            def self.histogram(opts, data)
                samples = Columns.numeric(data, 0, "sample")
                Inkchart.histogram(samples, **ChartOpts.for(opts))
            end
        end
    end

    # box: one or more columns, one box per column, named by the
    # header or 1..n (DESIGN.md's CLI input rules).
    class CLI
        class BoxKind
            def self.build(opts, rows)
                header, data = Header.split(rows)
                ncols = (header || data.first).size
                names = header || (1..ncols).map(&:to_s)
                columns = (0...ncols).map do |i|
                    Columns.numeric(data, i, names[i])
                end
                Inkchart.box(names, columns, **ChartOpts.for(opts))
            end
        end
    end

    # stem: one column, or two for the back-to-back form (DESIGN.md's
    # CLI input rules).
    class CLI
        class StemKind
            def self.build(opts, rows)
                header, data = Header.split(rows)
                ncols = (header || data.first).size
                check_ncols!(ncols)
                values = Columns.numeric(data, 0, "value")
                other = ncols == 2 ? Columns.numeric(data, 1, "other") : nil
                Inkchart.stem(values, other, **ChartOpts.for(opts))
            end

            def self.check_ncols!(ncols)
                return if ncols <= 2

                raise DataError, "stem takes one or two columns, got #{ncols}"
            end
        end
    end
end
