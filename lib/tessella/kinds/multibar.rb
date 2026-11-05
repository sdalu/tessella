# frozen_string_literal: true

module Tessella
    # Bars of several series (DESIGN.md, "Chart and kinds"): Bar#add
    # given an Array per label -- one value a series -- draws them
    # grouped, a bar per series under each label with a blank row
    # between labels, or stacked: true, the series end to end in one bar
    # labelled with its total. Series are told apart by fill glyph
    # (█ ▓ ▒, ASCII # = +) and, under color: true, by colour; the legend
    # sits right of the frame, named by series: (1..n otherwise). Values
    # must be 0 or more; the braille, block and half layouts refuse
    # several series. Kept apart so Bar stays under budget.
    module MultiBars
        FILLS = %w[█ ▓ ▒].freeze
        ASCII_FILLS = %w[# = +].freeze

        private

        def multi? = !@groups.nil?

        def add_multi(labels, rows)
            @groups ||= []
            rows.each_with_index do |values, i|
                vals = Check.finite!(Array(values), "value")
                check_series_size!(vals)
                @groups << [labels[i], vals]
            end
            self
        end

        def check_series_size!(vals)
            n = @groups.first&.last&.size || vals.size
            return if vals.size == n && n.positive?

            raise ArgumentError, "every label needs #{n} values, one a " \
                                 "series: got #{vals.size}"
        end

        def series_count = @groups.first.last.size

        def series_fill(i) = (@ascii ? ASCII_FILLS : FILLS)[i % FILLS.size]

        # Eighths (▏..▉, ▁..▇) are solid: they end only a █ series, so a
        # ▓ or ▒ bar is never closed by what looks like another series.
        def eighths_for?(fill) = @eighths && fill == FILLS.first
        def series_color(i) = Color::NAMES[i % Color::NAMES.size]

        def series_names
            names = Array(@opts[:series]).map(&:to_s)
            return names if names.size == series_count

            (1..series_count).map(&:to_s)
        end

        def legend
            series_names.each_with_index.to_h do |name, i|
                [i, "#{series_fill(i)} #{name}"]
            end
        end

        def multi_values!
            values = @groups.flat_map(&:last)
            return if values.all? { it >= 0 }

            raise ArgumentError, "bars of several series need values of " \
                                 "0 or more"
        end

        def multi_frame_options
            multi_values!
            unless @blocks == :eighths
                raise ArgumentError, "blocks: #{@blocks} draws one series"
            end
            return multi_column_options if @orientation == :vertical

            multi_row_options
        end
    end
end
