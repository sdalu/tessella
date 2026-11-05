# frozen_string_literal: true

module Tessella
    # The family every tessella refusal belongs to.
    class Error < StandardError; end

    # A value in the data that cannot be drawn: not a finite number,
    # a negative pie slice, a candle whose low and high do not hold
    # it, an empty sample. An ArgumentError, as every bad argument
    # is, kept apart so the command line can call it bad input (exit
    # 1) rather than a usage mistake (exit 2).
    class ValueError < ArgumentError; end
end
