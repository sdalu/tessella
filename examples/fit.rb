# frozen_string_literal: true

# examples/fit.rb: a table fitted to a width. At 40 columns only the
# widest column narrows and wraps; at 26 it has come down to the next
# widest, and both narrow together. A cell holding a newline keeps its
# own lines. Fitted to 20, the table is refused, naming the width it
# needs.
require "tessella"

rows = Tessella::Table.parse(File.read("kinds.csv"))
rows << ["box", "none", "quartiles\nand whiskers"]
[40, 26, 20].each do |width|
    puts Tessella.table(rows, width: width)
rescue ArgumentError => e
    puts e.message
end
