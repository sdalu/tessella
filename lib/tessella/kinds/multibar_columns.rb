# frozen_string_literal: true

module Tessella
    # Columns of several series (MultiBars): side by side in each
    # label's slot, or stacked into one column; the value axis runs
    # from 0 to the largest value, or total.
    module MultiBarColumns
        private

        def multi_column_options
            body, slot, top = multi_columns
            { body: body, border: :box, ascii: @ascii, color: @color_on,
              title: @opts[:title], xlabel: @opts[:xlabel],
              ylabel: @opts[:ylabel] || column_value_label,
              left: { (body.size - 1) => "0", 0 => Axis.label(top) },
              right: legend, **group_names(slot) }
        end

        def multi_columns
            @opts[:stacked] ? stacked_columns : grouped_columns
        end

        # [gap, column width]: a blank column between groups when the
        # width allows, the rest shared between all the columns.
        def group_geometry
            g = @groups.size
            n = series_count
            gap = (g * n) + g - 1 <= width ? 1 : 0
            [gap, [(width - ((g - 1) * gap)) / (g * n), 1].max]
        end

        def grouped_columns
            gap, cw = group_geometry
            max = @groups.flat_map(&:last).max
            rows = Array.new(column_height) { [] }
            @groups.each_with_index do |(_, vals), gi|
                blank_columns(rows, gi.zero? ? 0 : gap)
                vals.each_with_index do |v, i|
                    grouped_column(rows, v, i, [max, cw])
                end
            end
            [rows, (series_count * cw) + gap, max]
        end

        def grouped_column(rows, value, index, scale)
            max, cw = scale
            fill = series_fill(index)
            units = column_units(share(value, max.to_f), value, fill)
            append_column(rows, units, cw, series_color(index), fill)
        end

        # Eighths of a cell for a █ series, whole cells for the others.
        def column_units(fraction, value, fill)
            units = rise_units(fraction, value)
            eighths_for?(fill) ? units : ((units + 4) / 8) * 8
        end

        def stacked_columns
            gap, cw = rise_geometry(@groups.size)
            max = @groups.map { it.last.sum }.max
            rows = Array.new(column_height) { [] }
            @groups.each_with_index do |(_, vals), gi|
                blank_columns(rows, gi.zero? ? 0 : gap)
                stacked_column(rows, vals, max.to_f, cw)
            end
            [rows, cw + gap, max]
        end

        def stacked_column(rows, vals, max, cw)
            heights = stack_heights(vals, max)
            rows.each_with_index do |row, r|
                level = (column_height - 1 - r) * 8
                glyph = stack_cell(heights, level, vals.size)
                row.concat(Array.new(cw) { glyph })
            end
        end

        # [total, the cumulative top of each series], in eighths.
        def stack_heights(vals, max)
            top = series_fill(vals.size - 1)
            total = column_units(share(vals.sum, max), vals.sum, top)
            ends = vals.each_index.map do |i|
                rise_units(share(vals[0..i].sum, max), vals[0..i].sum)
            end
            [total, ends]
        end

        # Whole cells take the series at their middle; the top cell's
        # eighths take the last series' colour.
        def stack_cell(heights, level, count)
            total, ends = heights
            return Cell.blank unless total > level
            if total < level + 8
                return Cell.new(char: ColumnBars::RISE[total - level],
                                color: series_color(count - 1))
            end

            s = ends.index { level + 4 < it } || (count - 1)
            Cell.new(char: series_fill(s), color: series_color(s))
        end

        def group_names(slot)
            names = @groups.map { it.first.to_s }
            return { bottom: [names.first, names.last] } unless
                names.all? { Width.of(it) <= slot }

            { under: names.map { Width.center(it, slot) }.join.rstrip }
        end
    end
end
