# frozen_string_literal: true

module AsciiArt
    # Binning, percentiles, and the value transforms a chart's scale can
    # apply before drawing (DESIGN.md, Stats and Axis).
    module Stats
        # edges ascending; counts.size == edges.size - 1; every value
        # lands in exactly one bin (DESIGN.md).
        Histogram = Data.define(:edges, :counts, :closed)

        TRANSFORMS = {
            ln: ->(x) { Math.log(x) },
            log2: ->(x) { Math.log2(x) },
            log10: ->(x) { Math.log10(x) }
        }.freeze
        IDENTITY = ->(x) { x }.freeze

        # bins: nil picks the count enumerable-statistics' Array#histogram
        # picks for the same data (Sturges' rule); closed: :left means
        # [a, b), :right (a, b].
        def self.histogram(values, bins: nil, closed: :left)
            left = left_closed?(closed)
            return empty_histogram(left) if values.empty?

            edges = histogram_edges(values, bins, left)
            counts = bin_counts(values, edges, left)
            Histogram.new(edges: edges, counts: counts,
                          closed: left ? :left : :right)
        end

        # ps in 0..100, linear interpolation between order statistics
        # (the definition enumerable-statistics uses).
        def self.percentiles(values, ps)
            sorted = values.sort
            ps.map { percentile(sorted, it) }
        end

        def self.transform(name)
            return IDENTITY if name.nil? || name == :identity

            TRANSFORMS.fetch(name) do
                raise ArgumentError, "unknown transform: #{name.inspect}"
            end
        end

        def self.left_closed?(closed)
            return true if closed == :left
            return false if closed == :right

            raise ArgumentError,
                  "closed must be :left or :right, got #{closed.inspect}"
        end

        def self.empty_histogram(left)
            Histogram.new(edges: [0.0], counts: [],
                          closed: left ? :left : :right)
        end

        def self.percentile(sorted, p)
            raise ArgumentError, "percentile out of bounds" if
                p.negative? || p > 100

            n = sorted.size
            return sorted.first.to_f if n == 1

            d = (n - 1) * p / 100.0
            i = d.floor
            interpolate(sorted, i, d - i, n)
        end

        def self.interpolate(sorted, i, f, n)
            return sorted[i].to_f if f.zero? || i == n - 1

            ((sorted[i] * (1 - f)) + (sorted[i + 1] * f)).to_f
        end

        def self.histogram_edges(values, bins, left)
            nbins = bins || sturges(values.size)
            raise ArgumentError, "bins must be >= 1, got #{nbins}" if
                nbins < 1

            lo, hi = values.minmax.map(&:to_f)
            Edges.calculate(lo, hi, nbins, left)
        end

        def self.sturges(n) = n.zero? ? 1 : (Math.log2(n).ceil + 1)

        def self.bin_counts(values, edges, left)
            counts = Array.new(edges.size - 1, 0)
            values.each do |v|
                bi = bin_index(edges, v.to_f, left)
                counts[bi] += 1 if bi.between?(0, counts.size - 1)
            end
            counts
        end

        def self.bin_index(edges, x, left)
            inside = left ? ->(e) { e <= x } : ->(e) { e < x }
            lo = -1
            hi = edges.size
            while hi - lo > 1
                mid = lo + ((hi - lo) / 2)
                inside.call(edges[mid]) ? lo = mid : hi = mid
            end
            left ? lo : hi - 1
        end

        # The edges unicode_plot's Array#histogram computes: a bin width
        # rounded to a nice step (1/2/5 x a power of ten), then widened
        # on both sides until it covers the data (closed-side dependent).
        module Edges
            State = Struct.new(:start, :step, :divisor, :len)

            def self.calculate(lo, hi, nbins, left)
                state = state_for(lo, hi, nbins)
                extend!(state, lo, hi, left)
                build(state)
            end

            def self.state_for(lo, hi, nbins)
                return State.new(hi, unit_step(hi), 1.0, 1) if lo == hi

                bw = (hi - lo) / nbins
                lbw = Math.log10(bw)
                return wide(lo, hi, bw, lbw) if lbw >= 0

                narrow(lo, hi, bw, lbw)
            end

            # A constant's one bin is [v, v + 1), as unicode_plot's; from
            # about 1e16 up v + 1 == v, so the width grows by tens until
            # the bin holds v.
            def self.unit_step(v)
                step = 1.0
                step *= 10 while v + step == v
                step
            end

            def self.wide(lo, hi, bw, lbw)
                base = 10.0**lbw.floor
                step = base * multiplier(bw / base)
                start = step * (lo / step).floor
                State.new(start, step, 1.0, ((hi - start) / step).ceil)
            end

            def self.narrow(lo, hi, bw, lbw)
                base = 10.0**-lbw.floor
                divisor = base / multiplier(bw * base)
                start = (lo * divisor).floor
                State.new(start, 1.0, divisor,
                          ((hi * divisor) - start).ceil)
            end

            def self.multiplier(r)
                return 1 if r <= 1.1
                return 2 if r <= 2.2
                return 5 if r <= 5.5

                10
            end

            def self.extend!(state, lo, hi, left)
                shrink!(state, lo, left)
                grow!(state, hi, left)
            end

            def self.shrink!(state, lo, left)
                if left
                    state.start -= state.step while
                        lo < state.start / state.divisor
                else
                    state.start -= state.step while
                        lo <= state.start / state.divisor
                end
            end

            def self.grow!(state, hi, left)
                if left
                    state.len += 1 while at(state, state.len) <= hi
                else
                    state.len += 1 while at(state, state.len) < hi
                end
            end

            def self.at(state, len)
                (state.start + ((len - 1) * state.step)) / state.divisor
            end

            def self.build(state)
                edges = []
                state.len.times do
                    edges << (state.start / state.divisor)
                    state.start += state.step
                end
                edges
            end
        end
    end
end
