# frozen_string_literal: true

# examples/floors.rb: one table fitted to 70 columns twice. With one
# floor for every column, the variable name is cut with the path; with
# a floor per column, the names keep their width and the path alone
# wraps. A list of the wrong length is refused.
require "tessella"

rows = [
    %w[name variable path mode size age],
    ["tado-pairing", "CLIMAT_PAIRING",
     "/home/user/.config/climat-control/tado-pairing.json", "0600",
     "1.2 kB", "3 d"]
]
puts Tessella.table(rows, width: 70, min_width: 4)
puts Tessella.table(rows, width: 70, min_width: [12, 14, 12, 4, 6, 7])
begin
    Tessella.table(rows, width: 70, min_width: [12, 14])
rescue ArgumentError => e
    puts e.message
end
