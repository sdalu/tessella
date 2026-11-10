# frozen_string_literal: true

module Tessella
    module Lint
        # The checks one line at a time: invalid UTF-8, tabs, forbidden
        # sequences, trailing blanks, wide / invisible / emoji-capable /
        # non-ASCII glyphs, spaces other than U+0020, wide glyphs on an
        # aligned row (web) and ambiguous ones (cjk), and the column
        # budget, which also records the line's ruler row.
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

            def check_char(sec, i, ch)
                wide = Lint.wide?(ch.ord)
                report(sec, i, glyph("wide char", ch)) if wide && no_wide?
                check_blank(sec, i, ch)
                check_web_char(sec, i, ch) if @opts[:web]
                check_ascii_char(sec, i, ch) if @opts[:ascii] && !wide
            end

            # Names a glyph drawn as nothing, or as a blank that is not
            # U+0020.
            def check_blank(sec, i, ch)
                if Lint.invisible?(ch.ord)
                    report(sec, i, code_point("invisible char", ch))
                elsif Lint.look_alike_space?(ch)
                    report(sec, i, code_point("look-alike space", ch))
                end
            end

            # A look-alike space is named by check_blank already.
            def check_ascii_char(sec, i, ch)
                return if ch.ord <= 0x7F || Lint.look_alike_space?(ch)

                report(sec, i, glyph("non-ASCII", ch))
            end

            def check_budget(sec, i, line)
                cols = end_column(line)
                @rulers << Ruler.new(line: sec.first + i, width: cols,
                                     verticals: vertical_columns(line))
                return if cols <= @opts[:width]

                report(sec, i, "#{cols} columns rendered (budget " \
                               "#{@opts[:width]})")
            end

            def code_point(what, ch)
                format("%<what>s U+%<code>04X", what: what, code: ch.ord)
            end

            def no_wide? = @opts[:no_wide] || @opts[:ascii]

            def glyph(what, ch)
                format("%<what>s U+%<code>04X %<ch>s", what: what,
                                                       code: ch.ord, ch: ch)
            end
        end
    end
end
