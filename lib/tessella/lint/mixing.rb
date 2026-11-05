# frozen_string_literal: true

module Tessella
    module Lint
        # ASCII box structure and Unicode box drawing in one figure: a
        # figure is a run of non-blank lines holding a box-drawing
        # glyph (so a Markdown table beside it stays out), inline code
        # spans stripped first (prose naming a glyph is not art). One
        # finding per figure, at its first ASCII-structured line. An
        # allow-mixed marker line closes the group before it and
        # exempts the next group to form, however far below.
        module Mixing
            # A line using ASCII as structure: a pair from
            # ASCII_STRUCT_PAIR, or a | at its first or last non-blank.
            def self.ascii_structural?(line)
                return true if line.match?(ASCII_STRUCT_PAIR)

                trimmed = line.strip
                !trimmed.empty? &&
                    (trimmed.start_with?("|") || trimmed.end_with?("|"))
            end

            private

            def check_vocab_mixing(sec)
                group = []
                exempt = sec.exempt
                sec.lines.each_with_index do |line, i|
                    next group << [i, line.gsub(INLINE_CODE, "")] unless
                        line.match?(MIXED_MARKER) || line.strip.empty?

                    exempt = flush_vocab_group(sec, group, exempt) ||
                             line.match?(MIXED_MARKER)
                    group = []
                end
                flush_vocab_group(sec, group, exempt)
            end

            # Checks the group unless exempt; an empty group (blank
            # after blank, marker after marker) keeps the exemption.
            def flush_vocab_group(sec, group, exempt)
                return exempt if group.empty?

                flag_mixed_vocab(sec, group) unless exempt
                false
            end

            def flag_mixed_vocab(sec, group)
                return unless group.any? { |_, line| line.match?(BOX_CHAR) }

                i, = group.find { |_, line| Mixing.ascii_structural?(line) }
                return unless i

                report(sec, i, "ASCII structure (a +-/-+/--/|-/-|/+|/|+/->/" \
                               "<- pair, or | at the line edge) mixed " \
                               "with Unicode box-drawing (U+2500-257F) " \
                               "in the same figure")
            end
        end
    end
end
