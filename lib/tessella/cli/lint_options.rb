# frozen_string_literal: true

module Tessella
    # Parses `tessella lint`'s argv into Tessella.lint's options (plus
    # :ruler), the mode (:lint or :alphabet), and the file arguments.
    # Raises Halt for --help; lets OptionParser::ParseError escape for
    # a bad flag or a missing argument.
    class LintCLI
        class Options
            def self.parse(argv)
                new.parse(argv)
            end

            def initialize
                @opts = { width: 78, prefix: "", suffix: "", ruler: false,
                          forbid: [], borders: [] }
                @mode = :lint
                @parser = OptionParser.new
                @parser.banner = LintCLI::BANNER
                build
            end

            def parse(argv)
                @parser.parse!(argv)
                [@opts, @mode, argv]
            end

            private

            def build
                add_budget
                add_forbid
                add_glyph_flags
                add_figure_flags
                add_modes
            end

            def add_budget
                @parser.on("--width N", Integer,
                           "column budget (default 78)") { @opts[:width] = it }
                @parser.on("--prefix STR", "string rendered before each line,",
                           "charged to the budget") { @opts[:prefix] = it }
                @parser.on("--suffix STR", "string rendered after each line,",
                           "charged to the budget") { @opts[:suffix] = it }
                @parser.on("--ruler", "print each line's width and the",
                           "columns of its verticals") { @opts[:ruler] = true }
            end

            def add_forbid
                presets = Lint::FORBID_PRESETS.keys.each_slice(5)
                                              .map { "#{it.join(", ")}," }
                presets[-1] = presets[-1].chomp(",")
                @parser.on("--forbid SEQ", "flag lines holding SEQ, or a",
                           "preset's sequences:", *presets) do |seq|
                    @opts[:forbid] << seq
                end
            end

            def add_glyph_flags
                @parser.on("--target T", Target::TARGETS.map(&:to_s),
                           "term (default), cjk: ambiguous glyphs 2",
                           "columns, or web: as --web") do |t|
                    @opts[:target] = t.to_sym
                end
                flag("--web", :web, "web-viewed target: flag emoji-capable",
                     "glyphs, and wide glyphs on aligned rows")
                flag("--no-wide", :no_wide, "flag wide (2-cell) glyphs")
                flag("--ascii", :ascii, "flag every non-ASCII glyph",
                     "(implies --no-wide)")
            end

            def add_figure_flags
                flag("--allow-mixed", :allow_mixed, "skip the check for ASCII",
                     "and Unicode structure mixed")
                flag("--fences", :fences, "lint each Markdown fenced block",
                     "on its own")
                flag("--geometry", :geometry, "check box sides, and that",
                     "connectors hang from something")
                @parser.on("--border GLYPHS", "a custom border set geometry",
                           "reads (6 glyphs: tl tr bl br h v)") do |set|
                    @opts[:borders] << set
                end
            end

            def add_modes
                @parser.on("--alphabet", "print each input's alphabet (ascii,",
                           "or utf-8 and its glyph classes);",
                           "lint nothing, exit 0") { @mode = :alphabet }
                @parser.on("--help", "print this help") do
                    raise LintCLI::Halt.new(0, @parser.to_s)
                end
            end

            def flag(name, key, *text)
                @parser.on(name, *text) { @opts[key] = true }
            end
        end
    end
end
