# frozen_string_literal: true

module Tessella
    # Stem-and-leaf plot (DESIGN.md, "Chart and kinds"): one sample, or
    # two back to back, laid out as unicode_plot's stemplot does --
    # stems beside a divider, leaves beside that, a key line below.
    # Text laid out by its own rules, not a pixel canvas: Chart lends
    # option checking and ascii/colour handling only; its canvas,
    # frame and draw_series go unused.
    class Stem < Chart
        DEFAULT_SCALE = 10
        MAX_STEMS = 1000
        DIVIDER = "|"

        def initialize(values, other = nil, scale: nil, **)
            super(**)
            @scale = Check.positive!(scale || DEFAULT_SCALE, "scale")
            @left = leaves_by_stem(values)
            @right = other && leaves_by_stem(other)
            check_stem_count!([@left, @right].compact.flat_map(&:keys).uniq)
            @left_color = @color_on ? auto_color : nil
            @right_color = @color_on && @right ? auto_color : nil
        end

        def to_s
            body = @right ? back_to_back_lines : single_lines
            "#{(body + key_lines).map(&:rstrip).join("\n")}\n"
        end

        private

        def numeric!(value, what)
            return value if value.is_a?(Numeric)

            raise ArgumentError, "non-numeric #{what}: #{value.inspect}"
        end

        def leaves_by_stem(values)
            Check.finite!(Array(values), "value").each_with_object({}) do |v, h|
                stem, leaf = stem_and_leaf(v)
                (h[stem] ||= []) << leaf
            end
        end

        def stem_and_leaf(value)
            value = numeric!(value, "value")
            # Rounded first: 0.3 / 0.1 is 2.9999999999999996, and
            # truncating that would file 0.3 under leaf 2.
            scaled = value.to_f.fdiv(@scale / 10.0).round(9)
            whole = (scaled / 10).to_i
            frac = (scaled - (whole * 10)).to_i
            sign = value.negative? ? "-" : ""
            ["#{sign}#{whole.abs}", frac.abs.to_s]
        end

        def stems_for(*hashes)
            keys = hashes.compact.flat_map(&:keys).uniq
            neg, pos = keys.partition { it.start_with?("-") }
            negative_range(neg) + positive_range(pos)
        end

        # One line per stem from the lowest to the highest, empty ones
        # included: past MAX_STEMS that is a wall of text, not a chart.
        def check_stem_count!(keys)
            return if keys.empty?

            lo, hi = keys.map { it.start_with?("-") ? -it.to_i.abs : it.to_i }
                         .minmax
            count = hi - lo + 1 + (keys.any? { it.start_with?("-") } ? 1 : 0)
            return if count <= MAX_STEMS

            raise ArgumentError, "#{count} stems at scale " \
                                 "#{Axis.label(@scale)}: raise the scale"
        end

        def negative_range(keys)
            return [] if keys.empty?

            lo, hi = keys.map { it.to_i.abs }.minmax
            (lo..hi).to_a.reverse.map { "-#{it}" }
        end

        def positive_range(keys)
            return [] if keys.empty?

            lo, hi = keys.map(&:to_i).minmax
            (lo..hi).to_a.map(&:to_s)
        end

        def single_lines
            stems = stems_for(@left)
            width = stems.map(&:length).max || 0
            stems.map { single_line(it, width) }
        end

        def single_line(stem, width)
            leaves = Color.wrap((@left[stem] || []).sort.join, @left_color)
            "#{stem.rjust(width)} #{DIVIDER} #{leaves}"
        end

        def back_to_back_lines
            stems = stems_for(@left, @right)
            width = stems.map(&:length).max || 0
            left_width = @left.values.map(&:length).max || 0
            stems.map { back_to_back_line(it, width, left_width) }
        end

        def back_to_back_line(stem, width, left_width)
            left = Color.wrap(left_leaves(stem, left_width), @left_color)
            right = Color.wrap((@right[stem] || []).sort.join, @right_color)
            mid = stem.rjust(width + 1).ljust(width + 2)
            "#{left} #{DIVIDER}#{mid}#{DIVIDER} #{right}"
        end

        def left_leaves(stem, width)
            (@left[stem] || []).sort.join.reverse.rjust(width)
        end

        def key_lines = [key_line, decimal_line]
        def key_line = "Key: 1#{DIVIDER}0 = #{Axis.label(@scale)}"

        def decimal_line
            tens = Math.log10(@scale).truncate
            side = tens.negative? ? "left" : "right"
            "The decimal is #{tens.abs} digit(s) to the #{side} of #{DIVIDER}"
        end
    end

    # (values, other = nil, scale: nil, **opts): a stem-and-leaf plot,
    # or -- given other -- one back to back with it.
    def self.stem(*, **)
        Stem.new(*, **)
    end
end
