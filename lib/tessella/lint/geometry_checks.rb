# frozen_string_literal: true

module Tessella
    module Lint
        # Geometry's two checks, on rows already split into display
        # columns (Geometry.cells) and glyphs read by their arms
        # (Geometry#arms): boxes keep their sides, connectors hang from
        # something.
        module Geometry
            # A box opened on row i: scanned left to right, each opening
            # corner followed down to its bottom edge. :uni is any
            # box-drawing set, :asc a +-| box.
            module Boxes
                private

                def check_boxes(sec, rows, i)
                    j = 0
                    j = box_at(sec, rows, [i, j]) while j < rows[i].length
                end

                # The column to resume the scan from.
                def box_at(sec, rows, pos)
                    kind = box_kind(rows, *pos) or return pos[1] + 1
                    k = box_end(rows[pos[0]], pos[1], kind)
                    return pos[1] + 1 unless
                        top_right?(Geometry.at(rows[pos[0]], k), kind)

                    follow_box(sec, rows, [*pos, k], kind) if
                        side_below?(rows, pos, kind)
                    k + 1
                end

                # :uni for a box-drawing top-left corner, :asc for a +
                # opening a -- run that is not the bottom edge of the box
                # above; nil otherwise.
                def box_kind(rows, i, j)
                    return :uni if corner?(rows[i][j], :tl)

                    :asc if ascii_corner?(rows[i], j) &&
                            !(i.positive? &&
                              SIDE_A.include?(Geometry.at(rows[i - 1], j)))
                end

                def ascii_corner?(row, j)
                    row[j] == "+" && Geometry.at(row, j + 1) == "-" &&
                        !(j.positive? && "-+".include?(Geometry.at(row, j - 1)))
                end

                # The column after the top edge's run of horizontals.
                def box_end(row, j, kind)
                    k = j + 1
                    k += 1 while k < row.length && top_run?(row, k, kind)
                    k
                end

                def top_run?(row, k, kind)
                    if kind == :uni
                        return arms?(row[k], LEFT | RIGHT) &&
                               !role?(row[k], :tr)
                    end

                    row[k] == "-" ||
                        (row[k] == "+" && Geometry.at(row, k + 1) == "-")
                end

                def top_right?(ch, kind)
                    return ch == "+" if kind == :asc

                    corner?(ch, :tr)
                end

                # A box's side: a vertical, or a junction on one.
                def side?(ch, kind)
                    return SIDE_A.include?(ch) if kind == :asc

                    vertical = UP | DOWN
                    arms?(ch, vertical) ||
                        (arms?(ch, LEFT | RIGHT) && arms(ch).anybits?(vertical))
                end

                def side_below?(rows, pos, kind)
                    below = rows[pos[0] + 1] or return false
                    side?(Geometry.at(below, pos[1]), kind)
                end

                # Down from the opening row to the first row that settles
                # the box: its bottom edge, or a side off its column.
                def follow_box(sec, rows, box, kind)
                    last = ((box[0] + 1)...rows.length).find do |i2|
                        box_settled?(sec, rows[i2], [*box, i2], kind)
                    end
                    return if last

                    report(sec, box[0], "box opened at col " \
                                        "#{geo_col(box[1])} has no bottom " \
                                        "edge")
                end

                def box_settled?(sec, row, pos, kind)
                    if bottom_left?(row, pos[1], kind)
                        check_bottom(sec, row, pos, kind)
                        return true
                    end
                    bad = off_side(row, pos, kind) or return false

                    report(sec, pos[3], "side of #{opened(sec, pos)} is off " \
                                        "at col #{geo_col(bad)}")
                    true
                end

                # The column of a side not where the box opened it, or
                # nil when both sides are in place.
                def off_side(row, pos, kind)
                    _, j, k, = pos
                    return j unless side?(Geometry.at(row, j), kind)

                    k unless side?(Geometry.at(row, k), kind)
                end

                def bottom_left?(row, j, kind)
                    left = Geometry.at(row, j)
                    return corner?(left, :bl) if kind == :uni

                    left == "+" && Geometry.at(row, j + 1) == "-"
                end

                def check_bottom(sec, row, pos, kind)
                    right = Geometry.at(row, pos[2])
                    return if closes?(right, kind)

                    report(sec, pos[3], "#{opened(sec, pos)} does not close " \
                                        "at col #{geo_col(pos[2])} (found " \
                                        "'#{right}')")
                end

                # A bottom-right corner, or a junction rising from it.
                def closes?(ch, kind)
                    return ch == "+" if kind == :asc

                    (arms?(ch, UP | LEFT) && !arms(ch).anybits?(DOWN)) ||
                        role?(ch, :br)
                end

                def opened(sec, pos)
                    "box opened at line #{sec.first + pos[0]} col " \
                        "#{geo_col(pos[1])}"
                end
            end

            # A vertical or an arrow head hangs from something above:
            # a glyph reaching down, or (ASCII) a | + or - edge.
            module Connectors
                private

                def check_connectors(sec, rows, i)
                    # Under a text row a stem may hang anywhere.
                    return unless rows[i - 1].any? do |ch|
                        arms(ch).positive? || SIDE_A.include?(ch)
                    end

                    rows[i].each_with_index do |ch, c|
                        check_connector(sec, rows, i, [ch, c])
                    end
                end

                def check_connector(sec, rows, i, glyph)
                    ch, c = glyph
                    ascii = connector_kind(rows[i], ch, c) or return
                    above = Geometry.at(rows[i - 1], c)
                    return if hangs?(above, ascii) ||
                              crossing?(rows, i, c, above)

                    report(sec, i, "connector '#{ch}' at col #{geo_col(c)} " \
                                   "hangs from '#{above}'")
                end

                # The ASCII glyphs that may carry this connector (an
                # arrow head's, or a vertical's), or nil when the glyph
                # is no connector: a vertical with a horizontal beside it
                # is a junction drawn in two cells.
                def connector_kind(row, ch, c)
                    return ABOVE_ARROW_A if arrow_head?(row, ch, c)
                    return SIDE_A if arms?(ch, UP | DOWN, exact: true) &&
                                     !beside_horizontal?(row, c)

                    ABOVE_VERT_A if ch == "|" && !beside?(row, c, "-")
                end

                def hangs?(above, ascii)
                    arms(above).anybits?(DOWN) || ascii.include?(above)
                end

                def arrow_head?(row, ch, c)
                    ARROWS.include?(ch) || (ch == "v" && lone?(row, c))
                end

                def lone?(row, c)
                    Geometry.at(row, c - 1) == " " &&
                        Geometry.at(row, c + 1) == " "
                end

                def beside?(row, c, glyph)
                    Geometry.at(row, c - 1) == glyph ||
                        Geometry.at(row, c + 1) == glyph
                end

                def beside_horizontal?(row, c)
                    [c - 1, c + 1].any? do |x|
                        arms?(Geometry.at(row, x), LEFT | RIGHT, exact: true)
                    end
                end

                # A lifeline crossed by an arrow: a plain horizontal
                # above, the same vertical on the row above that.
                def crossing?(rows, i, c, above)
                    return false unless i >= 2 &&
                                        arms?(above, LEFT | RIGHT, exact: true)

                    hangs?(Geometry.at(rows[i - 2], c), SIDE_A)
                end
            end
        end
    end
end
