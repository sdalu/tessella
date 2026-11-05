# frozen_string_literal: true

# examples/lint.rb: the lint from Ruby -- a figure tessella draws is
# clean by construction; a hand-drawn one is reported line by line,
# and the rulers show where its verticals stopped agreeing.
require "tessella"

chart = Tessella.bar(%w[ruby c rust], [12, 30, 7.5], width: 30)
puts "chart: #{Tessella.lint(chart.to_s, geometry: true).clean?}"

report = Tessella.lint(File.read("broken.txt"), geometry: true)
report.findings.each { puts "broken.txt:#{it.line}: #{it.message}" }

Tessella.lint(File.read("table-drift.txt")).rulers.each do |r|
    puts "line #{r.line}: verticals #{r.verticals.inspect}"
end
