# frozen_string_literal: true

module Inkchart
    # Axis extremes and number labels for a chart's scale (DESIGN.md).
    module Axis
        INT64_RANGE =
            (-9_223_372_036_854_775_808..9_223_372_036_854_775_807)

        # lim [a, b] given and not [0, 0]: returned as is; otherwise the
        # data's extent widened to round values exactly as unicode_plot
        # widens it (its axis labels are the oracle).
        def self.limits(values, lim = nil)
            lim ||= [0, 0]
            auto = lim == [0, 0]
            mi, ma = (auto ? values : lim).minmax.map(&:to_f)
            mi, ma = widen(mi) if mi == ma
            auto ? narrow(mi, ma) : [mi, ma]
        end

        # Integer as is; Float in the shortest round-tripping form, no
        # exponent for |x| in 1e-4...1e15 (Ruby's own Float#to_s already
        # holds to that range, and keeps a Float's digits where an
        # Integer input has none).
        def self.label(number) = number.to_s

        # An axis extreme: limits are Floats, and a whole one prints
        # without its ".0" (10, not 10.0), as unicode_plot prints them;
        # any other value as label does. For value labels, use label.
        def self.tick(number)
            number = number.to_i if number.is_a?(Float) && roundable?(number)
            label(number)
        end

        def self.widen(mi) = [mi - 1, mi + 1]

        def self.narrow(mi, ma)
            diff = ma - mi
            lo = round_subtick(mi, diff, :down)
            hi = round_subtick(ma, diff, :up)
            [lo.to_f, hi.to_f]
        end

        def self.round_subtick(x, m, dir)
            return 0.0 if x.zero?

            digits = neg_log10_digits(m)
            up = dir == :up
            if x.positive?
                up ? x.ceil(digits) : x.floor(digits)
            else
                up ? -(-x).floor(digits) : -(-x).ceil(digits)
            end
        end

        def self.neg_log10_digits(m)
            v = -Math.log10(m)
            roundable?(v) ? v.ceil + 1 : v.floor + 1
        end

        def self.roundable?(x) = x.to_i == x && INT64_RANGE.cover?(x)
    end
end
