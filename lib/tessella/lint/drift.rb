# frozen_string_literal: true

module Tessella
    module Lint
        # A vertical anchor (a lifeline, a box edge) one column off on a
        # row or two. Per figure, the rows carrying a vertical at each
        # display column are counted: a column used by few rows, beside
        # one used by many, with no row using both, is a drifted anchor
        # rather than a second one. Boxes of different widths share no
        # such neighbour, and a double line (││) has rows using both.
        module Drift
            MIN_ROWS = 4
            RATIO = 3

            # A Markdown pipe table's separator row: such a paragraph is
            # not a figure, its pipes need not line up in the source.
            MD_TABLE_SEP = /\A\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*\z/

            private

            def check_anchor_drift(sec)
                group = []
                sec.lines.each_with_index do |line, i|
                    if line.strip.empty?
                        flag_anchor_drift(sec, group)
                        group = []
                    else
                        group << [i, line]
                    end
                end
                flag_anchor_drift(sec, group)
            end

            def flag_anchor_drift(sec, group)
                return unless drift_figure?(group)

                rows = vertical_rows(group)
                return if rows.length < MIN_ROWS

                count = rows.flat_map(&:last).tally
                count.default = 0
                count.keys.sort.each do |c|
                    anchor = drift_anchor(rows, count, c)
                    report_drift(sec, rows, count, [c, anchor]) if anchor
                end
            end

            # [index, its distinct vertical columns] per row that has any.
            def vertical_rows(group)
                group.map { |i, line| [i, vertical_columns(line).uniq] }
                     .reject { |_, cols| cols.empty? }
            end

            def drift_figure?(group)
                group.any? do |_, line|
                    bare = line.gsub(INLINE_CODE, "")
                    bare.match?(BOX_CHAR) || Mixing.ascii_structural?(bare)
                end && group.none? { |_, line| line.match?(MD_TABLE_SEP) }
            end

            def drift_anchor(rows, count, col)
                [col - 1, col + 1].find do |d|
                    count[d] >= MIN_ROWS && count[d] >= RATIO * count[col] &&
                        rows.none? do |_, cols|
                            cols.include?(col) && cols.include?(d)
                        end
                end
            end

            def report_drift(sec, rows, count, pair)
                col, anchor = pair
                bad = rows.select { |_, cols| cols.include?(col) }
                          .map { |i, _| sec.first + i }
                report(sec, bad.first - sec.first,
                       "vertical at column #{col} on #{bad.length} row(s) " \
                       "(#{bad.join(",")}) beside the figure's anchor at " \
                       "column #{anchor} (#{count[anchor]} rows) -- one " \
                       "column off?")
            end
        end
    end
end
