# frozen_string_literal: true

module Tessella
    # pie: label value, a row a slice, --donut for a ring (DESIGN.md's
    # CLI input rules). A pie has no axes: --width, --xlim, --ylim,
    # --canvas and --xscale are refused, --height sizes the disc.
    class ChartCLI
        class PieKind
            REFUSED = { width: "--width", xlim: "--xlim", ylim: "--ylim",
                        canvas: "--canvas", xscale: "--xscale" }.freeze

            def self.build(opts, rows)
                refuse!(opts)
                _header, data = Header.split(rows, bar_like: true)
                two!(data)
                Tessella.pie(data.map(&:first),
                             Columns.numeric(data, 1, "value"),
                             **ChartOpts.for(opts).except(*REFUSED.keys))
            end

            def self.refuse!(opts)
                key = REFUSED.keys.find { opts.key?(it) }
                return unless key

                raise UsageError, "#{REFUSED[key]} is not valid with --kind pie"
            end

            def self.two!(data)
                i = data.index { it.size != 2 }
                return unless i

                raise DataError, "row #{i + 1} has #{data[i].size} columns: " \
                                 "pie reads label value"
            end
        end
    end
end
