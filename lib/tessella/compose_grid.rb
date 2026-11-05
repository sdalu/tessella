# frozen_string_literal: true

module Tessella
    # grid: figures in rows of columns: (DESIGN.md, "Blocks and
    # composition") -- the dashboard layout other libraries have, built
    # from beside and stack: each row's figures side by side, gap:
    # columns apart and aligned by align:, the rows stacked row_gap:
    # rows apart. A short last row stays short.
    module Compose
        GRID = { columns: 2, gap: 2, row_gap: 1, align: :top }.freeze

        # (*figures, columns: 2, gap: 2, row_gap: 1, align: :top,
        # ascii: false)
        def self.grid(*figures, ascii: Target.ascii?, **layout)
            raise ArgumentError, "grid takes one figure or more" if
                figures.empty?

            o = GRID.merge(layout)
            Check.positive_integer!(o[:columns], "columns")
            rows = blocks(figures, ascii).each_slice(o[:columns]).map do |row|
                grid_row(row, o, ascii)
            end
            return rows.first if rows.size == 1

            stack(*rows, gap: o[:row_gap], ascii: ascii)
        end

        def self.grid_row(row, o, ascii)
            return row.first if row.size == 1

            beside(*row, gap: o[:gap], align: o[:align], ascii: ascii)
        end
    end

    def self.grid(...) = Compose.grid(...)
end
