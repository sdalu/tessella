# frozen_string_literal: true

module Tessella
    # A greyscale image to draw as text (DESIGN.md, "Images"): width,
    # height, and luma -- width * height Floats in 0..1, row by row,
    # top row first, 1.0 the brightest. Colour becomes luma by Rec. 601
    # (0.299 R + 0.587 G + 0.114 B); an alpha channel is composited over
    # black, so a transparent pixel is empty under the default polarity.
    Raster = Data.define(:width, :height, :luma) do
        def initialize(width:, height:, luma:)
            Check.positive_integer!(width, "width")
            Check.positive_integer!(height, "height")
            if luma.size < width * height
                raise ArgumentError, "raster too short: #{luma.size} " \
                                     "values for #{width}x#{height}"
            end
            super
        end

        # Rec. 601 luma of an RGB triple in 0..1, alpha (0..1) over black.
        def self.luma(red, green, blue, alpha = 1.0)
            ((0.299 * red) + (0.587 * green) + (0.114 * blue)) * alpha
        end

        # The format, by the bytes' own signature: PNM (P2 P3 P5 P6) and
        # PNG are decoded here, in Ruby; anything else needs RMagick.
        def self.decode(bytes)
            bytes = bytes.b
            return Pnm.decode(bytes) if bytes.start_with?(/P[2356]\s/n)
            return Png.decode(bytes) if bytes.start_with?(Png::SIGNATURE)

            RMagickReader.decode(bytes)
        end

        def self.read(io) = decode(io.binmode.read)
    end

    # PGM / PPM, plain (P2 P3) and binary (P5 P6), maxval up to 65535,
    # "#" comments in the header -- as the ascii-art skill's img2art.rb
    # reads them.
    module Pnm
        HEADER = /\A(P[2356])(?:\s|\#[^\n]*\n)+(\d+)
                  (?:\s|\#[^\n]*\n)+(\d+)(?:\s|\#[^\n]*\n)+(\d+)\s/xn

        def self.decode(bytes)
            m = HEADER.match(bytes) or
                raise ArgumentError, "not a PGM/PPM (P2/P3/P5/P6) stream"
            magic, width, height, maxval = m[1], *m[2..4].map(&:to_i)
            check_maxval(maxval)
            values = samples(magic, maxval, bytes[m.end(0)..])
            luma = %w[P3 P6].include?(magic) ? rgb(values) : values
            Raster.new(width: width, height: height, luma: luma)
        end

        def self.samples(magic, maxval, raster)
            ints = if %w[P2 P3].include?(magic)
                       plain_samples(raster)
                   else
                       raster.unpack(maxval < 256 ? "C*" : "n*")
                   end
            check_samples(ints, maxval)
            ints.map { it.fdiv(maxval) }
        end

        # A plain (P2/P3) raster's samples: decimal digits only, so a
        # "-128" or an "x" is refused rather than read as a number.
        def self.plain_samples(raster)
            raster.split.map do |token|
                unless token.match?(/\A\d+\z/)
                    raise ArgumentError, "PNM sample is not a number: " \
                                         "#{token.inspect}"
                end
                token.to_i
            end
        end

        def self.check_maxval(maxval)
            return if (1..65_535).cover?(maxval)

            raise ArgumentError, "PNM maxval out of 1..65535: #{maxval}"
        end

        def self.check_samples(ints, maxval)
            over = ints.find { it > maxval }
            return unless over

            raise ArgumentError, "PNM sample #{over} above maxval #{maxval}"
        end

        def self.rgb(values) = values.each_slice(3).map { Raster.luma(*it) }
    end
end
