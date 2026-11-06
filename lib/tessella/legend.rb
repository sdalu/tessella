# frozen_string_literal: true

module Tessella
    # What tells series apart where colour may be off -- a fill each,
    # one width class, so at most 12 series (pie slices, bar series) --
    # and a legend set under a frame: its entries two blanks apart,
    # wrapped into lines no wider than the frame's body, or than the
    # widest entry, which is never split.
    module Legend
        FILLS = %w[█ ▓ ▒ ░ ╳ ╱ ╲ ∴ ● ○ ■ ·].freeze
        ASCII_FILLS = %w[# = + @ * : . o % & ~ x].freeze

        def self.fills!(count, what)
            return if count <= FILLS.size

            raise ArgumentError, "at most #{FILLS.size} #{what}, one a fill"
        end

        def self.wrap(entries, width)
            limit = [width, *entries.map { Width.of(it) }].max
            entries.each_with_object([]) do |entry, lines|
                last = lines.last
                if last && Width.of(last) + 2 + Width.of(entry) <= limit
                    last << "  " << entry
                else
                    lines << +entry
                end
            end.join("\n")
        end
    end
end
