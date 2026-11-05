# frozen_string_literal: true

# examples/gradient.rb: a Raster built in Ruby -- no image file --
# drawn in three styles, side by side.
require "tessella"

w = h = 48
luma = (0...h).flat_map do |y|
    (0...w).map { |x| Math.hypot(x - 24, y - 24) < 22 ? x / 47.0 : 0 }
end
raster = Tessella::Raster.new(width: w, height: h, luma: luma)
figs = %i[ramp blocks braille].map do |style|
    Tessella.caption(Tessella.image(raster, style: style, width: 16),
                     text: style.to_s)
end
puts Tessella.beside(*figs, gap: 3)
