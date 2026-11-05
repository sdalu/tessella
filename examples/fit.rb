# frozen_string_literal: true

# examples/fit.rb: a table fitted to 40 columns; its widest column
# wraps, and a cell holding a newline keeps its own lines. Fitted to
# 20, it is refused, naming the width it needs.
require "tessella"

rows = Tessella::Table.parse(File.read("kinds.csv"))
rows << ["box", "none", "quartiles\nand whiskers"]
puts Tessella.table(rows, width: 40)
begin
    Tessella.table(rows, width: 20)
rescue ArgumentError => e
    puts e.message
end
