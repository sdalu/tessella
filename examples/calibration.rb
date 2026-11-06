# frozen_string_literal: true

# examples/calibration.rb: measured points marked on a fitted line.
require "tessella"

xs = (0..20).map { it * 0.5 }
fit = Tessella.line(xs, xs.map { (0.5 * it) + 1 },
                    name: "fit", width: 30, height: 6, title: "calibration",
                    canvas: :block)
fit.add([1, 3, 4.5, 7, 9], [1.4, 2.7, 3.0, 4.9, 5.4],
        name: "measured", mark: "●")
puts fit
