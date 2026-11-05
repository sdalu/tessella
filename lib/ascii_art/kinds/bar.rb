# frozen_string_literal: true

module AsciiArt
    # Building one bar's row of cells: the fill run, the optional
    # eighths partial cell, the track run, the value label, padding.
    # Kept apart from Bar so Bar's own class body stays under budget.
    module BarCells
        EIGHTHS = " ▏▎▍▌▋▊▉".chars.freeze

        private

        def cell(char, color = nil) = Cell.new(char: char, color: color)

        def bar_fraction(value, max_val)
            return 0.0 unless max_val.positive?

            [@xscale.call(value), 0].max.fdiv(max_val)
        end

        def bar_glyphs(fraction, max_bar_width)
            return [(fraction * max_bar_width).round, nil] unless @eighths

            units = (fraction * max_bar_width * 8).round
            full, rem = units.divmod(8)
            [full, rem.zero? ? nil : EIGHTHS[rem]]
        end

        def bar_cells(full, partial, color)
            cells = Array.new(full) { cell(@fill, color) }
            cells << cell(partial, color) if partial
            cells
        end

        def middle_cells(full, partial, max_bar_width)
            return [] unless @track

            used = full + (partial ? 1 : 0)
            remain = max_bar_width - used
            remain.positive? ? Array.new(remain) { cell(@track) } : []
        end

        def label_cells(value)
            Axis.label(value).each_char.map { |ch| cell(ch) }
        end

        def pad_cells(cells, ew)
            pad = [ew - cells.length, 0].max
            cells + Array.new(pad) { Cell.blank }
        end
    end

    # Bars over values of both signs: the bar area splits at a zero
    # column into a negative zone and a positive one, each as wide as
    # its share of the data's span; negative bars grow left from zero,
    # positive ones right, and the value labels follow the whole area,
    # so zero is one column on every row. Without a negative value Bar
    # keeps unicode_plot's layout. A negative bar's fractional end, at
    # its left, is a right half block (Unicode has no right eighths).
    module SignedBars
        RIGHT_HALF = "▐"

        private

        def signed? = @bars.any? { |_, value, _| @xscale.call(value).negative? }

        def signed_rows
            values = @bars.map { |_, value, _| @xscale.call(value) }
            max_len = signed_label_width
            ew = effective_width(max_len)
            zones = signed_zones(values, [ew - 2 - max_len, 1].max)
            @bars.each_with_index.map do |(_, value, color), i|
                signed_row(values[i], value, color, zones, ew)
            end
        end

        # scaled places the bar, value (as given) labels it.
        def signed_row(scaled, value, color, zones, ew)
            cells = signed_cells(scaled, color, zones)
            pad_cells(cells + [Cell.blank] + label_cells(value), ew)
        end

        # Every label, not only the largest value's: "-12.5" can be the
        # widest, and each row must end at the same column.
        def signed_label_width
            @bars.map { |_, value, _| Axis.label(value).length }.max
        end

        def signed_zones(values, area)
            neg = -values.min
            pos = [values.max, 0].max
            neg_w = (area * neg.fdiv(neg + pos)).round
            [neg_w, area - neg_w, neg, pos]
        end

        def signed_cells(value, color, zones)
            neg_w, pos_w, neg, pos = zones
            return left_bar(-value.fdiv(neg), neg_w, color) + gap(pos_w) if
                value.negative?

            fraction = pos.positive? ? value.fdiv(pos) : 0.0
            gap(neg_w) + right_bar(fraction, pos_w, color)
        end

        def left_bar(fraction, width, color)
            full, half = left_glyphs(fraction, width)
            gap(width - full - half) +
                Array.new(half) { cell(RIGHT_HALF, color) } +
                Array.new(full) { cell(@fill, color) }
        end

        def left_glyphs(fraction, width)
            return [(fraction * width).round, 0] unless @eighths

            (fraction * width * 2).round.divmod(2)
        end

        def right_bar(fraction, width, color)
            cells = bar_cells(*bar_glyphs(fraction, width), color)
            cells + gap(width - cells.size)
        end

        def gap(count)
            Array.new([count, 0].max) { @track ? cell(@track) : Cell.blank }
        end
    end

    # Horizontal bars for (label, value) pairs (DESIGN.md, "Chart and
    # kinds"): rows of cells laid out directly, one per bar, not on a
    # pixel canvas, handed to Frame with border :bar -- as
    # unicode_plot's barplot frame. Chart lends option checking and
    # ascii/colour handling; its canvas and draw_series go unused.
    class Bar < Chart
        include BarCells
        include SignedBars

        OPTIONS = (Chart::OPTIONS + %i[fill eighths track]).freeze
        MIN_WIDTH = 10
        DEFAULT_FILL = "█"
        ASCII_FILL = "#"
        DEFAULT_TRACK = "·"
        ASCII_TRACK = "."

        def initialize(**opts)
            super
            @fill = fill_option(opts)
            @eighths = @ascii ? false : opts.fetch(:eighths, true)
            @track = track_option(opts)
            @bars = []
        end

        def add(labels, values, color: nil)
            bar_color = color || auto_color
            labels = Array(labels)
            values = Check.finite!(Array(values), "value")
            Check.same_size!(labels, values, %w[labels values])
            labels.zip(values).each do |label, value|
                @bars << [label, value, bar_color]
            end
            self
        end

        private

        def default_border = :bar
        def default_xlabel_basename = ""

        def fill_option(opts)
            fill = opts[:fill] || (@ascii ? ASCII_FILL : DEFAULT_FILL)
            if fill.length != 1
                raise ArgumentError,
                      "fill must be one character: #{fill.inspect}"
            end
            fill
        end

        def track_option(opts)
            return opts[:track] if opts.key?(:track)

            @ascii ? ASCII_TRACK : DEFAULT_TRACK
        end

        def frame
            Frame.new(**frame_options)
        end

        def frame_options
            { body: rows, border: @border, ascii: @ascii, color: @color_on,
              title: @opts[:title], xlabel: xlabel, ylabel: @opts[:ylabel],
              left: left_labels }
        end

        def xlabel
            @opts[:xlabel] || auto_xlabel
        end

        def auto_xlabel
            xscale = @opts[:xscale]
            base = default_xlabel_basename
            return base.empty? ? nil : base unless xscale

            "#{base} [#{xscale}]"
        end

        def left_labels
            @bars.each_with_index.to_h { |(label, *), i| [i, label.to_s] }
        end

        def reference
            return [0.0, 0] if @bars.empty?

            transformed = @bars.map { |_, value, _| @xscale.call(value) }
            max_val = transformed.max
            idx = transformed.index(max_val)
            [max_val, Axis.label(@bars[idx][1]).length]
        end

        def effective_width(max_len)
            [width, max_len + 7, MIN_WIDTH].max
        end

        def rows
            return signed_rows if signed?

            max_val, max_len = reference
            ew = effective_width(max_len)
            @bars.map do |_, value, color|
                bar_row(value, color, max_val, max_len, ew)
            end
        end

        def bar_row(value, color, max_val, max_len, ew)
            max_bar_width = [ew - 2 - max_len, 1].max
            fraction = bar_fraction(value, max_val)
            full, partial = bar_glyphs(fraction, max_bar_width)
            cells = bar_cells(full, partial, color)
            cells += middle_cells(full, partial, max_bar_width)
            cells << Cell.blank
            cells += label_cells(value)
            pad_cells(cells, ew)
        end
    end

    # Frequency bars over Stats.histogram's bins (DESIGN.md): the same
    # engine as Bar, fed bin labels and counts instead of given ones.
    class Histogram < Bar
        def add(values, bins: nil, closed: :left, color: nil)
            values = Check.finite!(Array(values), "value")
            hist = Stats.histogram(values, bins: bins, closed: closed)
            super(bin_labels(hist), hist.counts, color: color)
        end

        private

        def default_xlabel_basename = "Frequency"

        def bin_labels(hist)
            pairs = edge_pairs(hist)
            pad = label_padding(pairs.flatten)
            lb, rb = hist.closed == :right ? ["(", "]"] : ["[", ")"]
            pairs.first(hist.counts.size).map do |lo, hi|
                "#{lb}#{pad_num(lo, pad)}, #{pad_num(hi, pad)}#{rb}"
            end
        end

        def edge_pairs(hist)
            edges = hist.edges
            step = edges.size > 1 ? edges[1] - edges[0] : 1.0
            edges.map { |e| bin_pair(e, step) }
        end

        def bin_pair(edge, step)
            lo = round_edge(edge, step)
            [lo, round_edge(lo + step, step)]
        end

        def round_edge(value, step)
            digits = round_digits(step)
            if value.negative?
                (-(-value).round(digits)).to_f
            else
                value.round(digits).to_f
            end
        end

        def round_digits(step)
            return 1 if step.zero?

            v = -Math.log10(step)
            (v == v.to_i ? v.ceil : v.floor) + 1
        end

        def label_padding(values)
            parts = values.map { |v| v.to_s.split(".", 2) }
            [parts.map { |a| a[0].length }.max,
             parts.map { |a| (a[1] || "").length }.max]
        end

        def pad_num(value, pad)
            left, right = pad
            whole, frac = value.to_s.split(".", 2)
            (" " * (left - whole.length)) + value.to_s +
                (" " * (right - frac.length))
        end
    end

    # (labels, values, **opts): a new Bar chart with one set of bars.
    def self.bar(*, **)
        Bar.new(**).add(*)
    end

    # (values, bins: nil, closed: :left, **opts): a histogram over
    # Stats.histogram's bins.
    def self.histogram(values, bins: nil, closed: :left, **)
        Histogram.new(**).add(values, bins: bins, closed: closed)
    end
end
