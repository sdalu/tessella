# frozen_string_literal: true

module Tessella
    # A sparkline (DESIGN.md, "Meters and rules"): one line, one cell a
    # value, eight steps from the lowest to the highest -- "▁▂▃▅▇" -- or
    # eight ASCII levels under ascii: true. width: averages the values
    # into that many cells (or repeats them to fill it); min: and max:
    # fix the range, so lines drawn apart share one scale.
    module Sparkline
        RISE = "▁▂▃▄▅▆▇█"
        ASCII = "_.-:=+*#"

        def self.build(values, width: nil, min: nil, max: nil,
                       ascii: Target.ascii?)
            vals = Check.finite!(Array(values), "value")
            raise ArgumentError, "a sparkline needs values" if vals.empty?

            vals = resample(vals, Check.positive_integer!(width, "width")) if
                width
            glyphs = ascii ? ASCII : RISE
            lo, hi = range(vals, min, max)
            steps = glyphs.size
            Block.new([vals.map { glyphs[level(it, lo, hi, steps)] }.join])
        end

        def self.range(vals, min, max)
            lo = min || vals.min
            hi = max || vals.max
            Check.finite!([lo, hi], "min/max")
            raise ArgumentError, "min #{lo} is above max #{hi}" if lo > hi

            [lo, hi]
        end

        # The step for v: the middle one when every value is the same.
        def self.level(v, lo, hi, steps)
            return steps / 2 if hi == lo

            (v.clamp(lo, hi) - lo).fdiv(hi - lo).*(steps - 1).round
        end

        # width cells: the mean of the values falling in each, or the
        # nearest value when there are fewer values than cells.
        def self.resample(vals, width)
            n = vals.size
            (0...width).map do |i|
                lo = i * n / width
                hi = [((i + 1) * n / width), lo + 1].max
                bucket = vals[lo...hi]
                bucket.sum.fdiv(bucket.size)
            end
        end
    end

    # values, width: nil, min: nil, max: nil, ascii: false.
    def self.sparkline(values, **) = Sparkline.build(values, **)
end
