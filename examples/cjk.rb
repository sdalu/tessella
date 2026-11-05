# frozen_string_literal: true

# examples/cjk.rb: a table and a frame asked for in Unicode under the
# cjk target. Their inner widths are rounded up to whole border
# glyphs, so they close in a CJK terminal; read in a Western one, as
# here, the boxes look a column wide here and there.
require "tessella"

Tessella::Target.with(:cjk) do
    rows = Tessella::Table.parse(File.read("cities.csv"))
    puts Tessella.table(rows, ascii: false)
    puts Tessella.frame(File.read("note.txt"), ascii: false)
end
