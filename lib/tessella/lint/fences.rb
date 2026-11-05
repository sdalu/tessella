# frozen_string_literal: true

module Tessella
    module Lint
        # fences: true -- each fenced block of a Markdown text linted on
        # its own, with the text's line numbers, since a whole document
        # would read its prose and tables as art. A fence opens with
        # three or more backticks or tildes (indented at most three
        # spaces) and closes with a run of the same glyph at least as
        # long; an unclosed fence runs to the end. An allow-mixed
        # marker on the last non-blank line before a fence exempts
        # that block from the mixing check.
        module Fences
            OPEN = /\A {0,3}(`{3,}|~{3,})/

            def self.sections(lines)
                out = []
                i = 0
                while i < lines.length
                    fence = lines[i][OPEN, 1]
                    i += 1
                    next unless fence

                    out << section(lines, i, closing(lines, i, fence))
                    i = out.last.first + out.last.lines.length
                end
                out
            end

            # The index of the closing fence, or lines.length.
            def self.closing(lines, from, fence)
                glyph = Regexp.escape(fence[0])
                close = /\A {0,3}#{glyph}{#{fence.length},}\s*\z/
                (from...lines.length).find { lines[it].match?(close) } ||
                    lines.length
            end

            def self.section(lines, from, stop)
                Section.new(lines: lines[from...stop], first: from + 1,
                            exempt: marked?(lines, from - 1))
            end

            def self.marked?(lines, fence_at)
                before = lines[0...fence_at].reverse.find do |line|
                    !line.strip.empty?
                end
                before&.match?(MIXED_MARKER) || false
            end
        end
    end
end
