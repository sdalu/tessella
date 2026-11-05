# frozen_string_literal: true

module Tessella
    # The border glyph sets every framed figure draws with (a frame, a
    # table): corners, a horizontal and a vertical run. Under ascii:
    # true the set is "ascii" from the first byte; asking for another
    # one with it is refused rather than silently overridden.
    #
    # Besides the named sets, a custom one: a Set, or a String of six
    # glyphs in Set order (tl tr bl br h v), or of eleven for a table,
    # whose five more are its tees (top_t bot_t sep_l sep_t sep_r:
    # down from the top edge, up from the bottom one, and the left
    # tee, cross and right tee of a separator row). Each glyph is one
    # visible column; under ascii: true each must be ASCII.
    module Borders
        Set = Data.define(:tl, :tr, :bl, :br, :h, :v)

        STYLES = {
            light: Set.new("┌", "┐", "└", "┘", "─", "│"),
            heavy: Set.new("┏", "┓", "┗", "┛", "━", "┃"),
            double: Set.new("╔", "╗", "╚", "╝", "═", "║"),
            rounded: Set.new("╭", "╮", "╰", "╯", "─", "│"),
            dashed: Set.new("┌", "┐", "└", "┘", "┄", "┆"),
            dashed_fine: Set.new("┌", "┐", "└", "┘", "┈", "┊"),
            heavy_dashed: Set.new("┏", "┓", "┗", "┛", "┅", "┇"),
            heavy_dashed_fine: Set.new("┏", "┓", "┗", "┛", "┉", "┋"),
            double_h: Set.new("╒", "╕", "╘", "╛", "═", "│"),
            double_v: Set.new("╓", "╖", "╙", "╜", "─", "║"),
            ascii: Set.new("+", "+", "+", "+", "-", "|")
        }.freeze

        TEE_KEYS = %i[top_t bot_t sep_l sep_t sep_r].freeze

        def self.fetch(style, ascii: false)
            return custom(style, ascii: ascii).first if custom?(style)

            name = Borders.name(style || (ascii ? :ascii : :light))
            if ascii && name != :ascii
                raise ArgumentError, "style #{name} conflicts with ascii: true"
            end

            STYLES.fetch(name) do
                raise ArgumentError, "unknown style: #{name.inspect}"
            end
        end

        # A style's name as a Symbol: "double-h" and :double_h alike.
        def self.name(style) = style.to_s.tr("-", "_").to_sym

        # A Set, or a String that names no style: a glyph set.
        def self.custom?(style)
            style.is_a?(Set) ||
                (style.is_a?(String) && !STYLES.key?(name(style)) &&
                 !style.match?(/\A[a-z_-]+\z/))
        end

        # [Set, tees Hash or nil] for a custom style, checked.
        def self.custom(style, ascii: false)
            glyphs = style.is_a?(Set) ? style.to_h.values : style.chars
            unless [6, 11].include?(glyphs.size)
                raise ArgumentError, "a border set is 6 glyphs (tl tr bl br " \
                                     "h v), or 11 with a table's tees: " \
                                     "#{style.inspect}"
            end
            glyphs.each { check_glyph!(it, ascii) }
            [Set.new(*glyphs.first(6)), tees(glyphs)]
        end

        def self.tees(glyphs)
            glyphs.size == 11 ? TEE_KEYS.zip(glyphs.last(5)).to_h : nil
        end

        def self.check_glyph!(glyph, ascii)
            unless glyph.is_a?(String) && glyph.length == 1 &&
                   Width.of(glyph) == 1 && glyph.match?(/\A[[:graph:]]\z/)
                raise ArgumentError, "a border glyph is one visible " \
                                     "column: #{glyph.inspect}"
            end
            return unless ascii && !glyph.ascii_only?

            raise ArgumentError, "border glyph #{glyph} conflicts with " \
                                 "ascii: true"
        end
    end
end
