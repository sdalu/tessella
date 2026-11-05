# frozen_string_literal: true

module Tessella
    # Every image format tessella does not decode itself (JPEG, TIFF,
    # WebP, ...), through the rmagick gem when it is installed: a soft
    # dependency, never declared in the gemspec (DESIGN.md, "Images").
    # This is the one file under lib/tessella that may require, and it
    # requires only "rmagick", only when such an image arrives, so a
    # caller that never reads one never loads it.
    module RMagickReader
        GEM = "rmagick"

        def self.available?
            return @available unless @available.nil?

            @available = load_gem
        end

        def self.load_gem
            require GEM
            true
        rescue LoadError
            false
        end

        def self.decode(bytes)
            unless available?
                raise ArgumentError,
                      "not a PNM or PNG image, and the rmagick gem is not " \
                      "installed: install it, or convert the image first " \
                      "(magick IMAGE pgm:- | tessella image)"
            end
            raster(read(bytes))
        end

        def self.read(bytes)
            ::Magick::Image.from_blob(bytes).first
        rescue StandardError => e
            raise ArgumentError, "unreadable image: #{e.message}"
        end

        # RGBA as Integers in 0..QuantumRange, alpha over black.
        def self.raster(image)
            q = ::Magick::QuantumRange.to_f
            px = image.export_pixels(0, 0, image.columns, image.rows, "RGBA")
            luma = px.each_slice(4).map do |r, g, b, a|
                Raster.luma(r / q, g / q, b / q, a / q)
            end
            Raster.new(width: image.columns, height: image.rows, luma: luma)
        end
    end
end
