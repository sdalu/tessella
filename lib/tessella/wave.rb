# frozen_string_literal: true

module Tessella
    # A timing diagram from WaveDrom-like signal text (DESIGN.md): one
    # signal per line, "name: wave" in WaveDrom's alphabet (0 low, 1
    # high, p positive clock, n negative clock, x unknown, z high
    # impedance, = a bus value, . repeat the previous state), with an
    # optional "| label label ..." naming the bus values in order and
    # a lone "---" line drawing an empty separator row. Ported from
    # the ascii-art skill's scripts/wave.rb; Tessella.wave is the
    # entry point, at the bottom of this file.
    module Wave
        ALPHABET = ".01pnxz=".chars.freeze

        # One input line -> a WaveSignal, :separator, or nil (blank).
        WaveSignal = Struct.new(:name, :wave, :labels, :lineno)

        # One rendered cell: a level, its column width, the bus label
        # (if any), the state it follows, and whether its own first
        # column is a boundary (edge/tick/marker) rather than fill.
        Segment = Struct.new(:kind, :width, :label, :prev_kind, :boundary)

        def self.build(text, period:, ascii:, ruler:)
            check_period!(period)
            diagram = Diagram.parse(text, period, ascii, ruler)
            Block.new(diagram.rows)
        end

        def self.check_period!(period)
            return if period.is_a?(Integer) && period >= 2

            raise ArgumentError,
                  "period must be an Integer >= 2: #{period.inspect}"
        end
    end

    # One input line -> a WaveSignal, :separator, or nil (a blank
    # line); every refusal names the line it is about.
    module Wave
        class LineParser
            def self.parse(line, lineno)
                text = line.strip
                return nil if text.empty?
                return :separator if text == "---"

                new(text, lineno).signal
            end

            def initialize(text, lineno)
                @text = text
                @lineno = lineno
            end

            def signal
                name, rest = split_name
                wave, labels = split_wave(rest)
                validate(wave)
                Wave::WaveSignal.new(name, wave, labels, @lineno)
            end

            private

            def split_name
                idx = @text.index(":")
                raise ArgumentError, "line #{@lineno}: missing ':'" unless idx

                name = @text[0...idx].strip
                if name.empty?
                    raise ArgumentError, "line #{@lineno}: empty signal name"
                end

                [name, @text[(idx + 1)..].strip]
            end

            def split_wave(rest)
                wave_part, _, label_part = rest.partition("|")
                wave = wave_part.gsub(/\s+/, "")
                if wave.empty?
                    raise ArgumentError,
                          "line #{@lineno}: empty wave"
                end

                [wave, label_part.strip.split]
            end

            def validate(wave)
                bad = wave.chars.reject { Wave::ALPHABET.include?(it) }.uniq
                return if bad.empty?

                raise ArgumentError,
                      "line #{@lineno}: unknown wave character " \
                      "#{bad.join(",")}"
            end
        end
    end

    # Wave characters -> Segments, resolving "." continuation,
    # splitting a clock char into its rise/fall halves, and merging a
    # "=" with the "." that follow it into one labelled bus run.
    module Wave
        class SegmentBuilder
            CHAR_KIND = { "0" => :low, "1" => :high, "x" => :unknown,
                          "z" => :hiz }.freeze

            def initialize(wave, labels, period)
                @chars = wave.chars
                @labels = labels.dup
                @period = period
                @prev = nil
                @clock = nil
            end

            def segments
                result = []
                i = 0
                i = step(result, i) while i < @chars.length
                unless @labels.empty?
                    raise ArgumentError,
                          "too many labels for '='"
                end

                result
            end

            private

            def step(result, i)
                c = @chars[i]
                return bus_run(result, i) if c == "="
                return i + 1 if advance?(result, c)

                raise ArgumentError, "unknown wave character #{c.inspect}"
            end

            def advance?(result, c)
                case c
                when "0", "1", "x", "z"
                    result << flat(CHAR_KIND.fetch(c), @period)
                    @clock = nil
                when "." then result.concat(repeat)
                when "p" then result.concat(pulse(:high, :low, :p))
                when "n" then result.concat(pulse(:low, :high, :n))
                else return false
                end
                true
            end

            def flat(kind, width)
                seg = Wave::Segment.new(kind, width, nil, @prev, edge?(kind))
                @prev = kind
                seg
            end

            def edge?(kind)
                return false if @prev.nil? || %i[unknown hiz].include?(kind)

                kind != @prev
            end

            # "." repeats whatever the previous character did: another
            # full cycle for a clock (its own rise and fall), a flat hold
            # at the same level for anything else.
            def repeat
                raise ArgumentError, "'.' with no previous state" unless @prev
                return pulse(:high, :low, :p) if @clock == :p
                return pulse(:low, :high, :n) if @clock == :n

                [Wave::Segment.new(@prev, @period, nil, @prev, false)]
            end

            def pulse(first, second, clock)
                halves = [@period / 2, @period - (@period / 2)]
                segs = [flat(first, halves[0]), flat(second, halves[1])]
                @clock = clock
                segs
            end

            def bus_run(result, i)
                label = @labels.shift
                raise ArgumentError, "not enough labels for '='" unless label
                steps = 1
                steps += 1 while @chars[i + steps] == "."
                width = steps * @period
                boundary = !@prev.nil?
                check_fit(label, width - (boundary ? 1 : 0))
                result << Wave::Segment.new(:bus, width, label, @prev, boundary)
                @prev = :bus
                i + steps
            end

            def check_fit(label, width)
                return if Width.of(label) <= width

                raise ArgumentError,
                      "label #{label.inspect} does not fit in " \
                      "#{width} columns"
            end
        end
    end

    # Segments -> the two printed rows (top: the high line; bottom:
    # the low line, the bus baseline, and the name). One glyph table
    # per mode.
    module Wave
        class RowRenderer
            FILL = {
                unicode: { low: "─", high: "─", unknown: "▒", hiz: "┄",
                           bus: "─" },
                ascii: { low: "_", high: "_", unknown: "x", hiz: "-", bus: "_" }
            }.freeze

            def initialize(ascii)
                @ascii = ascii
                @fill = ascii ? FILL[:ascii] : FILL[:unicode]
            end

            def render(segments)
                pairs = segments.map { cell(it) }
                [pairs.map(&:first).join, pairs.map(&:last).join]
            end

            private

            def cell(seg)
                lead = seg.boundary ? 1 : 0
                top, bot = fill(seg, seg.width - lead)
                return [top, bot] unless seg.boundary

                mtop, mbot = marker(seg)
                [mtop + top, mbot + bot]
            end

            def fill(seg, width)
                case seg.kind
                when :low  then [" " * width, @fill[:low] * width]
                when :high then [@fill[:high] * width, " " * width]
                when :unknown, :hiz
                    band = @fill[seg.kind] * width
                    [band, band]
                when :bus then [" " * width, bus_label(seg.label, width)]
                end
            end

            def bus_label(label, width)
                gap = width - Width.of(label)
                f = @fill[:bus]
                (f * (gap / 2)) + label + (f * (gap - (gap / 2)))
            end

            def marker(seg)
                return bus_marker if seg.kind == :bus || seg.prev_kind == :bus
                return vertical_marker if
                    %i[unknown hiz].include?(seg.prev_kind)

                edge_marker(seg)
            end

            def bus_marker = @ascii ? [" ", "X"] : %w[╳ ╳]

            def vertical_marker = @ascii ? [" ", "|"] : %w[│ │]

            def edge_marker(seg)
                return vertical_marker if @ascii

                seg.kind == :high ? %w[┌ ┘] : %w[┐ └]
            end
        end
    end

    # The whole figure: every signal's two rows (never rstripped --
    # Block does that), a blank line between any two consecutive
    # entries (a "---" entry has no rows of its own, so it reads as
    # one extra blank), and an optional ruler row at the end.
    module Wave
        class Diagram
            def self.parse(text, period, ascii, ruler)
                entries = text.each_line.with_index(1).filter_map do |line, n|
                    Wave::LineParser.parse(line, n)
                end
                if entries.grep(Wave::WaveSignal).empty?
                    raise ArgumentError, "no signal lines"
                end

                new(entries, period, ascii, ruler)
            end

            def initialize(entries, period, ascii, ruler)
                @entries = entries
                @period = period
                @ascii = ascii
                @ruler = ruler
                widths = entries.grep(Wave::WaveSignal).map { Width.of(it.name) }
                @name_width = widths.max || 0
            end

            def rows
                @rows ||= build_rows
            end

            private

            def build_rows
                rows = []
                @entries.each_with_index do |e, i|
                    rows << "" if i.positive?
                    rows.concat(body(e))
                end
                rows.concat(ruler_rows) if @ruler
                rows
            end

            def body(entry)
                return [] if entry == :separator

                top, bot = render_wave(entry)
                [pad(nil) + top, pad(entry.name) + bot]
            end

            def render_wave(entry)
                builder = Wave::SegmentBuilder.new(entry.wave, entry.labels,
                                                   @period)
                Wave::RowRenderer.new(@ascii).render(builder.segments)
            rescue ArgumentError => e
                raise ArgumentError, "line #{entry.lineno}: #{e.message}"
            end

            def ruler_rows
                steps = @entries.grep(Wave::WaveSignal)
                                .map { it.wave.length }.max || 0
                line = (0...steps).map { it.to_s.ljust(@period) }.join
                ["", pad(nil) + line]
            end

            def pad(name)
                text = name ? Width.ljust(name, @name_width) : " " * @name_width
                "#{text} "
            end
        end
    end

    def self.wave(text, period: 4, ascii: false, ruler: false)
        Wave.build(text, period: period, ascii: ascii, ruler: ruler)
    end
end
