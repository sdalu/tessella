# frozen_string_literal: true

# examples/load.rb: a bar chart and a table side by side, framed and
# captioned -- composition of any two figures.
require "tessella"

rows = Tessella::Table.parse(File.read("langs.csv"))
labels = rows.drop(1).map(&:first)
values = rows.drop(1).map { Integer(it[1], exception: false) || it[1].to_f }
plot = Tessella.bar(labels, values, width: 20)
table = Tessella.table(rows, style: :rounded)
fig = Tessella.beside(plot, table, gap: 2, align: :middle)
puts Tessella.caption(Tessella.frame(fig, title: "Load"),
                      text: "Figure 1: lines of code, in thousands")
