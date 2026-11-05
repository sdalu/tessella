# frozen_string_literal: true

module Tessella
    module Lint
        # The checks one line at a time: invalid UTF-8, tabs, forbidden
        # sequences, trailing blanks, wide / invisible / emoji-capable /
        # non-ASCII glyphs, wide glyphs on an aligned row (web) and
        # ambiguous ones (cjk), and the column budget, which also
        # records the line's ruler row.
        module Lines
            private

            # A line that is not valid UTF-8 is named once, then linted
            # with each bad byte as "?".
            def sanitized(sec)
                lines = sec.lines.each_with_index.map do |line, i|
                    next line if line.valid_encoding?

                    report(sec, i, "invalid UTF-8 byte sequence")
                    line.scrub("?")
                end
                sec.with(lines: lines)
            end

            def check_line(sec, i, line)
                report(sec, i, "tab character") if line.include?("\t")
                check_forbidden(sec, i, line)
                report(sec, i, "trailing whitespace") if
                    line.match?(/[ \t]+\z/)
                check_chars(sec, i, line)
                check_target_row(sec, i, line)
                check_budget(sec, i, line)
            end

            def check_forbidden(sec, i, line)
                @opts[:forbid].each do |seq|
                    if seq == :trailing_backslash
                        if line.end_with?("\\")
                            report(sec, i, "row ends in backslash (line " \
                                           "splicing)")
                        end
                    elsif line.include?(seq)
                        report(sec, i, "forbidden sequence #{seq.inspect}")
                    end
                end
            end

            def check_chars(sec, i, line)
                skip = text_styled(line)
                line.each_char.with_index do |ch, k|
                    check_char(sec, i, ch) unless skip.include?(k)
                end
            end

            # Under :web, an emoji-capable glyph followed by U+FE0E is
            # kept as text: the indices of both, neither a finding.
            def text_styled(line)
                return [] unless @opts[:web]

                line.enum_for(:scan, /(.)\u{FE0E}/).flat_map do
                    match = Regexp.last_match
                    k = match.begin(0)
                    Lint.emoji_risk?(match[1].ord) ? [k, k + 1] : []
                end
            end

            def check_target_row(sec, i, line)
                check_web_row(sec, i, line) if @opts[:web]
                check_cjk_row(sec, i, line) if @opts[:target] == :cjk
            end

            def check_char(sec, i, ch)
                wide = Lint.wide?(ch.ord)
                report(sec, i, glyph("wide char", ch)) if wide && no_wide?
                if Lint.invisible?(ch.ord)
                    report(sec, i, format("invisible char U+%<code>04X",
                                          code: ch.ord))
                end
                check_web_char(sec, i, ch) if @opts[:web]
                check_ascii_char(sec, i, ch) if @opts[:ascii] && !wide
            end

            def check_ascii_char(sec, i, ch)
                report(sec, i, glyph("non-ASCII", ch)) if ch.ord > 0x7F
            end

            def check_web_char(sec, i, ch)
                return unless Lint.emoji_risk?(ch.ord)

                report(sec, i, "#{glyph("emoji-capable", ch)} (web target)")
            end

            def check_web_row(sec, i, line)
                return unless line.match?(STRUCTURAL)

                line.each_char do |ch|
                    next unless Lint.wide?(ch.ord)

                    report(sec, i, "#{glyph("wide", ch)} on aligned row " \
                                   "(web target)")
                end
            end

            # Under :cjk an ambiguous glyph that is not box drawing (·, é,
            # ●) on a row that must line up takes two columns: named,
            # as the drift and geometry checks measure it so.
            def check_cjk_row(sec, i, line)
                return unless line.match?(STRUCTURAL)

                line.each_char.grep_v(BOX_CHAR).uniq.each do |ch|
                    next unless Width.class_of(ch) == :A

                    report(sec, i, "#{glyph("ambiguous", ch)} on aligned row " \
                                   "(cjk target: 2 columns#{stand_in(ch)})")
                end
            end

            # The small head that lines up in place of a full-size one.
            def stand_in(ch)
                small = { "▲" => "▴", "▼" => "▾" }[ch]
                small ? "; #{small} lines up" : ""
            end

            def check_budget(sec, i, line)
                cols = end_column(line)
                @rulers << Ruler.new(line: sec.first + i, width: cols,
                                     verticals: vertical_columns(line))
                return if cols <= @opts[:width]

                report(sec, i, "#{cols} columns rendered (budget " \
                               "#{@opts[:width]})")
            end

            def no_wide? = @opts[:no_wide] || @opts[:ascii]

            def glyph(what, ch)
                format("%<what>s U+%<code>04X %<ch>s", what: what,
                                                       code: ch.ord, ch: ch)
            end
        end
    end
end
