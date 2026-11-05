# frozen_string_literal: true

# examples/refusals.rb: what the library refuses, and how it says so.
require "tessella"

[
    -> { Tessella.line([1, 2, 3], [1, 2]) },
    -> { Tessella.bar(%w[a b], [1, Float::NAN]) },
    -> { Tessella.line([1, 2], width: 0) },
    -> { Tessella.line([1, 2], colour: true) },
    -> { Tessella.tree("a\n   b\n  c") },
    -> { Tessella.frame("é", ascii: true) }
].each do |call|
    call.call
rescue ArgumentError => e
    puts "#{e.class}: #{e.message}"
end
