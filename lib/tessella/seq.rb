# frozen_string_literal: true

module Tessella
    # UML-style sequence diagrams (this module matches the tessella
    # skill's scripts/seq.rb byte for byte). One statement per line:
    # "participant NAME", "A -> B: text" (call), "A --> B: text"
    # (reply, dashed), "A ->> B: text" (async, a double arrowhead), a
    # self call "A -> A: text" (a loop right of A), and "note over
    # A[,B]: text". A name is any run of Unicode letters/digits, "_",
    # "." or "-"; under ascii: true such a name must be ASCII.
    # Columns are fixed by first appearance (or an explicit
    # "participant" line) and widen just enough for every label and
    # note that touches them -- never truncating. Every refusal (an
    # unrecognised statement, a non-ASCII name under ascii: true, no
    # statements or no participants in the input) is an ArgumentError
    # naming the line ("line N: ..."; line 0 when there is no line).
    module Seq
        GAP = 2
        LOOP_WIDTH = 3

        # A name may hold "-" but not end with one, so "A-->B" is A
        # replying to B, and "A-->>B", no arrow, is refused.
        NAME = '[\p{L}\p{N}_.](?:[\p{L}\p{N}_.-]*[\p{L}\p{N}_.])?'
        KIND = { "->" => :call, "-->" => :reply, "->>" => :async }.freeze
        PART_RE = /\Aparticipant\s+(#{NAME})\s*\z/
        ARROW_RE = /\A(#{NAME})\s*(->>|-->|->)\s*(#{NAME})\s*:\s*(.*)\z/
        NOTE_RE = /\Anote\s+over\s+(#{NAME})(?:\s*,\s*(#{NAME}))?
                    \s*:\s*(.*)\z/x

        UNI_G = { h: "─", v: "│", tl: "┌", tr: "┐", bl: "└", br: "┘",
                  td: "┬", tu: "┴", tr_: "├", tl_: "┤", dash: "┄" }.freeze
        ASC_G = { h: "-", v: "|", tl: "+", tr: "+", bl: "+", br: "+",
                  td: "+", tu: "+", tr_: "+", tl_: "+", dash: "-" }.freeze

        def self.bad!(lineno, msg)
            raise ArgumentError, "line #{lineno}: #{msg}"
        end

        def self.style_for(ascii)
            (ascii ? ASC_G : UNI_G).merge(ascii: ascii)
        end

        # The whole pipeline: parse, check names, number messages,
        # fix the participant order, lay out columns, draw.
        def self.build(text, ascii:, numbered:, footer:)
            statements = parse(text)
            check_ascii_names!(statements, ascii)
            assign_numbers!(statements, numbered)
            participants = gather_participants(statements)
            bad!(0, "no participants in the input") if participants.empty?
            lay = layout(participants, statements)
            style = style_for(ascii)
            Block.new(render(statements, lay, participants, style, footer))
        end
    end

    # Parsing: one statement per non-blank, non-comment line, each
    # tagged with its 1-based line number; a line matching none of
    # the three shapes is refused by name, and so is empty input.
    module Seq
        def self.match_statement(line)
            if (m = PART_RE.match(line))
                { type: :participant, name: m[1] }
            elsif (m = ARROW_RE.match(line))
                { type: :message, kind: KIND[m[2]], from: m[1], to: m[3],
                  text: m[4].rstrip }
            elsif (m = NOTE_RE.match(line))
                { type: :note, names: [m[1], m[2]].compact.uniq,
                  text: m[3].rstrip }
            end
        end

        def self.parse_line(raw, lineno)
            line = raw.strip
            return nil if line.empty? || line.start_with?("#")

            stmt = match_statement(line)
            bad!(lineno, line) unless stmt
            stmt.merge(line: lineno)
        end

        def self.parse(text)
            statements = text.split("\n", -1).each_with_index
                             .map { |raw, i| parse_line(raw, i + 1) }.compact
            bad!(0, "no statements in the input") if statements.empty?
            statements
        end

        def self.assign_numbers!(statements, numbered)
            n = 0
            statements.each do |s|
                next unless s[:type] == :message

                n += 1
                s[:number] = numbered ? n : nil
            end
        end

        def self.label_text(stmt)
            return stmt[:text] unless stmt[:number]

            "#{stmt[:number]}. #{stmt[:text]}"
        end

        def self.names_in(stmt)
            case stmt[:type]
            when :participant then [stmt[:name]]
            when :message then [stmt[:from], stmt[:to]]
            when :note then stmt[:names]
            else []
            end
        end

        def self.ascii_name?(name) = name.each_char.all? { it.ord < 128 }

        # Under ascii: true names, labels and notes are ASCII -- but
        # under :cjk, where ascii: only means the structure.
        def self.check_ascii_names!(statements, ascii)
            return unless ascii && !Target.text_free?

            statements.each { check_ascii_statement!(it) }
        end

        def self.check_ascii_statement!(stmt)
            name = names_in(stmt).find { !ascii_name?(it) }
            line = stmt[:line]
            bad!(line, "participant #{name.inspect} is not ASCII") if name
            text = stmt[:text]
            bad!(line, "text #{text.inspect} is not ASCII") if
                text && !ascii_name?(text)
        end

        def self.gather_participants(stmts)
            seen = {}
            order = []
            stmts.each do |s|
                names_in(s).each do |n|
                    next if seen[n]

                    seen[n] = true
                    order << n
                end
            end
            order
        end
    end

    # Column layout, part 1: a participant's box (inner width and
    # centre offset), the left-to-right positions gaps and margin
    # produce, and the two primitives ("how much room is free to one
    # side of a column") the growers below share.
    module Seq
        def self.measure_box(text)
            inner = Width.of(text) + 2
            inner += 1 if inner.even?
            { inner: inner, width: inner + 2, offset: (inner + 1) / 2 }
        end

        def self.positions_for(boxes, gaps, left_margin)
            cursor = left_margin
            boxes.each_with_index.map do |box, i|
                left = cursor
                cursor += box[:width] + gaps[i]
                { left: left, center: left + box[:offset], width: box[:width] }
            end
        end

        def self.total_width(positions, gaps)
            last = positions.last
            last[:left] + last[:width] + gaps.last
        end

        def self.right_room(boxes, pos, idx, trailing_gap)
            return trailing_gap if idx == boxes.size - 1

            pos[idx + 1][:center] - pos[idx][:center] - 1
        end

        def self.left_room(pos, idx)
            return pos[0][:center] if idx.zero?

            pos[idx][:center] - pos[idx - 1][:center] - 1
        end
    end

    # Column layout, part 2: state is { gaps:, margin:, boxes: },
    # one Array entry per participant; ensure_width! grows the gap
    # between two columns, grow_left!/grow_right! grow the margin or
    # a neighbouring gap, and widen_for! dispatches a statement to
    # whichever of those its shape (a message, a self call, a note
    # over one or two participants) needs.
    module Seq
        def self.ensure_width!(state, lo, hi, required, pad)
            pos = positions_for(state[:boxes], state[:gaps], state[:margin])
            deficit = required - (pos[hi][:center] - pos[lo][:center] + pad)
            state[:gaps][lo] += deficit if deficit.positive?
        end

        def self.grow_left!(state, idx, amount)
            return unless amount.positive?

            if idx.zero?
                state[:margin] += amount
            else
                state[:gaps][idx - 1] += amount
            end
        end

        def self.grow_right!(state, idx, needed)
            boxes = state[:boxes]
            pos = positions_for(boxes, state[:gaps], state[:margin])
            amount = needed - right_room(boxes, pos, idx, state[:gaps][idx])
            state[:gaps][idx] += amount if amount.positive?
        end

        def self.ensure_centered!(state, idx, note_box)
            half = note_box[:offset] + 1
            pos = positions_for(state[:boxes], state[:gaps], state[:margin])
            grow_left!(state, idx, half - left_room(pos, idx))
            grow_right!(state, idx, half)
        end

        def self.self_loop_need(label) = LOOP_WIDTH + 3 + Width.of(label)

        def self.widen_message!(state, participants, stmt)
            i = participants.index(stmt[:from])
            j = participants.index(stmt[:to])
            label = label_text(stmt)
            return grow_right!(state, i, self_loop_need(label)) if i == j

            seg = label_gap(i, j)
            required = Width.of(label) + 2
            ensure_width!(state, seg, seg + 1, required, -1)
        end

        # The gap a message's label sits in: the one beside its
        # sender, so a message that skips participants never writes
        # its label over a lifeline it passes.
        def self.label_gap(from, to) = from < to ? from : from - 1

        def self.widen_note!(state, participants, stmt)
            idx = stmt[:names].map { participants.index(it) }.sort
            if idx.size == 1
                ensure_centered!(state, idx.first, measure_box(stmt[:text]))
            else
                required = Width.of(stmt[:text]) + 2
                ensure_width!(state, idx.first, idx.last, required, 1)
            end
        end

        def self.widen_for!(state, participants, stmt)
            case stmt[:type]
            when :message then widen_message!(state, participants, stmt)
            when :note then widen_note!(state, participants, stmt)
            end
        end

        def self.layout(participants, statements)
            boxes = participants.map { measure_box(it) }
            state = { gaps: Array.new(participants.size, GAP), margin: 0,
                      boxes: boxes }
            statements.each { |s| widen_for!(state, participants, s) }
            pos = positions_for(boxes, state[:gaps], state[:margin])
            { positions: pos, boxes: boxes,
              width: total_width(pos, state[:gaps]) }
        end
    end

    # Drawing primitives on one row of characters: a blank row,
    # placing text (a double-width glyph takes two columns, so the
    # cell after it holds ""), a dashed or solid run, and a
    # three-line box (top, centred text, bottom) with an optional
    # tee in its top or bottom edge.
    module Seq
        def self.blank_row(width) = Array.new(width, " ")

        def self.place!(row, col, text)
            text.each_char do |ch|
                w = Width.of(ch)
                row[col] = ch
                row[col + 1] = "" if w == 2
                col += w
            end
        end

        def self.dash_line(inner, fill, tee, offset)
            s = fill * inner
            s[offset - 1] = tee if tee
            s
        end

        def self.box_rows(box, text, style, tee_top: nil, tee_bot: nil)
            tl, tr, bl, br, h, v = style.values_at(:tl, :tr, :bl, :br, :h, :v)
            inner = box[:inner]
            offset = box[:offset]
            top = tl + dash_line(inner, h, tee_top, offset) + tr
            mid = v + Width.center(text, inner) + v
            bot = bl + dash_line(inner, h, tee_bot, offset) + br
            [top, mid, bot]
        end

        # Full-size heads (not emoji-capable, though a font lacking
        # them gives them a fallback width on the web); async a double
        # head, as ->> writes it.
        HEADS = { call: { right: "►", left: "◄" },
                  async: { right: "►►", left: "◄◄" } }.freeze
        ASCII_HEADS = { call: { right: ">", left: "<" },
                        async: { right: ">>", left: "<<" } }.freeze

        def self.arrowhead(kind, dir, style)
            heads = style[:ascii] ? ASCII_HEADS : HEADS
            heads[kind == :async ? :async : :call][dir]
        end

        def self.alt_dashes(n) = (0...n).map { |i| i.even? ? "-" : " " }.join

        def self.dash_run(n, dashed, style)
            return "" if n <= 0
            return alt_dashes(n) if style[:ascii] && dashed

            (dashed ? style[:dash] : style[:h]) * n
        end
    end

    # Row builders, part 1: the header/footer boxes and plain
    # arrows. A lifeline row has the vertical bar at every
    # participant's centre column; an arrow row adds its head and a
    # dashed or solid run between two columns.
    module Seq
        def self.place_box!(rows, left, box)
            box.each_with_index { |s, r| place!(rows[r], left, s) }
        end

        def self.participant_lines(lay, participants, style, tee_top:,
                                   tee_bot:)
            positions, boxes, width = lay.values_at(:positions, :boxes,
                                                    :width)
            rows = Array.new(3) { blank_row(width) }
            participants.each_with_index do |name, i|
                br = box_rows(boxes[i], name, style,
                              tee_top: tee_top, tee_bot: tee_bot)
                place_box!(rows, positions[i][:left], br)
            end
            rows.map(&:join)
        end

        def self.lifeline_row(lay, style)
            row = blank_row(lay[:width])
            lay[:positions].each { |p| place!(row, p[:center], style[:v]) }
            row
        end

        def self.blank_line(lay, style) = lifeline_row(lay, style).join

        def self.fill_arrow_row(row, spec, style, dashed)
            lo, hi, kind, dir = spec.values_at(:lo, :hi, :kind, :dir)
            gap = dash_run(hi - lo - 2, dashed, style)
            head = arrowhead(kind, dir, style)
            if dir == :right
                place!(row, lo + 1, gap)
                place!(row, hi - Width.of(head), head)
            else
                place!(row, lo + 2, gap)
                place!(row, lo + 1, head)
            end
        end

        def self.arrow_row(lay, spec, style)
            row = lifeline_row(lay, style)
            fill_arrow_row(row, spec, style, spec[:kind] == :reply)
            row
        end

        # Only the label's own glyphs overwrite the lifeline row --
        # not the padding either side of it -- so a lifeline the
        # message happens to span still shows through the label row.
        def self.centered_start(interior, text_width)
            (interior - text_width) / 2
        end

        def self.arrow_rows(lay, spec, label, style)
            lo, hi = spec[:label]
            lr = lifeline_row(lay, style)
            interior = hi - lo - 1
            start = lo + 1 + centered_start(interior, Width.of(label))
            place!(lr, start, label)
            [lr.join, arrow_row(lay, spec, style).join]
        end
    end

    # Row builders, part 2: a self call loops to the right of its
    # own lifeline; a note is a small box over one participant's
    # centre column, or spanning the columns of two.
    module Seq
        def self.self_loop_top(lay, style, kind, col)
            row = lifeline_row(lay, style)
            place!(row, col + 1, dash_run(LOOP_WIDTH - 1, kind == :reply,
                                          style))
            place!(row, col + LOOP_WIDTH, style[:tr])
            row
        end

        def self.self_loop_mid(lay, style, label, col)
            row = lifeline_row(lay, style)
            place!(row, col + LOOP_WIDTH, style[:v])
            place!(row, col + LOOP_WIDTH + 2, label)
            row
        end

        def self.self_loop_bot(lay, style, kind, col)
            row = lifeline_row(lay, style)
            place!(row, col + 2, dash_run(LOOP_WIDTH - 2, kind == :reply,
                                          style))
            place!(row, col + 1, arrowhead(kind, :left, style))
            place!(row, col + LOOP_WIDTH, style[:br])
            row
        end

        def self.self_loop_rows(lay, style, kind, label, col)
            [self_loop_top(lay, style, kind, col),
             self_loop_mid(lay, style, label, col),
             self_loop_bot(lay, style, kind, col)].map(&:join)
        end

        def self.single_note(idx, positions, note_box)
            { left: positions[idx][:center] - note_box[:offset],
              box: note_box }
        end

        def self.span_note(lo, hi, positions)
            width = positions[hi][:center] - positions[lo][:center] + 1
            { left: positions[lo][:center],
              box: { inner: width - 2, width: width } }
        end

        def self.note_spot(idx, positions, text)
            return single_note(idx.first, positions, measure_box(text)) if
                idx.size == 1

            span_note(idx.first, idx.last, positions)
        end

        # A note's box drawn over the lifelines: where a lifeline
        # meets its top or bottom edge, the edge takes a junction
        # (├ ┤ at a corner, ┴ ┬ along an edge), so the lifeline
        # ends and resumes at a stroke rather than butting a plain
        # corner or edge.
        def self.overlay_rows(lay, style, rows, left)
            canvas = rows.map { lifeline_row(lay, style) }
            rows.each_with_index { |s, r| place!(canvas[r], left, s) }
            join_lifelines!(canvas, lay, note_joints(style))
            canvas.map(&:join)
        end

        def self.join_lifelines!(canvas, lay, joints)
            lay[:positions].each do |p|
                junction!(canvas.first, p[:center], joints[:top])
                junction!(canvas.last, p[:center], joints[:bottom])
            end
        end

        def self.note_joints(style)
            { top: { style[:tl] => style[:tr_], style[:tr] => style[:tl_],
                     style[:h] => style[:tu] },
              bottom: { style[:bl] => style[:tr_], style[:br] => style[:tl_],
                        style[:h] => style[:td] } }
        end

        def self.junction!(row, col, joints)
            row[col] = joints.fetch(row[col], row[col])
        end

        def self.note_rows(stmt, lay, participants, style)
            idx = stmt[:names].map { participants.index(it) }.sort
            spot = note_spot(idx, lay[:positions], stmt[:text])
            rows = box_rows(spot[:box], stmt[:text], style)
            overlay_rows(lay, style, rows, spot[:left])
        end
    end

    # Dispatches a statement to its rows, and assembles the whole
    # diagram: header boxes, a blank lifeline row and the statement's
    # own rows for each statement that draws anything (a bare
    # "participant" declaration draws nothing, and gets no spacer
    # row either), a trailing blank row, and the footer boxes when
    # asked for.
    module Seq
        def self.arrow_statement_rows(lay, idx_pair, kind, label, style)
            i, j = idx_pair
            lo, hi = idx_pair.minmax
            dir = i < j ? :right : :left
            pos = lay[:positions]
            seg = label_gap(i, j)
            spec = { lo: pos[lo][:center], hi: pos[hi][:center],
                     kind: kind, dir: dir,
                     label: [pos[seg][:center], pos[seg + 1][:center]] }
            arrow_rows(lay, spec, label, style)
        end

        def self.message_statement_rows(stmt, lay, participants, style)
            i = participants.index(stmt[:from])
            j = participants.index(stmt[:to])
            label = label_text(stmt)
            if i == j
                center = lay[:positions][i][:center]
                return self_loop_rows(lay, style, stmt[:kind], label, center)
            end
            arrow_statement_rows(lay, [i, j], stmt[:kind], label, style)
        end

        def self.statement_rows(stmt, lay, participants, style)
            case stmt[:type]
            when :message
                message_statement_rows(stmt, lay, participants, style)
            when :note
                note_rows(stmt, lay, participants, style)
            else
                []
            end
        end

        def self.append_footer(lines, lay, participants, style, footer)
            return lines unless footer

            footer_style = { tee_top: style[:tu], tee_bot: nil }
            lines.concat(participant_lines(lay, participants, style,
                                           **footer_style))
        end

        def self.append_statement(lines, s, lay, participants, style)
            rows = statement_rows(s, lay, participants, style)
            return if rows.empty?

            lines << blank_line(lay, style)
            lines.concat(rows)
        end

        def self.render(statements, lay, participants, style, footer)
            header_style = { tee_top: nil, tee_bot: style[:td] }
            lines = participant_lines(lay, participants, style,
                                      **header_style)
            statements.each do |s|
                append_statement(lines, s, lay, participants, style)
            end
            lines << blank_line(lay, style)
            append_footer(lines, lay, participants, style, footer)
        end
    end

    def self.seq(text, ascii: Target.ascii?, numbered: false, footer: false)
        Seq.build(text, ascii: ascii, numbered: numbered, footer: footer)
    end
end
