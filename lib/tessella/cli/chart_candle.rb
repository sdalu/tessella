# frozen_string_literal: true

module Tessella
    # candlestick: x open high low close, a row a candle; x an ISO 8601
    # date under --xdate (DESIGN.md's CLI input rules).
    class ChartCLI
        class CandleKind
            FIELDS = %w[open high low close].freeze

            def self.build(opts, rows)
                _header, data = Header.split(rows, bar_like: true)
                five!(data)
                x = opts[:xdate] ? Columns.times(data, 0) : x_values(data)
                prices = FIELDS.each_with_index.to_h do |name, i|
                    [name.to_sym, Columns.numeric(data, i + 1, name)]
                end
                Tessella.candlestick(x, **prices, **ChartOpts.for(opts))
            end

            def self.five!(data)
                i = data.index { it.size != 5 }
                return unless i

                raise DataError, "row #{i + 1} has #{data[i].size} columns: " \
                                 "candlestick reads x open high low close"
            end

            # x as numbers when every one is, else as given (labels).
            def self.x_values(data)
                xs = data.map(&:first)
                numbers = xs.map { Num.parse(it) }
                numbers.all? ? numbers : xs
            end
        end
    end
end
