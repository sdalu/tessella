# frozen_string_literal: true

module Tessella
    # Stacked bars under color: true, to the eighth: where one series
    # ends inside a cell and the next goes on, the cell is an eighths
    # glyph (▏..▉ across, ▁..▇ up) inked in the first series' colour on
    # the next one's background, so the boundary falls between whole
    # cells no more. Without colour the two halves of such a cell could
    # not be told apart, so the boundary stays on a whole cell there.
    module MultiBarFine
        private

        def fine? = @color_on && @eighths

        # A horizontal stacked row: cells to the total's last eighth.
        def fine_row(vals, scale)
            max, area, ew = scale
            ends = fine_ends(vals, max, area)
            full, rem = ends.last.divmod(8)
            cells = (0...(full + (rem.zero? ? 0 : 1))).map do |col|
                fine_cell(ends, col * 8, Bar::EIGHTHS)
            end
            finish_row(cells, [full, rem.zero? ? nil : true, area],
                       vals.sum, ew)
        end

        # Each series' cumulative end, in eighths of a cell.
        def fine_ends(vals, max, area)
            vals.each_index.map do |i|
                (share(vals[0..i].sum, max) * area * 8).round
            end
        end

        # The cell from eighth lo: the series covering lo, whole when it
        # covers the cell, else split with the series after it.
        def fine_cell(ends, low, glyphs)
            a = ends.index { it > low }
            return cell(series_fill(a), series_color(a)) if ends[a] >= low + 8

            b = ends.index { it > ends[a] }
            colors = b ? [series_color(a), series_color(b)] : series_color(a)
            cell(glyphs[ends[a] - low], colors)
        end
    end
end
