# frozen_string_literal: true

module Tessella
    # A pie's edge drawn to the shape (rim: :smooth or :basic): a cell
    # the disc (or a donut's hole) only partly covers takes the glyph
    # whose shape best fits that coverage, sampled as 4x8 -- ◢ ◣ ◤ ◥,
    # halves, quadrants, quarter and eighth blocks, Image's petscii
    # shapes -- in its slice's colour. The glyph is solid ink, so
    # without colour the rim reads as an outline rather than as its
    # slice's fill. :smooth adds Legacy Computing's 🮊 🮂 🮅, which
    # older fonts lack; :basic keeps to Block Elements and Geometric
    # Shapes. rim: :cells, the default, fills whole cells.
    module PieRim
        RIMS = %i[cells smooth basic].freeze
        BASIC = %w[█ ▀ ▄ ▌ ▐ ▘ ▝ ▖ ▗ ▚ ▞ ▙ ▛ ▜ ▟ ▏ ▕ ▔ ▁ ▊ ▂ ▆
                   ◢ ◣ ◤ ◥].freeze
        LEGACY = %W[\u{1FB8A} \u{1FB82} \u{1FB85}].freeze

        def initialize(**opts)
            super
            rim!
        end

        private

        def rim = Borders.name(@opts.fetch(:rim, :cells))
        def rim? = rim != :cells

        def rim!
            unless RIMS.include?(rim)
                raise ArgumentError, "rim must be one of #{RIMS.join(", ")}: " \
                                     "#{@opts[:rim].inspect}"
            end
            raise ArgumentError, "rim: #{rim} needs Unicode" if rim? && @ascii
        end

        # The cell as the rim draws it: blank, a shape, or nil when the
        # disc covers it whole (its slice's fill then).
        def rim_cell(x, y, w, slice)
            cover = coverage(x, y, w)
            return Cell.blank if cover.sum.zero?
            return nil if cover.sum == cover.size

            Cell.new(char: rim_glyph(cover), color: slice_color(slice))
        end

        def rim_glyph(cover)
            rim_shapes.min_by do |_, ink|
                ink.each_with_index.sum { |v, k| (v - cover[k])**2 }
            end.first
        end

        def rim_shapes
            @rim_shapes ||= Image::PETSCII.slice(
                *BASIC, *(rim == :smooth ? LEGACY : [])
            )
        end

        # 1.0 or 0.0 for each of the cell's 4x8 samples, row by row.
        def coverage(x, y, w)
            sw, sh = Image::PETSCII_SUB
            (0...sh).flat_map do |sy|
                (0...sw).map do |sx|
                    disc_ink(sample(x, sx, sw, w), sample(y, sy, sh, height))
                end
            end
        end

        def sample(cell, sub, subs, cells)
            ((cell + ((sub + 0.5) / subs)) - (cells / 2.0)) / (cells / 2.0)
        end

        def disc_ink(dx, dy)
            r = Math.hypot(dx, dy)
            r <= 1 && !(@opts[:donut] && r < Pie::HOLE) ? 1.0 : 0.0
        end
    end
end
