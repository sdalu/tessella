# frozen_string_literal: true

module Tessella
    # The command line (DESIGN.md, "Command line"): parses argv, reads
    # a file or stdin, calls one Tessella.<kind>, and prints. Split
    # into the small classes and modules below (each kept under the
    # ruby skill's size budget); every reopening of CLI adds one.
    class ChartCLI
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

        BANNER = "Usage: tessella chart [options] [file]"

        # argv is read, never mutated; the kind's one Tessella.<kind>
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
            rows = Reader.rows(path, stdin)
            Reader.check_ascii!(rows) if opts[:ascii]
            chart = Kinds.build(opts, rows)
            stdout.print(chart.to_s)
            0
        end

        def self.halt(error, stdout, stderr)
            (error.status.zero? ? stdout : stderr).print(error.text)
            error.status
        end

        def self.usage_error(error, stderr)
            stderr.puts("tessella chart: #{error.message}")
            stderr.puts(BANNER)
            2
        end

        def self.data_error(error, stderr)
            stderr.puts("tessella chart: #{error.message}")
            1
        end
    end

    # Integer-or-Float parsing that keeps a number's own kind
    # (DESIGN.md: "A number keeps its kind"), shared by option values
    # and data fields. nil when neither parses.
    class ChartCLI
        module Num
            def self.parse(raw)
                Integer(raw, 10, exception: false) ||
                    Float(raw, exception: false)
            end
        end
    end

    # Flags particular to some kinds (the axes' scales and dates, the
    # histogram's bins, the heatmap's cells), kept apart so Options
    # stays under budget.
    class ChartCLI
        module KindFlags
            private

            def add_axes
                @parser.on("--yscale C") { |v| @opts[:yscale] = v.to_sym }
                @parser.on("--xdate [FMT]") { |v| @opts[:xdate] = v || true }
                @parser.on("--yerr") { @opts[:yerr] = true }
                add_threshold
            end

            def add_threshold
                @parser.on("--threshold N") { @opts[:threshold] = num(it) }
                @parser.on("--above C") { @opts[:above] = Color.parse(it) }
                @parser.on("--below C") { @opts[:below] = Color.parse(it) }
            end

            def add_histogram_specific
                @parser.on("--bins N", Integer) { |v| @opts[:bins] = v }
                @parser.on("--closed C") { |v| @opts[:closed] = v.to_sym }
            end

            def add_layout
                @parser.on("--orientation O", %w[horizontal vertical]) do |v|
                    @opts[:orientation] = v.to_sym
                end
                blocks = %w[eighths braille block quadrant half]
                @parser.on("--blocks B", blocks) do |v|
                    @opts[:blocks] = v.to_sym
                end
            end

            def add_heatmap
                @parser.on("--cell-width N", Integer) do |n|
                    @opts[:cell_width] = n
                end
                @parser.on("--colormap C,C", Array) do |v|
                    @opts[:colormap] = v.map { Color.parse(it) }
                end
                @parser.on("--min A") { @opts[:min] = num(it) }
                @parser.on("--max B") { @opts[:max] = num(it) }
            end
        end
    end

    # Parses argv into the options CLI.run acts on: :kind plus every
    # key ChartOpts and KindOptions know about. Raises Halt for
    # --help/--version, or lets OptionParser::ParseError escape for a
    # bad flag, missing argument, or disallowed value.
    class ChartCLI
        class Options
            include KindFlags

            KINDS = %w[line scatter stairs density bar histogram box
                       stem heatmap].freeze

            def self.parse(argv)
                new.parse(argv)
            end

            def initialize
                @opts = { kind: :line }
                @parser = OptionParser.new
                @parser.banner = ChartCLI::BANNER
                build
            end

            def parse(argv)
                @parser.parse!(argv)
                raise ChartCLI::UsageError, "one file argument at most" if
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
                add_area
                @parser.on("--style C") { |v| @opts[:style] = v.to_sym }
                @parser.on("--scale N") { |v| @opts[:scale] = num(v) }
                @parser.on("--xscale C") { |v| @opts[:xscale] = v.to_sym }
                add_axes
            end

            def add_area
                @parser.on("--area") { @opts[:area] = true }
                @parser.on("--gradient C,C", Array) do |v|
                    @opts[:gradient] =
                        v == ["none"] ? false : v.map { Color.parse(it) }
                end
            end

            def add_bar_specific
                add_heatmap
                add_layout
                @parser.on("--stacked") { @opts[:stacked] = true }
                @parser.on("--fill G") { |v| @opts[:fill] = v }
                @parser.on("--no-eighths") { @opts[:eighths] = false }
                @parser.on("--track G") do |v|
                    @opts[:track] = v == "none" ? nil : v
                end
            end

            def add_meta
                @parser.on("--help") { raise ChartCLI::Halt.new(0, @parser.to_s) }
                @parser.on("--version") do
                    raise ChartCLI::Halt.new(0, "#{Tessella::VERSION}\n")
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
    class ChartCLI
        module Columns
            def self.numeric(rows, index, name)
                rows.each_with_index.map { |row, i| field(row, index, name, i) }
            end

            # The x column under --xdate: ISO 8601 times, a bad one named.
            def self.times(rows, index)
                rows.each_with_index.map do |row, i|
                    IsoTime.parse(row[index].to_s) or
                        raise DataError, "row #{i + 1}: x is not an ISO 8601 " \
                                         "date: #{row[index].inspect}"
                end
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
    class ChartCLI
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

    # The subset of parsed options forwarded to Tessella.<kind>: the
    # options common to every kind, plus the ones its own kind takes
    # (DESIGN.md's "Command line" and "Chart and kinds").
    class ChartCLI
        module ChartOpts
            COMMON = %i[title xlabel ylabel width height xlim ylim canvas
                        ascii color xscale].freeze

            EXTRA = {
                line: %i[area gradient orientation yscale xdate yerr
                         threshold above below],
                scatter: %i[orientation yscale xdate yerr threshold above
                            below],
                density: %i[orientation yscale xdate],
                stairs: %i[style area gradient orientation yscale xdate
                           threshold above below],
                bar: %i[fill eighths track orientation blocks stacked],
                histogram: %i[fill eighths track bins closed orientation
                              blocks],
                box: %i[orientation],
                heatmap: %i[cell_width colormap min max],
                stem: %i[scale]
            }.freeze

            # The chart's own options; --yerr goes to its series instead.
            def self.for(opts)
                opts.slice(*(COMMON + EXTRA.fetch(opts[:kind], []) - %i[yerr]))
            end
        end
    end

    # An option a kind does not take is a usage error naming both
    # (DESIGN.md's "Command line"): --style, --scale, --bins,
    # --closed, and bar's own --fill/--no-eighths/--track only fit
    # certain kinds.
    class ChartCLI
        module KindOptions
            FLAG = { style: "--style", scale: "--scale", bins: "--bins",
                     closed: "--closed", fill: "--fill", area: "--area",
                     gradient: "--gradient", orientation: "--orientation",
                     blocks: "--blocks", yscale: "--yscale",
                     stacked: "--stacked", cell_width: "--cell-width",
                     xdate: "--xdate", yerr: "--yerr",
                     threshold: "--threshold", above: "--above",
                     below: "--below",
                     colormap: "--colormap", min: "--min", max: "--max",
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
    # them too). A line holding a comma splits on commas only, one
    # holding a tab on tabs only, so a label may hold spaces; only a
    # line with neither splits on runs of spaces.
    class ChartCLI
        class Reader
            def self.fields(line)
                return line.split(/\s*,\s*/) if line.include?(",")
                return line.split(/\s*\t\s*/) if line.include?("\t")

                line.split
            end

            def self.rows(path, stdin)
                rows = text(path, stdin).each_line.filter_map { line(it) }
                raise DataError, "no data" if rows.empty?

                rows
            end

            # A non-ASCII label under --ascii is bad input, named by
            # its row (a non-ASCII --title or label is usage).
            def self.check_ascii!(rows)
                i = rows.index { |row| !row.join.ascii_only? } or return

                raise DataError, "row #{i + 1} is non-ASCII under --ascii"
            end

            def self.text(path, stdin)
                path ? File.read(path) : stdin.read
            rescue SystemCallError => e
                raise DataError, CLI.cannot_read(path, e)
            end

            def self.line(raw)
                stripped = raw.strip
                return nil if stripped.empty? || stripped.start_with?("#")

                fields(stripped)
            end
        end
    end

    # Dispatches to the one builder for opts[:kind] (DESIGN.md's CLI
    # input rules: the column shape differs by kind).
    class ChartCLI
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
                return HeatKind.build(opts, rows) if kind == :heatmap

                StemKind.build(opts, rows)
            end
        end
    end

    # line, scatter, stairs, density: one column is y against 1..n,
    # two are x y, more are x and one series per further column
    # (DESIGN.md's CLI input rules). The one Tessella.<kind> call
    # below makes the first series, named by its header field, and
    # chart.add the rest, each named the same way.
    class ChartCLI
        class SeriesKind
            def self.build(kind, opts, rows)
                header, data = Header.split(rows)
                ncols = (header || data.first).size
                columns = (0...ncols).map do |i|
                    column(data, header, i, ncols, opts[:xdate])
                end
                chart = first_call(kind, opts, columns, header)
                add_rest(chart, columns, header)
                chart
            end

            def self.column(data, header, i, ncols, xdate)
                return Columns.times(data, i) if xdate && i.zero? && ncols > 1

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
                Tessella.public_send(kind, *args, name: name,
                                                  **error_opts(opts, columns),
                                                  **ChartOpts.for(opts))
            end

            # --yerr: x, y and the error, three columns exactly.
            def self.error_opts(opts, columns)
                return {} unless opts[:yerr]
                unless columns.size == 3
                    raise DataError, "--yerr reads x, y and the error: " \
                                     "#{columns.size} columns"
                end
                { yerr: errors!(columns.pop) }
            end

            # A negative error is a bad value in the input: its row named.
            def self.errors!(errors)
                i = errors.index(&:negative?)
                return errors unless i

                raise DataError, "row #{i + 1}: the error is negative: " \
                                 "#{Axis.label(errors[i])}"
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
    class ChartCLI
        class BarKind
            def self.build(kind, opts, rows)
                header, data = Header.split(rows, bar_like: kind == :bar)
                return histogram(opts, data) unless kind == :bar

                bar(opts, data, header)
            end

            # label value, or label and a value a series (named by the
            # header), grouped or --stacked.
            def self.bar(opts, data, header)
                labels = data.map { it[0] }
                ncols = same_width!(data)
                if ncols == 2
                    return Tessella.bar(labels,
                                        Columns.numeric(data, 1, "value"),
                                        **ChartOpts.for(opts))
                end
                Tessella.bar(labels, series_values(data, ncols),
                             series: header&.drop(1), **ChartOpts.for(opts))
            end

            def self.series_values(data, ncols)
                columns = (1...ncols).map do |i|
                    Columns.numeric(data, i, "value #{i}")
                end
                columns.transpose
            end

            # Every row as wide as the first: a short or long one is
            # refused rather than read in part.
            def self.same_width!(data)
                ncols = data.first.size
                i = data.index { it.size != ncols }
                return ncols unless i

                raise DataError, "row #{i + 1} has #{data[i].size} columns, " \
                                 "row 1 has #{ncols}"
            end

            def self.histogram(opts, data)
                samples = Columns.numeric(data, 0, "sample")
                Tessella.histogram(samples, **ChartOpts.for(opts))
            end
        end
    end

    # box: one or more columns, one box per column, named by the
    # header or 1..n (DESIGN.md's CLI input rules).
    class ChartCLI
        class BoxKind
            def self.build(opts, rows)
                header, data = Header.split(rows)
                ncols = (header || data.first).size
                names = header || (1..ncols).map(&:to_s)
                columns = (0...ncols).map do |i|
                    Columns.numeric(data, i, names[i])
                end
                Tessella.box(names, columns, **ChartOpts.for(opts))
            end
        end
    end

    # stem: one column, or two for the back-to-back form (DESIGN.md's
    # CLI input rules).
    class ChartCLI
        class StemKind
            def self.build(opts, rows)
                header, data = Header.split(rows)
                ncols = (header || data.first).size
                check_ncols!(ncols)
                values = Columns.numeric(data, 0, "value")
                other = ncols == 2 ? Columns.numeric(data, 1, "other") : nil
                Tessella.stem(values, other, **ChartOpts.for(opts))
            end

            def self.check_ncols!(ncols)
                return if ncols <= 2

                raise DataError, "stem takes one or two columns, got #{ncols}"
            end
        end
    end
end
