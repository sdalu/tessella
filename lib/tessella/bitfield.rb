# frozen_string_literal: true

module Tessella
    # Bitfield (ported byte for byte from the ascii-art skill's
    # scripts/bitfield.rb): an RFC-style packet / bit-field diagram --
    # a two-row bit ruler, "+-+" tick rows, and each field's name
    # centred in its own cell. Pure ASCII always; RFC 2360's own
    # convention, so there is no Unicode mode (no "ascii:" option).
    #
    # `fields` is either the script's "name:bits" text (# comments and
    # blank lines skipped) or an Array of [name, bits] pairs. A field
    # wider than the bits left in its row continues on the next
    # row(s), the name repeated (or truncated under abbrev:) in each
    # one, as RFC 791 draws its Options field.
    module Bitfield
        WORD_SIZES = [8, 16, 32, 64].freeze
        FIELD_RE = /\A\s*([^:]+?)\s*:\s*(\d+)\s*\z/

        Field = Struct.new(:name, :bits, :line)
        RowState = Struct.new(:cursor, :row, :rows)

        def self.block(fields, word:, octets:, ruler:, abbrev:)
            word!(word)
            rows = layout_rows(ascii_names!(fields_for(fields)), word, abbrev)
            show_ruler = ruler && !octets
            Block.new(render(rows, word, show_ruler, octets))
        end

        def self.word!(word)
            return word if WORD_SIZES.include?(word)

            raise ArgumentError, "word must be 8, 16, 32 or 64: " \
                                 "#{word.inspect}"
        end

        # The script's own text format, or the fields already given.
        # A bit-field is drawn in ASCII only, so its names must be.
        def self.ascii_names!(fields)
            fields.each_with_index do |f, i|
                next if f.name.ascii_only?

                where = f.line ? "line #{f.line}" : "field #{i + 1}"
                raise ArgumentError, "#{where}: name #{f.name.inspect} is " \
                                     "non-ASCII (a bit-field is ASCII)"
            end
        end

        def self.fields_for(fields)
            return parse(fields) if fields.is_a?(String)

            fields.each_with_index.map { |(name, bits), i| pair(name, bits, i) }
        end

        def self.pair(name, bits, index)
            unless bits.is_a?(Integer) && bits.positive?
                raise ArgumentError, "field #{index + 1} (#{name.inspect}): " \
                                     "bits must be a positive Integer: " \
                                     "#{bits.inspect}"
            end
            Field.new(name.to_s, bits, nil)
        end
    end

    # Parsing the "name:bits" text format: one field per line, "#"
    # comments and blank lines skipped.
    module Bitfield
        def self.parse(text)
            fields = text.each_line.with_index(1).filter_map do |raw, lineno|
                line = raw.chomp
                next if line.strip.empty? || line.lstrip.start_with?("#")

                parse_line(line, lineno)
            end
            raise ArgumentError, "no fields given" if fields.empty?

            fields
        end

        def self.parse_line(line, lineno)
            m = FIELD_RE.match(line)
            unless m
                raise ArgumentError,
                      "line #{lineno}: #{line.inspect} not name:bits"
            end
            Field.new(m[1], bits_for(m[2], line, lineno), lineno)
        end

        def self.bits_for(digits, line, lineno)
            bits = digits.to_i
            return bits unless bits.zero?

            raise ArgumentError, "line #{lineno}: #{line.inspect} has 0 bits"
        end
    end

    # Laying fields into rows of word: bits each, a field that outgrows
    # its row continuing on the next (RowState tracks the row being
    # filled, and the rows closed so far).
    module Bitfield
        # A name that already fits returns as-is; one too wide is bad
        # input unless abbrev truncates it to width - 1 characters plus
        # a dot.
        def self.fit_label(name, width, abbrev)
            return name if name.length <= width
            unless abbrev
                raise ArgumentError, "name #{name.inspect} needs " \
                                     "#{name.length} columns, this cell " \
                                     "only has #{width}"
            end
            "#{name[0, width - 1]}."
        end

        def self.close_row(state, word)
            return unless state.cursor == word

            state.rows << state.row
            state.row = []
            state.cursor = 0
        end

        def self.place_field(field, word, abbrev, state)
            remaining = field.bits
            until remaining.zero?
                take = [remaining, word - state.cursor].min
                label = fit_label(field.name, (2 * take) - 1, abbrev)
                state.row << { bits: take, label: label }
                state.cursor += take
                remaining -= take
                close_row(state, word)
            end
        end

        def self.layout_rows(fields, word, abbrev)
            state = RowState.new(0, [], [])
            fields.each { place_field(it, word, abbrev, state) }
            state.rows << state.row unless state.row.empty?
            state.rows
        end

        def self.row_bits(row) = row.sum { it[:bits] }
    end

    # Rendering rows into text lines: the bit ruler, a tick line per
    # row (and a closing one), and each row's content line.
    module Bitfield
        def self.tick_line(bits, step)
            positions = (0..bits).step(step).to_a
            positions << bits if positions.last != bits
            line = +"+"
            positions.each_cons(2) do |p0, p1|
                line << ("-" * ((2 * (p1 - p0)) - 1)) << "+"
            end
            line
        end

        def self.ruler_lines(word)
            tens = +""
            units = +""
            word.times do |i|
                tens << " " << ((i % 10).zero? ? (i / 10).to_s : " ")
                units << " " << (i % 10).to_s
            end
            [tens.rstrip, units.rstrip]
        end

        def self.content_line(segments)
            line = +"|"
            segments.each do |seg|
                line << Width.center(seg[:label], (2 * seg[:bits]) - 1) << "|"
            end
            line
        end

        def self.render(rows, word, show_ruler, octets)
            step = octets ? 8 : 1
            lines = show_ruler ? ruler_lines(word) : []
            rows.each do |row|
                lines << tick_line(row_bits(row), step)
                lines << content_line(row)
            end
            lines << tick_line(row_bits(rows.last), step)
            lines
        end
    end

    def self.bitfield(fields, word: 32, octets: false, ruler: true,
                      abbrev: false)
        Bitfield.block(fields, word: word, octets: octets, ruler: ruler,
                               abbrev: abbrev)
    end
end
