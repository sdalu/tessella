# frozen_string_literal: true

module Tessella
    # The border glyph sets every framed figure draws with (a frame, a
    # table): corners, a horizontal and a vertical run. Under ascii:
    # true the set is "ascii" from the first byte; asking for another
    # one with it is refused rather than silently overridden.
    module Borders
        Set = Data.define(:tl, :tr, :bl, :br, :h, :v)

        STYLES = {
            light: Set.new("┌", "┐", "└", "┘", "─", "│"),
            heavy: Set.new("┏", "┓", "┗", "┛", "━", "┃"),
            double: Set.new("╔", "╗", "╚", "╝", "═", "║"),
            rounded: Set.new("╭", "╮", "╰", "╯", "─", "│"),
            ascii: Set.new("+", "+", "+", "+", "-", "|")
        }.freeze

        def self.fetch(style, ascii: false)
            name = (style || (ascii ? :ascii : :light)).to_sym
            if ascii && name != :ascii
                raise ArgumentError, "style #{name} conflicts with ascii: true"
            end

            STYLES.fetch(name) do
                raise ArgumentError, "unknown style: #{name.inspect}"
            end
        end
    end
end
