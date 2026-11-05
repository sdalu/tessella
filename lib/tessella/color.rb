# frozen_string_literal: true

module Tessella
    # Colours to ANSI SGR, and nothing else (DESIGN.md, "Frame and
    # Color"). Color.wrap is the only way a cell or label becomes
    # coloured text; every other part treats colour as a value, never
    # an escape code. A colour is one of the eight basic names, a
    # 256-colour index (0..255), or a truecolor "#rrggbb".
    module Color
        NAMES = %i[red green yellow blue magenta cyan white].freeze

        CODES = {
            red: 31, green: 32, yellow: 33, blue: 34,
            magenta: 35, cyan: 36, white: 37
        }.freeze

        HEX = /\A#\h{6}\z/

        RESET = "\e[0m"

        # name nil => text as is, never an escape.
        def self.wrap(text, name)
            return text if name.nil?

            "\e[#{code(name)}m#{text}#{RESET}"
        end

        def self.code(color)
            case color
            when Integer then "38;5;#{color}" if valid?(color)
            when HEX then "38;2;#{rgb(color).join(";")}"
            else CODES[color.to_s.to_sym]
            end || (raise ArgumentError, "unknown colour: #{color}")
        end

        def self.valid?(color)
            return color.between?(0, 255) if color.is_a?(Integer)
            return true if color.is_a?(String) && color.match?(HEX)

            CODES.key?(color.to_s.to_sym)
        end

        # A colour from a command-line word: a name, an index, a #hex.
        def self.parse(word)
            return word.to_i if word.match?(/\A\d+\z/)

            word.start_with?("#") ? word.downcase : word.to_sym
        end

        def self.rgb(hex) = hex[1..].scan(/../).map { it.to_i(16) }
    end

    # A gradient: colours (stops) to one colour per row of a figure,
    # row 0 the bottom. Truecolor stops blend smoothly, the first stop
    # on the bottom row and the last on the top one; any other set is
    # split into equal bands, the first at the bottom.
    module Color
        module Gradient
            def self.check!(stops)
                return if stops.is_a?(Array) && !stops.empty? &&
                          stops.all? { Color.valid?(it) }

                raise ArgumentError, "gradient must be colours (names " \
                                     "#{Color::NAMES.join(", ")}, 0..255 " \
                                     "or #rrggbb): #{stops.inspect}"
            end

            # The colour of row (0 the bottom) of rows.
            def self.at(stops, row, rows)
                return band(stops, row.fdiv(rows)) unless smooth?(stops)

                blend(stops, rows > 1 ? row.fdiv(rows - 1) : 0.0)
            end

            def self.smooth?(stops)
                stops.size > 1 && stops.all?(String)
            end

            def self.band(stops, share)
                stops[[(share * stops.size).floor, stops.size - 1].min]
            end

            # The colour share (0..1) of the way through the stops.
            def self.blend(stops, share)
                pos = share.clamp(0.0, 1.0) * (stops.size - 1)
                i = [pos.floor, stops.size - 2].min
                mix(Color.rgb(stops[i]), Color.rgb(stops[i + 1]), pos - i)
            end

            def self.mix(from, to, t)
                rgb = from.zip(to).map { |a, b| (a + ((b - a) * t)).round }
                "##{rgb.map { format("%<v>02x", v: it) }.join}"
            end
        end
    end
end
