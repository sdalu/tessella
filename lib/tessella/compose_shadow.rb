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
            g = glyph || (ascii ? ASCII_SHADOW : SHADOW)
            unless g.is_a?(String) && g.length == 1 && Width.of(g) == 1 &&
                   g.match?(/\A[[:graph:]]\z/)
                raise ArgumentError, "shadow glyph must be one visible " \
                                     "column: #{g.inspect}"
            end
            text!("shadow glyph", g, ascii)
        end
    end

    def self.shadow(...) = Compose.shadow(...)
end
