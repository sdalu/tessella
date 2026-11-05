# frozen_string_literal: true

module Tessella
    # heatmap: a row a label then its values; a first row whose values
    # are not numbers names the columns (DESIGN.md's CLI input rules).
    # Every row as wide as the first.
    class ChartCLI
        class HeatKind
            def self.build(opts, rows)
                header, data = Header.split(rows, bar_like: true)
                ncols = BarKind.same_width!(data)
                values = (1...ncols).map do |i|
                    Columns.numeric(data, i, "value #{i}")
                end
                Tessella.heatmap(values.transpose, ylabels: data.map(&:first),
                                                   xlabels: header&.drop(1),
                                                   **ChartOpts.for(opts))
            end
        end
    end
end
