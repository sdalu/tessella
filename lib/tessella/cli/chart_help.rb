# frozen_string_literal: true

module Tessella
    # `tessella chart --help`: the kinds and what each reads, and a
    # description of every option -- filled into the parser's switches
    # after they are built, so the option definitions stay short.
    class ChartCLI
        module Help
            BANNER = <<~TEXT
                Usage: tessella chart [options] [file]  (stdin if none)

                Kinds (--kind) and the columns they read, a row a line:
                  line, scatter, stairs, density  y; x y; or x and a y a series
                  bar          label value; or label and a value a series
                  histogram    values (one column)
                  box          a column a box, a header naming them
                  stem         one column, or two back to back
                  heatmap      label then a row of values
                  candlestick  x open high low close
                  pie          label value

                Options (some only for the kinds named):
            TEXT

            DESCRIPTIONS = {
                "--kind" => ["the chart kind (default line)"],
                "--width" => ["plot columns (default 40)"],
                "--height" => ["plot rows (default 15)"],
                "--title" => ["a title above the frame"],
                "--xlabel" => ["the x axis label"],
                "--ylabel" => ["the y axis label"],
                "--xlim" => ["the x range, A,B"],
                "--ylim" => ["the y range, A,B"],
                "--canvas" => ["braille, block (quadrant), half, sextant,",
                               "octant (Unicode 16), dot,",
                               "ascii, density, or eighths (--area)"],
                "--ascii" => ["ASCII only, from the first byte"],
                "--color" => ["ANSI colours (off by default)"],
                "--xscale" => ["ln, log2 or log10 on x"],
                "--yscale" => ["ln, log2 or log10 on y (plotted kinds)"],
                "--xdate" => ["x is ISO 8601 dates; FMT a strftime",
                              "format (plotted kinds, candlestick)"],
                "--yerr" => ["x y error: error bars (line, scatter)"],
                "--threshold" => ["a dashed rule at N (line, scatter,",
                                  "stairs)"],
                "--above" => ["colour beyond --threshold (red)"],
                "--below" => ["colour before --threshold"],
                "--bins" => ["histogram bins (Sturges by default)"],
                "--closed" => ["histogram bins closed left or right"],
                "--orientation" => ["horizontal or vertical: the value",
                                    "axis's direction"],
                "--blocks" => ["bar glyphs: eighths, braille, block,",
                               "quadrant, half, sextant or octant"],
                "--cell-width" => ["heatmap columns a cell (2)"],
                "--colormap" => ["heatmap colours, C,C,... (--color)"],
                "--min" => ["heatmap range bottom"],
                "--max" => ["heatmap range top"],
                "--donut" => ["pie: a ring, hollow in the middle"],
                "--style" => ["stairs: post or pre"],
                "--scale" => ["stem: the stem unit"],
                "--area" => ["fill under the line (line, stairs)"],
                "--gradient" => ["area colours by height, C,C,... or",
                                 "none (--color)"],
                "--stacked" => ["bar: stack the series"],
                "--fill" => ["bar glyph (█, # in ASCII)"],
                "--no-eighths" => ["bar: whole cells only"],
                "--track" => ["bar track glyph, or none"],
                "--help" => ["print this help"],
                "--version" => ["print the version"]
            }.freeze

            # Each switch's description from DESCRIPTIONS, by its long
            # name (--[no-]x and --no-x alike).
            def self.describe!(parser)
                parser.top.list.each do |switch|
                    name = Array(switch.long).first.to_s
                    text = DESCRIPTIONS[name.sub("[no-]", "")]
                    switch.desc.replace(text) if text && switch.desc.empty?
                end
            end
        end
    end
end
