# frozen_string_literal: true

module Inkchart
    # Colour names to ANSI SGR, and nothing else (DESIGN.md, "Frame and
    # Color"). Color.wrap is the only way a cell or label becomes
    # coloured text; every other part treats colour as a name, never
    # an escape code.
    module Color
        NAMES = %i[red green yellow blue magenta cyan white].freeze

        CODES = {
            red: 31, green: 32, yellow: 33, blue: 34,
            magenta: 35, cyan: 36, white: 37
        }.freeze

        RESET = "\e[0m"

        # name nil => text as is, never an escape.
        def self.wrap(text, name)
            return text if name.nil?

            "\e[#{code(name)}m#{text}#{RESET}"
        end

        def self.code(name)
            CODES.fetch(name) { raise ArgumentError, "unknown colour: #{name}" }
        end
    end
end
