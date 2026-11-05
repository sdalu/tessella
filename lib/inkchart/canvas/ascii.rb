# frozen_string_literal: true

module Inkchart
    class Canvas
        # 3x3 sub-pixels per cell, drawn with ASCII only. There is no
        # Unicode or ASCII standard for "this 3x3 dot pattern means
        # this character" the way there is for braille dots or block
        # quadrants, so the glyph follows an original rule, by where
        # the set sub-pixels lie (D2): one populated row reads as a
        # mark along that row (top: ` left, ' centre or right, " for
        # two or more; middle: -; bottom: . one, _ for two or more);
        # a full middle row with pixels elsewhere is still - unless
        # some column is also full, which (with a full row) is a
        # crossing; a column two- or three-deep with nothing in the
        # other columns is |; a dominant diagonal is / or \; a
        # crossing (both diagonals, or a full row and a full column)
        # is +; anything else falls back to whichever of - or | its
        # coverage resembles more. # overrides all of the above once
        # 7 or more of the 9 sub-pixels are set: by then a full row
        # and a full column always coexist (pigeonhole: 3 rows summing
        # to >= 7 force one to be full, and likewise for columns), so
        # "dense" and "a crossing" are never really distinct cases --
        # density is checked first and reads as solid ink, not a plus
        # sign. bits index as sy * SIZE + sx (top row first).
        class Ascii < Canvas
            SIZE = 3

            private

            def x_pixel_per_char = SIZE
            def y_pixel_per_char = SIZE

            def encode(code, sub_x, sub_y)
                code | (1 << ((sub_y * SIZE) + sub_x))
            end

            def decode(code)
                return " " if code.zero?
                glyph_for(code)
            end

            def glyph_for(code)
                rows = row_counts(code)
                cols = col_counts(code)
                row_only_glyph(code, rows) ||
                    full_middle_glyph(rows, cols) || column_glyph(cols) ||
                    dense_glyph(code) ||
                    diag_or_cross_glyph(code, rows, cols) ||
                    fallback_glyph(rows, cols)
            end

            def dense_glyph(code)
                "#" if (0...9).count { code[it] == 1 } >= 7
            end

            def row_counts(code)
                (0..2).map { |r| (0..2).count { code[(r * SIZE) + it] == 1 } }
            end

            def col_counts(code)
                (0..2).map { |c| (0..2).count { code[(it * SIZE) + c] == 1 } }
            end

            def only_row?(rows, idx)
                others = (0..2).to_a - [idx]
                rows[idx].positive? && others.all? { rows[it].zero? }
            end

            def row_only_glyph(code, rows)
                return top_row_glyph(code) if only_row?(rows, 0)
                return bottom_row_glyph(code) if only_row?(rows, 2)
                "-" if only_row?(rows, 1)
            end

            def top_row_glyph(code)
                set = (0..2).select { code[it] == 1 }
                return "\"" if set.size >= 2
                set.first.zero? ? "`" : "'"
            end

            def bottom_row_glyph(code)
                (0..2).count { code[6 + it] == 1 } >= 2 ? "_" : "."
            end

            def full_middle_glyph(rows, cols)
                return nil unless rows[1] == 3
                "-" unless cols.any? { it == 3 }
            end

            def column_glyph(cols)
                idx = (0..2).find { cols[it] >= 2 }
                return nil unless idx
                "|" if (0..2).all? { it == idx || cols[it].zero? }
            end

            def diagonal_counts(code)
                [[6, 4, 2].count { code[it] == 1 },
                 [0, 4, 8].count { code[it] == 1 }]
            end

            def crossing?(rising, falling, rows, cols)
                (rising >= 2 && falling >= 2) ||
                    (rows.any? { it == 3 } && cols.any? { it == 3 })
            end

            def diag_or_cross_glyph(code, rows, cols)
                rising, falling = diagonal_counts(code)
                return "+" if crossing?(rising, falling, rows, cols)
                return "/" if rising >= 2 && rising > falling
                "\\" if falling >= 2 && falling > rising
            end

            def fallback_glyph(rows, cols)
                rows.max >= cols.max ? "-" : "|"
            end
        end

        register(:ascii, Ascii)
    end
end
