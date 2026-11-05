# frozen_string_literal: true

module Tessella
    # A lint for text figures (DESIGN.md, "Lint"), ported from the
    # ascii-art skill's scripts/artlint.rb: tabs, invisible glyphs,
    # trailing blanks, a column budget, forbidden comment-breaking
    # sequences, drop-shadow geometry, ASCII structure mixed with
    # Unicode box drawing, a vertical anchor one column off -- and, on
    # request, box sides and connectors (geometry: true) and one
    # Markdown fence at a time (fences: true). Tessella.lint and
    # Tessella.alphabet, at the bottom of this file, are the entries.
    module Lint
        # One finding: the line of the text it is on, 1-based, and what
        # is wrong there.
        Finding = Data.define(:line, :message)

        # One --ruler row: a line's rendered width (the prefix
        # included) and the display columns of its verticals.
        Ruler = Data.define(:line, :width, :verticals)

        # What Tessella.lint returns: every finding, in the order
        # artlint.rb reported them, and a Ruler per line linted.
        Report = Data.define(:findings, :rulers) do
            def clean? = findings.empty?
        end

        # A run of lines linted as one text: the whole input, or one
        # fenced block's body. first is the input line of lines[0];
        # exempt says an allow-mixed marker came just before the fence.
        Section = Data.define(:lines, :first, :exempt)

        # Emoji-capable with text-default presentation (Emoji=Yes minus
        # Emoji_Presentation=Yes, BMP; digits/#/* excluded): one cell in
        # terminals, but web viewers may substitute the 2-cell emoji
        # glyph. Generated from Unicode 15.1 emoji-data.txt.
        EMOJI_RISK = [
            0x00A9..0x00A9, 0x00AE..0x00AE, 0x203C..0x203C, 0x2049..0x2049,
            0x2122..0x2122, 0x2139..0x2139, 0x2194..0x2199, 0x21A9..0x21AA,
            0x2328..0x2328, 0x23CF..0x23CF, 0x23ED..0x23EF, 0x23F1..0x23F2,
            0x23F8..0x23FA, 0x24C2..0x24C2, 0x25AA..0x25AB, 0x25B6..0x25B6,
            0x25C0..0x25C0, 0x25FB..0x25FC, 0x2600..0x2604, 0x260E..0x260E,
            0x2611..0x2611, 0x2618..0x2618, 0x261D..0x261D, 0x2620..0x2620,
            0x2622..0x2623, 0x2626..0x2626, 0x262A..0x262A, 0x262E..0x262F,
            0x2638..0x263A, 0x2640..0x2640, 0x2642..0x2642, 0x265F..0x2660,
            0x2663..0x2663, 0x2665..0x2666, 0x2668..0x2668, 0x267B..0x267B,
            0x267E..0x267E, 0x2692..0x2692, 0x2694..0x2697, 0x2699..0x2699,
            0x269B..0x269C, 0x26A0..0x26A0, 0x26A7..0x26A7, 0x26B0..0x26B1,
            0x26C8..0x26C8, 0x26CF..0x26CF, 0x26D1..0x26D1, 0x26D3..0x26D3,
            0x26E9..0x26E9, 0x26F0..0x26F1, 0x26F4..0x26F4, 0x26F7..0x26F9,
            0x2702..0x2702, 0x2708..0x2709, 0x270C..0x270D, 0x270F..0x270F,
            0x2712..0x2712, 0x2714..0x2714, 0x2716..0x2716, 0x271D..0x271D,
            0x2721..0x2721, 0x2733..0x2734, 0x2744..0x2744, 0x2747..0x2747,
            0x2763..0x2764, 0x27A1..0x27A1, 0x2934..0x2935, 0x2B05..0x2B07,
            0x3030..0x3030, 0x303D..0x303D, 0x3297..0x3297, 0x3299..0x3299
        ].freeze

        VERTICALS = "│┃║╎╏┆┇┊┋|"
        STRUCTURAL = /[─-╿|]/
        BOX_CHAR = /[─-╿]/

        # Box structure in ASCII: a line with one of these pairs, or a
        # | at its first or last non-blank column. The bare "--" is
        # guarded by word boundaries, so "--align" in a label and
        # "well--known" in a caption are words, not a rule.
        ASCII_STRUCT_PAIR =
            /\+-|-\+|(?<!\w)--(?!\w)|\|-|-\||\+\||\|\+|->|<-/
        INLINE_CODE = /`[^`\n]*`/

        # Exempts the one figure that follows it from the mixing check,
        # whatever comment syntax wraps it: <!-- artlint: allow-mixed -->,
        # # tessella: allow-mixed, ...
        MIXED_MARKER = /(?:artlint|tessella):\s*allow-mixed/

        # Comment-breaking sequences per host syntax, for forbid:.
        # :trailing_backslash is a positional check, not a substring.
        FORBID_PRESETS = {
            "xml" => ["--"], "html" => ["--"],
            "c-block" => ["*/", "/*"], "rust" => ["*/", "/*"],
            "c-line" => [:trailing_backslash],
            "haskell" => ["{-", "-}"], "ocaml" => ["(*", "*)"],
            "pascal" => ["}", "(*", "*)"], "d" => ["/+", "+/"],
            "lisp" => ["#|", "|#"], "lua" => ["]]"],
            "python-doc" => ['"""'], "cdata" => ["]]>"],
            "markdown-fence" => ["```", "~~~"]
        }.freeze

        DEFAULTS = { width: 78, prefix: "", web: false, forbid: [],
                     no_wide: false, ascii: false, allow_mixed: false,
                     fences: false, geometry: false, borders: [] }.freeze

        def self.wide?(code) = Width.char(code) == 2
        def self.invisible?(code) = Width.char(code).zero?

        def self.emoji_risk?(code) = EMOJI_RISK.any? { it.cover?(code) }

        def self.width_of(text) = text.each_char.sum { Width.char(it.ord) }

        def self.run(source, opts)
            resolved = Options.resolve(DEFAULTS.merge(opts))
            Runner.new(resolved).run(text(source))
        end

        # The source as UTF-8, invalid bytes kept for the lint to name:
        # a String of bytes, or an IO read to its end.
        def self.text(source)
            raw = source.respond_to?(:read) ? source.read : source
            unless raw.is_a?(String)
                raise ArgumentError, "source must be a String or IO: " \
                                     "#{source.inspect}"
            end

            raw.dup.force_encoding(Encoding::UTF_8)
        end
    end

    # Validates Tessella.lint's options: width a positive Integer,
    # prefix a String, and forbid a list of preset names or literal
    # sequences, resolved here to the sequences.
    module Lint
        module Options
            def self.resolve(opts)
                Check.positive_integer!(opts[:width], "width")
                unless opts[:prefix].is_a?(String)
                    raise ArgumentError, "prefix must be a String: " \
                                         "#{opts[:prefix].inspect}"
                end

                opts.merge(forbid: forbid(opts[:forbid]),
                           borders: borders(opts[:borders]))
            end

            # Each a Borders name, Set or glyph String, as its Set.
            def self.borders(list)
                Array(list).map do |style|
                    next Borders.custom(style).first if Borders.custom?(style)

                    Borders.fetch(style)
                end
            end

            def self.forbid(list)
                Array(list).flat_map do |seq|
                    seq = seq.to_s
                    raise ArgumentError, "forbid: empty sequence" if
                        seq.empty?

                    FORBID_PRESETS.fetch(seq) { [seq] }
                end
            end
        end
    end

    # width: 78, prefix: "", web: false, forbid: [], no_wide: false,
    # ascii: false, allow_mixed: false, fences: false, geometry: false,
    # borders: [] (Lint::DEFAULTS); returns a Lint::Report.
    def self.lint(source, **opts) = Lint.run(source, opts)

    # "ascii", or "utf-8" and the glyph classes the source holds.
    def self.alphabet(source) = Lint::Alphabet.of(Lint.text(source))
end
