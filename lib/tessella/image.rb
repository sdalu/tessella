# frozen_string_literal: true

module Tessella
    # A picture as text (DESIGN.md, "Images"): tone ramps, shade
    # blocks, half/quadrant/sextant/braille pixels, or Sobel edges,
    # with error-diffusion or ordered dithering. Ported from the
    # ascii-art skill's scripts/img2art.rb; Tessella.image is the
    # entry point, at the bottom of this file. Its --pad is dropped:
    # composition pads a block itself (DESIGN.md, "Blocks and
    # composition"), and a blank braille cell is U+0020, never
    # U+2800, so every other house rule (no trailing blank, ASCII
    # from the first byte) falls out of Block on its own.
    module Image
        RAMPS = { ramp: " .:-=+*#%@", blocks: " ░▒▓█" }.freeze
        QUAD = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"
        BRAILLE_BITS = [[0x01, 0x08], [0x02, 0x10], [0x04, 0x20],
                        [0x40, 0x80]].freeze
        # U+1FB00.. enumerates the 6-bit sextant subsets in binary
        # order (UL=1 UR=2 ML=4 MR=8 LL=16 LR=32), skipping empty/full
        # and the two half-blocks, which live in U+2580-259F.
        SEXTANT = (0..63).map do |v|
            case v
            when 0  then " "
            when 21 then "▌"
            when 42 then "▐"
            when 63 then "█"
            else [0x1FB00 + v - 1 - (v > 21 ? 1 : 0) - (v > 42 ? 1 : 0)]
                .pack("U")
            end
        end.freeze
        STYLES = %i[ramp blocks half quadrant sextant braille edges].freeze
        DITHERS = %i[none fs atkinson bayer].freeze
        SUBCELL = { ramp: [1, 1], blocks: [1, 1], half: [1, 2],
                    quadrant: [2, 2], sextant: [2, 3], braille: [2, 4],
                    edges: [1, 1] }.freeze
        DEFAULTS = { style: :ramp, width: 78, ramp: nil, gamma: 1.0,
                     threshold: 0.5, dither: :fs, invert: false,
                     edge_threshold: 0.3, ascii: false }.freeze

        # A picture whose every cell is blank (edges on a flat image, a
        # threshold above every tone) is refused as Blank, naming the
        # options to move, rather than returned as an empty figure.
        class Blank < ArgumentError; end

        def self.build(source, opts)
            raster = Source.raster(source)
            resolved = Options.resolve(DEFAULTS.merge(opts))
            rows = Renderer.rows(raster, resolved)
            if rows.all? { it.strip.empty? }
                raise Blank, blank_message(resolved)
            end

            Block.new(rows)
        end

        def self.blank_message(opts)
            knob = opts[:style] == :edges ? "edge_threshold" : "threshold"
            "the picture renders blank at style #{opts[:style]}: lower " \
                "#{knob}, or try invert or another style"
        end
    end

    # Validates Tessella.image's keyword options and resolves the
    # tone ramp, exactly as img2art.rb's OptionParser does, plus the
    # ASCII rule this library adds: ascii: true allows only
    # style: :ramp with an ASCII ramp (DESIGN.md).
    module Image
        class Options
            def self.resolve(opts)
                new(opts).resolve
            end

            def initialize(opts)
                @opts = opts
            end

            def resolve
                check_style!
                check_dither!
                Check.positive_integer!(@opts[:width], "width")
                check_numeric!
                chars = resolve_ramp
                check_ascii!(chars)
                @opts.merge(chars: chars)
            end

            private

            def check_style!
                return if Image::STYLES.include?(@opts[:style])

                raise ArgumentError, "unknown style: #{@opts[:style].inspect}"
            end

            def check_dither!
                return if Image::DITHERS.include?(@opts[:dither])

                raise ArgumentError,
                      "unknown dither: #{@opts[:dither].inspect}"
            end

            def check_numeric!
                Check.finite!([@opts[:gamma]], "gamma")
                Check.finite!([@opts[:threshold]], "threshold")
                Check.finite!([@opts[:edge_threshold]], "edge_threshold")
                Check.positive!(@opts[:gamma], "gamma")
            end

            def resolve_ramp
                ramp = @opts[:ramp]
                return check_custom_ramp!(ramp) if ramp

                Image::RAMPS.fetch(@opts[:style], Image::RAMPS[:ramp])
            end

            def check_custom_ramp!(ramp)
                raise ArgumentError, "ramp must not be empty" if ramp.empty?

                ramp
            end

            def check_ascii!(chars)
                return unless @opts[:ascii]

                check_ascii_style!
                return if chars.ascii_only?

                raise ArgumentError,
                      "ascii: true needs an ASCII ramp: #{chars.inspect}"
            end

            def check_ascii_style!
                return if @opts[:style] == :ramp

                raise ArgumentError,
                      "ascii: true allows only style: :ramp, not " \
                      "#{@opts[:style].inspect}"
            end
        end
    end

    # Tessella.image's source: a Raster already decoded, an IO to
    # read as image bytes (Raster.read), or a String of image bytes
    # (Raster.decode).
    module Image
        module Source
            def self.raster(source)
                return source if source.is_a?(Raster)
                return Raster.read(source) if source.respond_to?(:read)
                return Raster.decode(source) if source.is_a?(String)

                raise ArgumentError,
                      "source must be a Raster, IO, or String: " \
                      "#{source.inspect}"
            end
        end
    end

    # Floyd-Steinberg / Atkinson error diffusion, or a 4x4 Bayer
    # threshold matrix, turning a sampled luma grid into on/off
    # cells before a style's glyph table reads it. Ported from
    # img2art.rb's Dither, byte for byte but for dither: as a Symbol.
    module Image
        class Dither
            KERNELS = {
                fs: [[1, 0, 7], [-1, 1, 3], [0, 1, 5], [1, 1, 1]]
                    .map { |x, y, w| [x, y, w / 16.0] },
                atkinson: [[1, 0], [2, 0], [-1, 1], [0, 1], [1, 1], [0, 2]]
                          .map { |x, y| [x, y, 1 / 8.0] }
            }.freeze

            BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9],
                      [15, 7, 13, 5]].freeze

            def self.apply(grid, pw, ph, thr, mode)
                new(grid, pw, ph, thr).run(mode)
            end

            def initialize(grid, pw, ph, thr)
                @grid = grid
                @pw = pw
                @ph = ph
                @thr = thr
            end

            def run(mode)
                return bayer if mode == :bayer

                diffuse(KERNELS[mode])
            end

            private

            def bayer
                @grid.each_with_index.map do |v, i|
                    cell = BAYER4[(i / @pw) % 4][i % @pw % 4]
                    v > @thr + ((cell + 0.5) / 16.0) - 0.5
                end
            end

            def diffuse(kernel)
                return @grid.map { |v| v > @thr } unless kernel

                out = Array.new(@grid.size)
                (0...@ph).each { |y| row(out, y, kernel) }
                out
            end

            def row(out, y, kernel)
                (0...@pw).each do |x|
                    i = (y * @pw) + x
                    on = @grid[i] > @thr
                    out[i] = on
                    spread(x, y, @grid[i] - (on ? 1.0 : 0.0), kernel)
                end
            end

            def spread(x, y, err, kernel)
                kernel.each do |dx, dy, w|
                    nx = x + dx
                    ny = y + dy
                    next if nx.negative? || nx >= @pw || ny >= @ph

                    @grid[(ny * @pw) + nx] += err * w
                end
            end
        end
    end

    # Samples a Raster's luma into one float per output pixel (box
    # filter, gamma and polarity applied), then dithers it into
    # on/off cells for every style but ramp/blocks/edges, which read
    # the float tone directly. Ported from img2art.rb's
    # Renderer#sample, #box_mean, #value and #bits.
    module Image
        class Field
            def initialize(raster, cols, rows, opts)
                @raster = raster
                @cols = cols
                @rows = rows
                @sw, @sh = SUBCELL[opts[:style]]
                @pw = cols * @sw
                @ph = rows * @sh
                @gamma = opts[:gamma]
                @invert = opts[:invert]
                @thr = opts[:threshold]
                @dither = opts[:dither]
            end

            def tone(cx, cy) = sample(cx, cy, 1, 1)

            def on?(x, y) = bits[(y * @pw) + x]

            private

            def bits
                @bits ||= begin
                    grid = Array.new(@pw * @ph) do |i|
                        sample(i % @pw, i / @pw, @sw, @sh)
                    end
                    Dither.apply(grid, @pw, @ph, @thr, @dither)
                end
            end

            def sample(sx, sy, sw, sh)
                x0, x1 = span(sx, sw, @cols, @raster.width)
                y0, y1 = span(sy, sh, @rows, @raster.height)
                value(box_mean(x0, x1, y0, y1))
            end

            # One axis of a sample window: the source pixels an
            # output subcell at s (of cells subcells wide) covers,
            # at least one pixel even when size < cells * sub.
            def span(s, sub, cells, size)
                g = cells * sub
                a = s * size / g
                [a, [(s + 1) * size / g, a + 1].max]
            end

            def box_mean(x0, x1, y0, y1)
                sum = 0.0
                (y0...y1).each do |y|
                    (x0...x1).each do |x|
                        sum += @raster.luma[(y * @raster.width) + x]
                    end
                end
                sum / ((x1 - x0) * (y1 - y0))
            end

            def value(v)
                v = 1.0 - v if @invert
                v**@gamma
            end
        end
    end

    # One character per output cell, from a Field's on/off pixels or
    # tone, for every style. Ported from img2art.rb's Renderer#glyph
    # and its per-style methods.
    module Image
        class Glyphs
            SOBEL_X = [[-1, -1, -1], [-1, 0, -2], [-1, 1, -1],
                       [1, -1, 1], [1, 0, 2], [1, 1, 1]].freeze
            SOBEL_Y = [[-1, -1, -1], [0, -1, -2], [1, -1, -1],
                       [-1, 1, 1], [0, 1, 2], [1, 1, 1]].freeze

            def initialize(field, opts, cols, rows)
                @field = field
                @style = opts[:style]
                @chars = opts[:chars]
                @cols = cols
                @rows = rows
                @edge_thr = opts[:edge_threshold]
            end

            def glyph(cx, cy)
                case @style
                when :half     then half(cx, cy)
                when :quadrant then quadrant(cx, cy)
                when :sextant  then sextant(cx, cy)
                when :braille  then braille(cx, cy)
                when :edges    then edge(cx, cy)
                else                tone(cx, cy)
                end
            end

            private

            def tone(cx, cy)
                v = @field.tone(cx, cy)
                @chars[(v * (@chars.length - 1)).round]
            end

            def half(cx, cy)
                top = @field.on?(cx, cy * 2)
                bot = @field.on?(cx, (cy * 2) + 1)
                [" ", "▀", "▄", "█"][(top ? 1 : 0) | (bot ? 2 : 0)]
            end

            def quadrant(cx, cy)
                bits = 0
                [[0, 0, 1], [1, 0, 2], [0, 1, 4], [1, 1, 8]]
                    .each do |dx, dy, bit|
                        bits |= bit if @field.on?((cx * 2) + dx, (cy * 2) + dy)
                    end
                QUAD[bits]
            end

            def sextant(cx, cy)
                bits = 0
                (0...3).each do |dy|
                    (0...2).each do |dx|
                        bits |= 1 << ((dy * 2) + dx) if
                            @field.on?((cx * 2) + dx, (cy * 3) + dy)
                    end
                end
                SEXTANT[bits]
            end

            def braille(cx, cy)
                bits = 0
                (0...4).each do |dy|
                    (0...2).each do |dx|
                        bits |= BRAILLE_BITS[dy][dx] if
                            @field.on?((cx * 2) + dx, (cy * 4) + dy)
                    end
                end
                bits.zero? ? " " : [0x2800 | bits].pack("U")
            end

            def cell(cx, cy)
                @field.tone(cx.clamp(0, @cols - 1), cy.clamp(0, @rows - 1))
            end

            def edge(cx, cy)
                gx = SOBEL_X.sum { |dx, dy, w| w * cell(cx + dx, cy + dy) }
                gy = SOBEL_Y.sum { |dx, dy, w| w * cell(cx + dx, cy + dy) }
                return " " if Math.hypot(gx, gy) / 4.0 < @edge_thr

                stroke(gx, gy)
            end

            def stroke(gx, gy)
                deg = ((Math.atan2(gy, gx) * 180 / Math::PI) + 90) % 180
                return "─" if deg < 22.5 || deg >= 157.5
                return "╲" if deg < 67.5
                return "│" if deg < 112.5

                "╱"
            end
        end
    end

    # The finished grid of lines, one call per output cell through
    # Glyphs. img2art.rb joined rows with "\n" and trimmed each row's
    # own trailing blanks (--pad kept them); Block.new on the raw
    # rows does both instead (DESIGN.md), after the ASCII rule has
    # already run (Options).
    module Image
        class Renderer
            def self.rows(raster, opts)
                new(raster, opts).rows
            end

            def initialize(raster, opts)
                @cols = opts[:width]
                @rows = fit_rows(raster, @cols)
                field = Field.new(raster, @cols, @rows, opts)
                @glyphs = Glyphs.new(field, opts, @cols, @rows)
            end

            def rows = (0...@rows).map { |cy| row(cy) }

            private

            # Output rows follow the source aspect; a single row at
            # least, however wide the source or narrow the width.
            def fit_rows(raster, cols)
                [(raster.height * cols / (2.0 * raster.width)).round,
                 1].max
            end

            def row(cy)
                (0...@cols).map { |cx| @glyphs.glyph(cx, cy) }.join
            end
        end
    end

    # style: :ramp, width: 78, ramp: nil, gamma: 1.0, threshold: 0.5,
    # dither: :fs, invert: false, edge_threshold: 0.3, ascii: false
    # (Image::DEFAULTS) are every keyword's default; **opts keeps this
    # within the house parameter-count limit (as Chart#initialize
    # does), not a looser contract -- an unknown keyword is ignored,
    # exactly as a missing one falls back to its default.
    def self.image(source, **opts)
        Image.build(source, opts)
    end
end
