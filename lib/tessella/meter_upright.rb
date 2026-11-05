# frozen_string_literal: true

module Tessella
    # A meter standing up (orientation: :vertical): the bar a column of
    # height: cells (8 by default), filled from the bottom -- the block
    # style tops its fill by eighths, ▁ to ▇ -- between a ─ above and
    # below (- in ASCII; none with brackets: false), the title over it
    # and the percentage under it, each line centred on the bar. Meters
    # side by side are `compose beside`'s.
    module MeterUpright
        RISE = " ▁▂▃▄▅▆▇".chars.freeze

        def self.build(share, opts)
            Check.positive_integer!(opts[:height], "height")
            column = column(share, opts[:height], Meter.glyphs(opts),
                            Meter.eighths?(opts))
            Block.new(centre(lines(share, column, opts)))
        end

        # The bar's cells, top to bottom.
        def self.column(share, height, glyphs, eighths)
            fill, track = glyphs
            units = (share * height * (eighths ? 8 : 1)).round
            full, rem = eighths ? units.divmod(8) : [units, 0]
            cells = Array.new(full, fill)
            cells << RISE[rem] unless rem.zero?
            (Array.new(height - cells.size, track) + cells.reverse)
        end

        def self.lines(share, column, opts)
            cap = opts[:ascii] ? "-" : "─"
            bar = opts[:brackets] ? [cap, *column, cap] : column
            [Meter.title_of(opts), *bar,
             (Meter.percent(share) if opts[:label])].compact
        end

        # Every line centred on the widest; trailing blanks dropped.
        def self.centre(lines)
            widest = lines.map { Width.of(it) }.max
            lines.map { Width.center(it, widest).rstrip }
        end
    end
end
