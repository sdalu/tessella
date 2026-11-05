# frozen_string_literal: true

module Tessella
    # The named glyph sets (DESIGN.md, "Glyphs"), from the ascii-art
    # skill's glyph palette and ui.md: border styles, fill patterns,
    # meter fill/track pairs, rule lines and tone ramps, each with the
    # width classes its glyphs fall into, computed from Width, never
    # typed in. A set whose glyphs span two classes is "mixed": fine in
    # Western terminals, but it changes length in CJK-configured ones.
    module Glyphs
        GlyphSet = Data.define(:kind, :name, :glyphs, :note) do
            def classes = Width.classes(glyphs)
            def mixed? = classes.size > 1
        end

        PATTERNS = {
            light: "░", medium: "▒", dark: "▓", solid: "█",
            hatch: "╱", backhatch: "╲", cross: "╳", grid: "┼",
            stipple: "∴∵", sparse: "·", dotted: "∘",
            dots: ".", colons: ":", hash: "#", at: "@"
        }.freeze

        # Fill then track, as ui.md's progress-bar styles.
        METERS = {
            arrow: "▸▹", chevron: "› ", classic: "= ", rectangle: "▮▯",
            wave: "~_", blade: "▰▱", button: "⦿⦾", block: "█·",
            box: "■□", circle: "●○", star: "★☆"
        }.freeze

        RULES = {
            light: "─", heavy: "━", double: "═", dashed: "┄", ascii: "-"
        }.freeze

        # Light to dense, a blank first.
        RAMPS = {
            ramp: " .:-=+*#%@", blocks: " ░▒▓█",
            long: " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZm" \
                  "wqpdbkhao*#MW&8%B@$",
            hatch: " ·∘╱╳"
        }.freeze

        NOTES = {
            blade: "patchy font coverage", button: "patchy font coverage",
            block: "house style: █ on a · track"
        }.freeze

        def self.all
            @all ||= [*borders, *table(:pattern, PATTERNS),
                      *table(:meter, METERS), *table(:rule, RULES),
                      *table(:ramp, RAMPS)].freeze
        end

        def self.borders
            Borders::STYLES.map do |name, set|
                GlyphSet.new(kind: :border, name: name,
                             glyphs: set.to_h.values.join, note: nil)
            end
        end

        def self.table(kind, sets)
            sets.map do |name, glyphs|
                note = kind == :meter ? NOTES[name] : nil
                GlyphSet.new(kind: kind, name: name, glyphs: glyphs, note: note)
            end
        end

        # The set of that kind and name, or ArgumentError naming both.
        def self.fetch(kind, name)
            key = Borders.name(name)
            all.find { it.kind == kind && it.name == key } or
                raise ArgumentError, "unknown #{kind}: #{name.inspect} " \
                                     "(#{names(kind).join(", ")})"
        end

        def self.names(kind) = all.select { it.kind == kind }.map(&:name)
    end
end
