# frozen_string_literal: true

module Tessella
    # shadow: a drop shadow, as the ascii-art skill's ui.md draws it
    # and the lint checks it (DESIGN.md, "Blocks and composition"): the
    # glyph one column right of every row but the first, and a bottom
    # bar one row down, from one column in to that same column, so the
    # L closes at both ends. ░ by default, # under ascii: true.
    module Compose
        SHADOW = "░"
        ASCII_SHADOW = "#"

        def self.shadow(figure, glyph: nil, ascii: false)
            block, = blocks([figure], ascii)
            g = shadow_glyph!(glyph, ascii)
            width = block.width
            rows = block.lines.each_with_index.map do |line, i|
                i.zero? ? line : Width.ljust(line, width) + g
            end
            Block.new([*rows, " #{g * width}"])
        end

        def self.shadow_glyph!(glyph, ascii)
            glyph!(glyph || (ascii ? ASCII_SHADOW : SHADOW), "shadow glyph",
                   ascii)
        end

        # A glyph drawn into a figure: one visible column, ASCII under
        # ascii: true.
        def self.glyph!(glyph, what, ascii)
            unless glyph.is_a?(String) && glyph.length == 1 &&
                   Width.of(glyph) == 1 && glyph.match?(/\A[[:graph:]]\z/)
                raise ArgumentError, "#{what} must be one visible column: " \
                                     "#{glyph.inspect}"
            end
            text!(what, glyph, ascii)
        end
    end

    def self.shadow(...) = Compose.shadow(...)
end
