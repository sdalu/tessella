# frozen_string_literal: true

module Tessella
    # The argument checks every kind shares: each raises ArgumentError
    # naming what it refused, before anything is drawn.
    module Check
        def self.positive_integer!(value, name)
            return value if value.is_a?(Integer) && value.positive?

            raise ArgumentError,
                  "#{name} must be a positive Integer: #{value.inspect}"
        end

        def self.positive!(value, name)
            return value if value.is_a?(Numeric) && value.positive?

            raise ArgumentError, "#{name} must be positive: #{value.inspect}"
        end

        # Only a finite number can be placed on an axis: nil, a String,
        # NaN or +-Infinity is refused, and what produced it (data, or
        # an xscale over a value <= 0) is named.
        def self.finite!(values, name)
            i = values.index { !finite_number?(it) }
            return values unless i

            raise ArgumentError,
                  "#{name} must be a finite number: #{values[i].inspect}"
        end

        def self.finite_number?(value)
            value.is_a?(Numeric) && (!value.is_a?(Float) || value.finite?)
        end

        def self.same_size!(a, b, names)
            return if a.size == b.size

            raise ArgumentError, "#{names[0]} and #{names[1]} differ in " \
                                 "length: #{a.size} and #{b.size}"
        end
    end
end
