# frozen_string_literal: true

module Tessella
    # A pure-Ruby PNG decoder (DESIGN.md, "Images"): the whole
    # still-image core of the format -- chunk parsing with CRC,
    # colour types 0/2/3/4/6, bit depths 1/2/4/8/16, all five filter
    # types, Adam7 interlacing, tRNS -- so a PNG needs no gem and no
    # external program. `zlib` (a bundled default gem, required by
    # lib/tessella.rb, never this file) does the inflating; nothing
    # else outside the standard library is used.
    module Png
        SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

        # Chunk parsing: length/type/data/CRC framing, with the CRC
        # checked against Zlib.crc32 and unknown critical chunks
        # refused. Ancillary chunks (gAMA, sRGB, iCCP, tEXt, APNG's
        # acTL/fcTL/fdAT, ...) are skipped without being named here --
        # their first byte alone (lower case) says they are skippable.
        module Chunks
            KNOWN = %w[IHDR PLTE IDAT IEND tRNS].freeze

            def self.parse(bytes)
                offset = 8
                chunks = []
                loop do
                    chunk, offset = read(bytes, offset)
                    chunks << chunk
                    break if chunk[:type] == "IEND"
                end
                chunks
            end

            def self.read(bytes, offset)
                check_available(bytes, offset, 8)
                length = bytes.byteslice(offset, 4).unpack1("N")
                type = bytes.byteslice(offset + 4, 4)
                refuse_unknown_critical(type)
                data, crc_at = body(bytes, offset, length)
                verify_crc(bytes, type, data, crc_at)
                [{ type: type, data: data }, crc_at + 4]
            end

            def self.body(bytes, offset, length)
                crc_at = offset + 8 + length
                check_available(bytes, crc_at, 4)
                [bytes.byteslice(offset + 8, length), crc_at]
            end

            def self.check_available(bytes, offset, needed)
                return if bytes.bytesize >= offset + needed

                raise ArgumentError, "truncated PNG stream"
            end

            def self.refuse_unknown_critical(type)
                return if type[0] =~ /[a-z]/ || KNOWN.include?(type)

                raise ArgumentError, "unknown critical chunk: #{type}"
            end

            def self.verify_crc(bytes, type, data, crc_at)
                expected = bytes.byteslice(crc_at, 4).unpack1("N")
                return if Zlib.crc32(type + data) == expected

                raise ArgumentError, "bad CRC in #{type} chunk"
            end

            def self.data_for(chunks, type)
                chunks.find { it[:type] == type }&.fetch(:data)
            end

            def self.idat(chunks)
                parts = chunks.select { it[:type] == "IDAT" }
                raise ArgumentError, "missing IDAT chunk" if parts.empty?

                parts.map { it[:data] }.join
            end

            def self.ihdr(chunks)
                first = chunks.first
                return first[:data] if first && first[:type] == "IHDR"

                raise ArgumentError, "missing IHDR chunk"
            end
        end

        # The bit depths each colour type allows (the spec's own
        # table), keyed by colour type.
        HEADER_DEPTHS = {
            0 => [1, 2, 4, 8, 16], 2 => [8, 16], 3 => [1, 2, 4, 8],
            4 => [8, 16], 6 => [8, 16]
        }.freeze

        # IHDR, as a Data value: width, height, bit_depth, colour_type,
        # interlace -- the fields later stages need; compression and
        # filter method are checked here and then dropped, since the
        # spec fixes both to 0.
        Header = Data.define(
            :width, :height, :bit_depth, :colour_type, :interlace
        ) do
            def self.from_ihdr(chunks)
                data = Chunks.ihdr(chunks)
                unless data.bytesize == 13
                    raise ArgumentError, "bad IHDR chunk length"
                end

                w, h, depth, type, comp, filt, inter = data.unpack("NNC5")
                header = new(width: w, height: h, bit_depth: depth,
                             colour_type: type, interlace: inter)
                header.check!(comp, filt)
                header
            end

            def check!(compression, filter_method)
                Check.positive_integer!(width, "width")
                Check.positive_integer!(height, "height")
                check_depth
                check_methods(compression, filter_method)
            end

            def check_depth
                allowed = HEADER_DEPTHS[colour_type]
                return if allowed&.include?(bit_depth)

                raise ArgumentError,
                      "invalid colour type/bit depth: " \
                      "#{colour_type}/#{bit_depth}"
            end

            def check_methods(compression, filter_method)
                return if compression.zero? && filter_method.zero? &&
                          [0, 1].include?(interlace)

                raise ArgumentError,
                      "unsupported PNG compression, filter or interlace"
            end
        end

        # The palette (PLTE), as [r, g, b] 0..255 triples; required
        # only for colour type 3, read (but unused for luma) otherwise.
        module Palette
            def self.parse(header, chunks)
                data = Chunks.data_for(chunks, "PLTE")
                return nil unless header.colour_type == 3
                raise ArgumentError, "missing PLTE chunk" unless data
                unless (3..768).cover?(data.bytesize) &&
                       (data.bytesize % 3).zero?
                    raise ArgumentError, "bad PLTE chunk length"
                end

                data.unpack("C*").each_slice(3).to_a
            end
        end

        # tRNS, in whatever shape its colour type gives it: a single
        # grey sample value (type 0), an [r, g, b] sample triple
        # (type 2), or one alpha byte per palette index, padded with
        # opaque (255) past the chunk's own length (type 3).
        module Trns
            def self.parse(header, data, palette)
                return nil unless data

                case header.colour_type
                when 0 then data.unpack1("n")
                when 2 then data.unpack("n3")
                when 3 then palette_alpha(data, palette)
                end
            end

            def self.palette_alpha(data, palette)
                alpha = data.unpack("C*")
                Array.new(palette.size) { |i| alpha[i] || 255 }
            end
        end

        # Scanline defiltering (the spec's five filter types), byte by
        # byte, independent of colour type and bit depth: both only
        # set the row length and the pixel stride ("bpp") the Sub,
        # Average and Paeth filters look back by.
        module Unfilter
            def self.rows(header, data, offset, width, height)
                channels = Pixels.channel_count(header.colour_type)
                bpp = stride(header.bit_depth, channels)
                row_size = row_bytes(width, channels, header.bit_depth)
                prior = "\x00".b * row_size
                rows = Array.new(height) do
                    filter, row, offset = read_row(data, offset, row_size)
                    prior = apply(filter, row, prior, bpp)
                end
                [rows, offset]
            end

            def self.stride(bit_depth, channels)
                [((bit_depth * channels) + 7) / 8, 1].max
            end

            def self.row_bytes(width, channels, bit_depth)
                ((width * channels * bit_depth) + 7) / 8
            end

            def self.read_row(data, offset, row_size)
                if data.bytesize < offset + 1 + row_size
                    raise ArgumentError, "truncated PNG image data"
                end

                filter = data.getbyte(offset)
                row = data.byteslice(offset + 1, row_size).dup
                [filter, row, offset + 1 + row_size]
            end

            def self.apply(filter, row, prior, bpp)
                case filter
                when 0 then row
                when 1 then sub(row, bpp)
                when 2 then up(row, prior)
                when 3 then average(row, prior, bpp)
                when 4 then paeth(row, prior, bpp)
                else raise ArgumentError, "bad filter type: #{filter}"
                end
            end

            def self.sub(row, bpp)
                row.bytesize.times do |i|
                    a = i >= bpp ? row.getbyte(i - bpp) : 0
                    row.setbyte(i, (row.getbyte(i) + a) & 0xff)
                end
                row
            end

            def self.up(row, prior)
                row.bytesize.times do |i|
                    row.setbyte(i, (row.getbyte(i) + prior.getbyte(i)) &
                                    0xff)
                end
                row
            end

            def self.average(row, prior, bpp)
                row.bytesize.times do |i|
                    a = i >= bpp ? row.getbyte(i - bpp) : 0
                    v = row.getbyte(i) + ((a + prior.getbyte(i)) / 2)
                    row.setbyte(i, v & 0xff)
                end
                row
            end

            def self.paeth(row, prior, bpp)
                row.bytesize.times do |i|
                    a = i >= bpp ? row.getbyte(i - bpp) : 0
                    b = prior.getbyte(i)
                    c = i >= bpp ? prior.getbyte(i - bpp) : 0
                    row.setbyte(i, (row.getbyte(i) + predict(a, b, c)) &
                                   0xff)
                end
                row
            end

            def self.predict(a, b, c)
                p = a + b - c
                pa = (p - a).abs
                pb = (p - b).abs
                pc = (p - c).abs
                return a if pa <= pb && pa <= pc
                return b if pb <= pc

                c
            end
        end

        # Adam7 interlacing geometry: each of the 7 passes is a
        # defiltered sub-image of its own width and height, placed
        # into the full width x height grid at (xstart + rx * xstep,
        # ystart + ry * ystep); a non-interlaced image is the same
        # walk with a single, whole-image "pass".
        module Interlace
            PASSES = [
                [0, 0, 8, 8], [4, 0, 8, 8], [0, 4, 4, 8], [2, 0, 4, 4],
                [0, 2, 2, 4], [1, 0, 2, 2], [0, 1, 1, 2]
            ].freeze
            WHOLE = [[0, 0, 1, 1]].freeze

            def self.decode(header, data)
                passes = header.interlace == 1 ? PASSES : WHOLE
                check_length(header, data, passes)
                grid = Array.new(header.height) { Array.new(header.width) }
                offset = 0
                passes.each do |geom|
                    offset = pass(header, data, offset, geom, grid)
                end
                grid
            end

            # The image data must hold every pass's rows before a grid
            # the header's size is allocated: a few bytes may claim
            # any width and height up to 2**31 - 1.
            def self.check_length(header, data, passes)
                return if data.bytesize >= byte_count(header, passes)

                raise ArgumentError, "truncated PNG image data"
            end

            def self.byte_count(header, passes)
                channels = Pixels.channel_count(header.colour_type)
                passes.sum do |xs, ys, xstep, ystep|
                    pw = dimension(header.width, xs, xstep)
                    ph = dimension(header.height, ys, ystep)
                    next 0 if pw.zero?

                    ph * (1 + Unfilter.row_bytes(pw, channels,
                                                 header.bit_depth))
                end
            end

            def self.pass(header, data, offset, geom, grid)
                xs, ys, xstep, ystep = geom
                pw = dimension(header.width, xs, xstep)
                ph = dimension(header.height, ys, ystep)
                return offset if pw.zero? || ph.zero?

                rows, offset = Unfilter.rows(header, data, offset, pw, ph)
                place(header, rows, pw, geom, grid)
                offset
            end

            def self.dimension(total, start, step)
                return 0 if start >= total

                ((total - start - 1) / step) + 1
            end

            def self.place(header, rows, pw, geom, grid)
                xs, ys, xstep, ystep = geom
                rows.each_with_index do |row, ry|
                    pixels = Pixels.samples(header, row, pw)
                    pixels.each_with_index do |px, rx|
                        grid[ys + (ry * ystep)][xs + (rx * xstep)] = px
                    end
                end
            end
        end

        # Samples out of a defiltered row (1/2/4/8/16-bit, big-endian),
        # grouped into one array per pixel, and the luma each colour
        # type turns its pixels into -- alpha, from the channel or
        # tRNS, composited over black as Raster.luma defines.
        module Pixels
            CHANNELS = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.freeze

            def self.channel_count(colour_type) = CHANNELS.fetch(colour_type)

            def self.samples(header, row, width)
                channels = channel_count(header.colour_type)
                values = extract(row, header.bit_depth, width * channels)
                values.each_slice(channels).to_a
            end

            def self.extract(row, bit_depth, count)
                return row.unpack("C#{count}") if bit_depth == 8
                return row.unpack("n#{count}") if bit_depth == 16

                sub_byte(row, bit_depth, count)
            end

            def self.sub_byte(row, bit_depth, count)
                per_byte = 8 / bit_depth
                mask = (1 << bit_depth) - 1
                Array.new(count) do |i|
                    byte = row.getbyte(i / per_byte)
                    shift = bit_depth * (per_byte - 1 - (i % per_byte))
                    (byte >> shift) & mask
                end
            end

            def self.luma_values(header, palette, trns, grid)
                max = (2**header.bit_depth) - 1
                grid.flat_map do |row|
                    row.map { |px| luma(header, palette, trns, px, max) }
                end
            end

            def self.luma(header, palette, trns, px, max)
                case header.colour_type
                when 0 then grey(px, trns, max)
                when 2 then rgb(px, trns, max)
                when 3 then indexed(px, palette, trns)
                when 4 then grey_alpha(px, max)
                when 6 then rgba(px, max)
                end
            end

            def self.grey(px, trns, max)
                g = px[0].fdiv(max)
                Raster.luma(g, g, g, px[0] == trns ? 0.0 : 1.0)
            end

            def self.rgb(px, trns, max)
                r, g, b = px
                Raster.luma(r / max.to_f, g / max.to_f, b / max.to_f,
                            px == trns ? 0.0 : 1.0)
            end

            def self.indexed(px, palette, trns)
                entry = palette[px[0]]
                unless entry
                    raise ArgumentError, "palette index #{px[0]} out of " \
                                         "range (#{palette.size} entries)"
                end

                r, g, b = entry
                alpha = trns ? trns[px[0]] : 255
                Raster.luma(r / 255.0, g / 255.0, b / 255.0, alpha / 255.0)
            end

            def self.grey_alpha(px, max)
                g, a = px
                gg = g / max.to_f
                Raster.luma(gg, gg, gg, a / max.to_f)
            end

            def self.rgba(px, max)
                r, g, b, a = px
                Raster.luma(r / max.to_f, g / max.to_f, b / max.to_f,
                            a / max.to_f)
            end
        end

        def self.decode(bytes)
            chunks = Chunks.parse(check_signature(bytes.b))
            header = Header.from_ihdr(chunks)
            palette = Palette.parse(header, chunks)
            trns = Trns.parse(
                header, Chunks.data_for(chunks, "tRNS"), palette
            )
            grid = Interlace.decode(header, inflate(Chunks.idat(chunks)))
            luma = Pixels.luma_values(header, palette, trns, grid)
            to_raster(header, luma)
        end

        def self.to_raster(header, luma)
            Raster.new(width: header.width, height: header.height,
                       luma: luma)
        end

        def self.check_signature(bytes)
            return bytes if bytes.start_with?(SIGNATURE)

            raise ArgumentError, "not a PNG stream (bad signature)"
        end

        def self.inflate(data)
            Zlib::Inflate.inflate(data)
        rescue Zlib::Error => e
            raise ArgumentError, "zlib error: #{e.message}"
        end
    end
end
