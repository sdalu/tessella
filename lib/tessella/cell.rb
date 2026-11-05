# frozen_string_literal: true

module Tessella
    # One character cell of a chart body: its glyph, and the colour name
    # it is drawn in (nil: none). Canvases produce rows of these; the
    # frame renders them (DESIGN.md).
    Cell = Data.define(:char, :color) do
        def self.blank = new(char: " ", color: nil)
    end
end
