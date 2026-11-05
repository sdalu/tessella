# frozen_string_literal: true

module Tessella
    module Lint
        # Drop shadows: ░ (U+2591) one column right of a frame on every
        # row but the first, and a bottom bar one row down, from one
        # column in to the shadow column. The slips are a shadow on the
        # closing row only and a bar one cell short; both look fine a
        # line at a time. Only a frame that already carries a shadow is
        # inspected: ░ as fill never sits against a box-drawing edge.
        module Shadows
            SHADOW = "░"
            TOP_LEFT = "┌┏╔╭┎┍"
            BOT_LEFT = "└┗╚╰┖┕"
            SHADOW_TAIL = /#{SHADOW}+\z/
            SHADOW_BAR = /\A *#{SHADOW}+\z/

            private

            def check_shadows(sec)
                row = 0
                row = shadow_at(sec, row) while row < sec.lines.length
            end

            # The row to resume from: past a shadowed frame opened at
            # row, once checked, or the next row.
            def shadow_at(sec, row)
                span = frame_span(sec.lines, row)
                return row + 1 unless span&.any? { shadow_tail?(sec.lines[it]) }

                check_shadow_geometry(sec, span)
                span.last + 1
            end

            # Rows top..bottom of the frame opened at top, or nil: the
            # run ends at the first row whose left edge is a bottom-left
            # corner in the same display column.
            def frame_span(lines, top)
                left = left_edge(lines[top])
                return nil unless left && TOP_LEFT.include?(left[0])

                ((top + 1)...lines.length).each do |i|
                    edge = left_edge(lines[i])
                    return nil unless edge && edge[1] == left[1]
                    return top..i if BOT_LEFT.include?(edge[0])
                end
                nil
            end

            # [first non-blank char, its display column], or nil.
            def left_edge(line)
                indent = line[/\A */]
                return nil if indent.length == line.length

                [line[indent.length], @overhead + indent.length + 1]
            end

            # A shadow cell hanging off a box-drawing edge; a run wider
            # than one cell is a column error, left to the geometry.
            def shadow_tail?(line)
                rest = unshadowed(line)
                rest.length < line.length && rest[-1].to_s.match?(BOX_CHAR)
            end

            def unshadowed(line) = line.sub(SHADOW_TAIL, "")

            def check_shadow_geometry(sec, span)
                top = sec.lines[span.first]
                if shadow_tail?(top)
                    report(sec, span.first, "drop shadow on the frame's " \
                                            "top row (offset it one row " \
                                            "down)")
                end
                # Off the frame edge, so a stray top-row shadow does not
                # drag the reference column with it.
                col = end_column(unshadowed(top)) + 1
                span.drop(1).each { check_shadow_row(sec, it, col) }
                check_shadow_bar(sec, span, col)
            end

            def check_shadow_row(sec, i, col)
                line = sec.lines[i]
                unless shadow_tail?(line)
                    return report(sec, i, "row has no drop shadow at " \
                                          "column #{col}")
                end
                actual = end_column(line)
                return if actual == col

                report(sec, i, "drop shadow at column #{actual}, frame's " \
                               "is at #{col}")
            end

            # The bar runs from one column right of the frame's left
            # edge to the shadow column, so the L closes on both ends.
            def check_shadow_bar(sec, span, col)
                bar = sec.lines[span.last + 1]
                unless bar&.match?(SHADOW_BAR)
                    return report(sec, span.last,
                                  "drop shadow has no bottom bar")
                end
                left = left_edge(sec.lines[span.first])[1]
                check_bar_ends(sec, span.last + 1, bar, [left + 1, col])
            end

            def check_bar_ends(sec, i, bar, ends)
                start = left_edge(bar)[1]
                stop = end_column(bar)
                if start != ends[0]
                    report(sec, i, "bottom bar starts at column #{start}, " \
                                   "should start at #{ends[0]}")
                end
                return if stop == ends[1]

                report(sec, i, "bottom bar ends at column #{stop}, " \
                               "should reach the shadow column #{ends[1]}")
            end
        end
    end
end
