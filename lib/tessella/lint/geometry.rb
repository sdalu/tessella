# frozen_string_literal: true

module Tessella
    module Lint
        # Box geometry (geometry: true), ported from the skills shelf's
        # tests/lib/check-readme.py: a box opened by a top-left corner
        # keeps its sides at the same two columns down to its bottom
        # edge -- a side wandering by one column is the commonest
        # hand-drawn defect -- and a connector (a vertical or an arrow
        # head) hangs from something above it: a junction, a vertical,
        # an arrow, a label, never a plain edge or blank.
        #
        # check-readme.py knew the light set only. Here every
        # box-drawing glyph is read by its arms (which of up, down,
        # left, right it reaches), so light, heavy, double, rounded,
        # dashed and mixed junctions (╤ ╫ ...) are all one case, and a
        # custom border set (borders:) gives its six glyphs the arms
        # of their role. ASCII boxes (+ - |) keep their own rules.
        # Columns are display columns, so a wide glyph is two; a
        # vertical under a horizontal that has the same vertical above
        # it is a crossing (a lifeline under an arrow), not a hanger.
        module Geometry
            include Boxes
            include Connectors

            UP = 1
            DOWN = 2
            LEFT = 4
            RIGHT = 8

            # The arms of U+2500..U+257F, one hex digit each (UP 1,
            # DOWN 2, LEFT 4, RIGHT 8), generated from the Unicode 15.1
            # character names: HORIZONTAL is left and right, VERTICAL
            # up and down, the diagonals none.
            ARMS = "cc33cc33cc33aaaa666699995555bbbbbbbb77777777eeeeeeee" \
                   "ddddddddffffffffffffffffcc33c3aaa666999555bbb777eeed" \
                   "ddfffa65900041824182c3c3"
                   .each_char.with_index.to_h do |digit, i|
                       [(0x2500 + i).chr(Encoding::UTF_8), digit.to_i(16)]
                   end.freeze

            # Arms by role in a custom border set.
            ROLE_ARMS = {
                tl: DOWN | RIGHT, tr: DOWN | LEFT, bl: UP | RIGHT,
                br: UP | LEFT, h: LEFT | RIGHT, v: UP | DOWN
            }.freeze

            SIDE_A = "|+"
            ABOVE_VERT_A = "|+-"
            ABOVE_ARROW_A = "|+-v▼▾"
            ARROWS = "▼▾"
            # The second column of a wide glyph: structural to nothing.
            TAIL = "\u0000"

            # A row as one glyph per display column.
            def self.cells(line)
                line.each_char.with_object([]) do |ch, out|
                    case Width.char(ch.ord)
                    when 0 then next
                    when 2 then out.push(ch, TAIL)
                    else out << ch
                    end
                end
            end

            def self.at(row, col) = (col.negative? ? nil : row[col]) || " "

            # Each declared border set's glyphs by the roles they play
            # (ASCII + - | stay with the ASCII rules): a glyph used for
            # several roles, as * for all four corners, plays them all.
            def self.roles_for(sets)
                roles = Hash.new { |h, k| h[k] = [] }
                sets.each do |set|
                    ROLE_ARMS.each_key do |role|
                        glyph = set.public_send(role)
                        roles[glyph] |= [role] unless "+-|".include?(glyph)
                    end
                end
                roles
            end

            # The arms table for one run: the box-drawing glyphs, and
            # each custom glyph with the union of its roles' arms.
            def self.arms_for(roles)
                roles.each_with_object(ARMS.dup) do |(glyph, list), arms|
                    arms[glyph] = list.sum { ROLE_ARMS[it] } |
                                  arms.fetch(glyph, 0)
                end
            end

            private

            def check_geometry(sec)
                @roles ||= Geometry.roles_for(@opts[:borders])
                @arms ||= Geometry.arms_for(@roles)
                rows = sec.lines.map { Geometry.cells(it) }
                rows.each_index { check_boxes(sec, rows, it) }
                (1...rows.length).each { check_connectors(sec, rows, it) }
            end

            def arms(ch) = @arms.fetch(ch, 0)

            def role?(ch, role) = @roles.fetch(ch, []).include?(role)

            # A corner: the box-drawing glyph with exactly its arms, or
            # a custom glyph declared for it.
            def corner?(ch, role)
                arms?(ch, ROLE_ARMS[role], exact: true) || role?(ch, role)
            end

            # Every arm in bits, and none outside them when exact.
            def arms?(ch, bits, exact: false)
                a = arms(ch)
                a.allbits?(bits) && (!exact || a == bits)
            end

            def geo_col(col) = @overhead + col + 1
        end
    end
end
