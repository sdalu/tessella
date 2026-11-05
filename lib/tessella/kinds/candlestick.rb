# frozen_string_literal: true

module Tessella
    # The x labels under a candlestick chart: the first and last x, as
    # dates when x holds times (xdate: or the span's format, as on a date
    # axis). Kept apart so Candlestick stays under budget.
    module CandleLabels
        private

        def x_label(value)
            return Axis.label(value) unless DateAxis.time?(value)

            Time.at(DateAxis.seconds(value)).utc.strftime(x_format)
        end

        def x_format
            return @opts[:xdate] if @opts[:xdate].is_a?(String)

            seconds = @x.map { DateAxis.seconds(it) }
            span = seconds.max - seconds.min
            DateAxis::SPANS.find { |least, _| span >= least }.last
        end
    end

    # Candlesticks (DESIGN.md, "Chart and kinds"): an open/high/low/
    # close series spread over width: (40 by default), each candle as
    # wide as its share of the width allows, a blank column between
    # candles -- a column each and no gap when they do not fit. The
    # wick │ runs from low to high in the candle's middle column; the
    # body from open to close fills the candle: █ for an up candle
    # (close at or above open), ▒ for a down one, ─ when open and close
    # share a row; under color: true up is green and down red. The
    # value axis is on the left, the first and last x under the frame.
    class Candlestick < Chart
        include CandleLabels

        OPTIONS = (Chart::OPTIONS - %i[canvas xscale xlim] +
                   %i[xdate]).freeze
        PRICES = %i[open high low close].freeze
        GLYPHS = { up: "█", down: "▒", flat: "─", wick: "│" }.freeze
        ASCII_GLYPHS = { up: "#", down: "=", flat: "-", wick: "|" }.freeze

        # x (1..n when nil), and the four prices as Arrays.
        def add(x = nil, **prices)
            values = price_values(prices)
            check_candles!(values)
            @x = Array(x || (1..values[0].size))
            Check.same_size!(@x, values[0], %w[x prices])
            @candles = values.transpose
            self
        end

        private

        def default_border = :box

        def price_values(prices)
            missing = PRICES - prices.keys
            raise ArgumentError, "missing #{missing.join(", ")}" if
                missing.any?

            PRICES.map { Check.finite!(Array(prices[it]), it.to_s) }
        end

        def check_candles!(values)
            same_length!(values)
            bad = values.transpose.index do |o, h, l, c|
                l > [o, c].min || h < [o, c].max
            end
            return unless bad

            raise ArgumentError, "candle #{bad + 1}: low and high must hold " \
                                 "open and close"
        end

        def same_length!(values)
            sizes = values.map(&:size).uniq
            return if sizes.size == 1 && sizes.first.positive?

            raise ArgumentError, "open, high, low and close must be Arrays " \
                                 "of one length"
        end

        def glyphs = @ascii ? ASCII_GLYPHS : GLYPHS

        def limits = Axis.limits(@candles.flatten, @opts[:ylim])

        def row_of(value, lo, hi)
            share = (hi - value).fdiv(hi - lo)
            (share * (height - 1)).round.clamp(0, height - 1)
        end

        def gap = (2 * @candles.size) - 1 <= width ? 1 : 0

        # Columns a candle: its share of the width, less the gap.
        def candle_width
            [((width + gap) / @candles.size) - gap, 1].max
        end

        def body
            lo, hi = limits
            rows = Array.new(height) { [] }
            @candles.each_with_index do |candle, i|
                rows.each { it << Cell.blank } if i.positive? && gap == 1
                column = candle_column(candle, lo, hi)
                rows.each_with_index { |row, r| row.concat(widen(column[r])) }
            end
            rows
        end

        # A cell across the candle's width: a body fills it, a wick
        # stays one column, in the middle.
        def widen(cell)
            cw = candle_width
            return Array.new(cw) { cell } unless cell.char == glyphs[:wick]

            Array.new(cw) { it == (cw - 1) / 2 ? cell : Cell.blank }
        end

        def candle_column(candle, lo, hi)
            open, high, low, close = candle
            up = close >= open
            top, bottom = [open, close].map { row_of(it, lo, hi) }.minmax
            color = up ? :green : :red
            (0...height).map do |r|
                candle_cell(r, [row_of(high, lo, hi), row_of(low, lo, hi)],
                            [top, bottom], [up, color])
            end
        end

        def candle_cell(row, wick, body, kind)
            up, color = kind
            if row.between?(*body)
                return Cell.new(char: body_glyph(body, up), color: color)
            end
            return Cell.blank unless row.between?(*wick)

            Cell.new(char: glyphs[:wick], color: color)
        end

        def body_glyph(body, up)
            return glyphs[:flat] if body[0] == body[1]

            glyphs[up ? :up : :down]
        end

        def frame = Frame.new(**candle_options)

        def candle_options
            lo, hi = limits
            { body: body, border: @border, ascii: @ascii, color: @color_on,
              title: @opts[:title], xlabel: @opts[:xlabel],
              ylabel: @opts[:ylabel],
              left: { 0 => Axis.tick(hi), (height - 1) => Axis.tick(lo) },
              bottom: [x_label(@x.first), x_label(@x.last)] }
        end
    end

    # (x = nil, open:, high:, low:, close:, **opts): a new Candlestick.
    def self.candlestick(x = nil, **opts)
        prices = opts.slice(*Candlestick::PRICES)
        Candlestick.new(**opts.except(*Candlestick::PRICES)).add(x, **prices)
    end
end
