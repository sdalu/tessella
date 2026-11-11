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

        # One --ruler row: a line's rendered width (the prefix and
        # suffix included) and the display columns of its verticals.
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

        VERTICALS = "│┃║╎╏┆┇┊┋|"
        BRAILLE = /[\u2801-\u28FF]/
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

        DEFAULTS = { width: 78, prefix: "", suffix: "", web: false,
                     target: nil,
                     forbid: [],
                     no_wide: false, ascii: false, allow_mixed: false,
                     fences: false, geometry: false, borders: [] }.freeze

        def self.wide?(code) = Width.char(code) == 2
        def self.invisible?(code) = Width.char(code).zero?

        # A space separator (Zs) other than U+0020: U+00A0, U+202F,
        # U+3000, ... Drawn as a blank, so no display tells it from a
        # space, yet a figure holding one is always an accident.
        def self.look_alike_space?(ch) = ch != " " && ch.match?(/\p{Zs}/)

        def self.emoji_risk?(code) = Target.emoji_risk?(code)

        def self.width_of(text) = text.each_char.sum { Width.char(it.ord) }

        # Linted for opts[:target] (web: true is :web), else the
        # current one (Target): widths are that target's.
        def self.run(source, opts)
            resolved = Options.resolve(DEFAULTS.merge(opts))
            Target.with(resolved[:target]) do
                Runner.new(resolved).run(text(source))
            end
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
    # prefix and suffix Strings, and forbid a list of preset names or literal
    # sequences, resolved here to the sequences.
    module Lint
        module Options
            def self.resolve(opts)
                Check.positive_integer!(opts[:width], "width")
                %i[prefix suffix].each { string!(opts, it) }
                target = target(opts)
                opts.merge(forbid: forbid(opts[:forbid]),
                           borders: borders(opts[:borders]),
                           target: target, web: target == :web)
            end

            def self.string!(opts, key)
                return if opts[key].is_a?(String)

                raise ArgumentError, "#{key} must be a String: " \
                                     "#{opts[key].inspect}"
            end

            def self.target(opts)
                return Target.check!(opts[:target]) if opts[:target]

                opts[:web] ? :web : Target.current
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

    # width: 78, prefix: "", suffix: "", web: false, forbid: [],
    # no_wide: false, ascii: false, allow_mixed: false, fences: false,
    # geometry: false, borders: [] (Lint::DEFAULTS); returns a Lint::Report.
    def self.lint(source, **opts) = Lint.run(source, opts)

    # "ascii", or "utf-8" and the glyph classes the source holds.
    def self.alphabet(source) = Lint::Alphabet.of(Lint.text(source))
end
