# frozen_string_literal: true

module Tessella
    # Horizontal bars of several series (MultiBars): grouped rows, a
    # blank row between labels, or stacked rows labelled with totals.
    module MultiBarRows
        private

        def multi_row_options
            ew = effective_width(multi_labels.map(&:length).max)
            area = [ew - 2 - multi_labels.map(&:length).max, 1].max
            rows, left = multi_rows(area, ew)
            { body: rows, border: @border, ascii: @ascii, color: @color_on,
              title: @opts[:title], xlabel: xlabel, ylabel: @opts[:ylabel],
              left: left, right: legend }
        end

        def multi_rows(area, ew)
            @opts[:stacked] ? stacked_rows(area, ew) : grouped_rows(area, ew)
        end

        # The value labels a bar ends with: each value, or each total.
        def multi_labels
            return @groups.map { Axis.label(it.last.sum) } if @opts[:stacked]

            @groups.flat_map { |_, vals| vals.map { Axis.label(it) } }
        end

        def grouped_rows(area, ew)
            scale = [@groups.flat_map(&:last).max.to_f, area, ew]
            rows = []
            left = {}
            @groups.each_with_index do |(label, vals), g|
                rows << pad_cells([], ew) if g.positive?
                left[rows.size] = label.to_s
                vals.each_with_index { |v, i| rows << series_row(v, i, scale) }
            end
            [rows, left]
        end

        def series_row(value, index, scale)
            max, area, ew = scale
            full, partial = series_glyphs(share(value, max), area, index)
            color = series_color(index)
            cells = Array.new(full) { cell(series_fill(index), color) }
            cells << cell(partial, color) if partial
            finish_row(cells, [full, partial, area], value, ew)
        end

        # The track after the bar, a blank, the value, padding.
        def finish_row(cells, bar, value, ew)
            cells += middle_cells(*bar)
            pad_cells(cells + [Cell.blank] + label_cells(value), ew)
        end

        def series_glyphs(fraction, area, index)
            return bar_glyphs(fraction, area) if
                eighths_for?(series_fill(index))

            [(fraction * area).round, nil]
        end

        def stacked_rows(area, ew)
            scale = [@groups.map { it.last.sum }.max.to_f, area, ew]
            rows = @groups.map { |_, vals| stacked_row(vals, scale) }
            [rows, @groups.each_with_index.to_h { |(l, _), i| [i, l.to_s] }]
        end

        # Each series runs to the cell its cumulative share reaches; the
        # total's eighths end the bar in the last series' colour.
        def stacked_row(vals, scale)
            max, area, ew = scale
            last = vals.size - 1
            full, partial = series_glyphs(share(vals.sum, max), area, last)
            ends = cumulative_ends(vals, max, area, full)
            cells = (0...full).map { segment_cell(ends, it) }
            cells << cell(partial, series_color(last)) if partial
            finish_row(cells, [full, partial, area], vals.sum, ew)
        end

        def cumulative_ends(vals, max, area, full)
            sums = vals.each_index.map { vals[0..it].sum }
            sums.map { (share(it, max) * area).round.clamp(0, full) }
        end

        def segment_cell(ends, col)
            s = ends.index { col < it } || (ends.size - 1)
            cell(series_fill(s), series_color(s))
        end
    end
end
