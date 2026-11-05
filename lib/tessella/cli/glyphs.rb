# frozen_string_literal: true

module Tessella
    # `tessella glyphs` (DESIGN.md, "Glyphs"): the named glyph sets and
    # their width classes, and the width targets each is safe for
    # (--target T lists only those). No argument lists every set; KIND lists one
    # kind; KIND NAME lists one set glyph by glyph (code point, class);
    # --check GLYPHS classifies a set of one's own. Exit 0; 1 when
    # --check finds the glyphs mix classes; 2 usage (an unknown kind or
    # set, too many arguments).
    class GlyphsCLI
        class UsageError < StandardError; end
        # Raised by --help, carrying its text.
        class Help < StandardError; end

        BANNER = "Usage: tessella glyphs [--target T] [KIND [NAME]] | " \
                 "--check GLYPHS\n"
        KINDS = %w[border pattern meter rule ramp head].freeze

        def self.run(argv, stdout:, stderr:, **)
            opts = parse(argv.dup)
            return check(opts[:check], stdout) if opts[:check]

            stdout.print(listing(*opts[:args], target: opts[:target]))
            0
        rescue Help => e
            stdout.print(e.message)
            0
        rescue OptionParser::ParseError, UsageError, ArgumentError => e
            stderr.puts("tessella glyphs: #{e.message}")
            2
        end

        def self.parse(argv)
            opts = {}
            parser = OptionParser.new(BANNER)
            parser.on("--check GLYPHS", "classify a set of one's own") do |g|
                opts[:check] = g
            end
            target(parser, opts)
            parser.on("--help", "print this help") { raise Help, parser.to_s }
            opts[:args] = parser.parse!(argv)
            opts
        end

        def self.target(parser, opts)
            parser.on("--target T", Target::TARGETS.map(&:to_s),
                      "only the sets safe for term, cjk or web") do |t|
                opts[:target] = t.to_sym
            end
        end

        def self.listing(kind = nil, name = nil, *rest, target: nil)
            raise UsageError, "too many arguments" unless rest.empty?
            return detail(Glyphs.fetch(kind!(kind), name)) if name

            sets = Glyphs.all
            sets = sets.select { it.kind == kind!(kind) } if kind
            sets = sets.select { it.targets.include?(target) } if target
            sets.map { row(it) }.join
        end

        def self.kind!(kind)
            return kind.to_sym if KINDS.include?(kind)

            raise UsageError, "unknown kind: #{kind} (#{KINDS.join(", ")})"
        end

        def self.row(set)
            classes = set.classes.join("+")
            flag = set.mixed? ? "  mixed" : ""
            note = set.note ? "  (#{set.note})" : ""
            line = format("%<kind>-8s %<name>-18s %<cls>-4s %<safe>-13s " \
                          "%<glyphs>s",
                          kind: set.kind, name: set.name, cls: classes,
                          safe: set.targets.join(" "),
                          glyphs: set.glyphs.strip)
            "#{line}#{flag}#{note}\n"
        end

        def self.detail(set)
            set.glyphs.chars.uniq.reject { it == " " }.map do |g|
                format("%<g>s  U+%<code>04X  %<cls>s\n",
                       g: g, code: g.ord, cls: Width.class_of(g))
            end.join
        end

        def self.check(glyphs, stdout)
            classes = Width.classes(glyphs)
            mixed = classes.size > 1
            prefix = mixed ? "mixed: " : ""
            stdout.puts(prefix + classes.join(" "))
            stdout.puts("safe for: #{Glyphs.targets(glyphs).join(" ")}")
            mixed ? 1 : 0
        end
    end
end
