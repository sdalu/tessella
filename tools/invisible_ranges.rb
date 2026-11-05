# frozen_string_literal: true

# Prints Width's zero-width ranges (lib/tessella/width_invisible*.rb)
# from a Unicode UnicodeData.txt: every Mn and Me, the Hangul medial
# and final jamo, and the zero-width, format and variation-selector
# ranges Width has always held, less what WIDE already covers.
#
#   ruby tools/invisible_ranges.rb UnicodeData.txt
require_relative "../lib/tessella"

EXTRA = [0x1160..0x11FF, 0xD7B0..0xD7FF, 0x200B..0x200F, 0x2060..0x206F,
         0xFE00..0xFE0F, 0xFEFF..0xFEFF].freeze

def marks(path)
    codes = []
    first = nil
    File.foreach(path) do |line|
        code, name, category = line.split(";")
        cp = code.to_i(16)
        next first = cp if name.end_with?("First>")

        range = name.end_with?("Last>") ? (first..cp) : (cp..cp)
        codes.concat(range.to_a) if %w[Mn Me].include?(category)
    end
    codes
end

def ranges(codes)
    codes.sort.uniq.slice_when { |a, b| b != a + 1 }.map { it.first..it.last }
end

codes = marks(ARGV.fetch(0)) + EXTRA.flat_map(&:to_a)
codes = codes.select { it >= 0x300 && !Tessella::Width.in?(Tessella::Width::WIDE, it) }
ranges(codes).each do |range|
    puts format("0x%<lo>04X..0x%<hi>04X", lo: range.first, hi: range.last)
end
