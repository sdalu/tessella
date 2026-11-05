# frozen_string_literal: true

module Inkchart
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

    # Horizontal bars for (label, value) pairs (DESIGN.md, "Chart and
    # kinds"): rows of cells laid out directly, one per bar, not on a
    # pixel canvas, handed to Frame with border :bar -- as
    # unicode_plot's barplot frame. Chart lends option checking and
    # ascii/colour handling; its canvas and draw_series go unused.
    class Bar < Chart
        include BarCells

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
            Array(labels).zip(Array(values)).each do |label, value|
                @bars << [label, value, bar_color]
            end
            self
        end

        private

        def default_border = :bar
        def default_xlabel_basename = ""

        def check_options!(opts)
            unknown = opts.keys - OPTIONS
            return if unknown.empty?

            raise ArgumentError,
                  "unknown option: #{unknown.map(&:inspect).join(", ")}"
        end

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
