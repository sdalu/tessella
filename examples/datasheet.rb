# frozen_string_literal: true

# examples/datasheet.rb: a register layout over its timing, as a
# datasheet draws them, stacked under one rule.
require "tessella"

register = Tessella.bitfield([["MODE", 4], ["DIV", 8], ["EN", 4]],
                             word: 16)
timing = Tessella.wave(<<~WAVE, period: 4)
    sclk: p.......
    cs:   10.....1
    mosi: x=.=.=.x | CMD ADDR DATA
WAVE
puts Tessella.stack(Tessella.caption(register, text: "CTRL (0x04)",
                                               above: true),
                    timing, gap: 1, rule: "─")
