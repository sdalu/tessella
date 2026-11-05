# frozen_string_literal: true

module Tessella
    # Composition (DESIGN.md, "Blocks and composition"): a frame around
    # a block, blocks side by side or stacked, a prefix on every line, a
    # caption. Each takes figures (Block.from) and returns a Block,
    # measuring by display width, so a CJK table and a braille chart
    # line up. A block's own lines are never rewritten, only padded on
    # the right -- except stack's center:, which shifts a narrower
    # block as a whole. Under ascii: true the glyphs added are ASCII and
    # a non-ASCII block or text is refused.
    module Compose
        ALIGNS = %i[top middle bottom].freeze

        def self.blocks(figures, ascii)
            figures.each_with_index.map do |figure, i|
                block = Block.from(figure)
                if ascii && !block.ascii?
                    raise ArgumentError,
                          "block #{i + 1} is non-ASCII under ascii: true"
                end
                block
            end
        end

        def self.text!(name, text, ascii)
            return text unless ascii && !text.to_s.ascii_only? &&
                               !Target.text_free?

            raise ArgumentError, "#{name} is non-ASCII under ascii: true"
        end

        def self.count!(name, value)
            return value if value.is_a?(Integer) && !value.negative?

            raise ArgumentError, "#{name} must be an Integer >= 0: " \
                                 "#{value.inspect}"
        end

        def self.align!(align)
            return align.to_sym if ALIGNS.include?(align&.to_sym)

            raise ArgumentError, "unknown align: #{align.inspect}"
        end
    end

    # frame: a box around one block, title centred in the top edge;
    # pad: is horizontal only, the frame hugs its content vertically.
    # Its inner width is a whole number of border glyphs, so under
    # target :cjk, where a Unicode box glyph takes two columns, the
    # frame still closes.
    module Compose
        # fill: a pattern for the background the frame adds, halo: as
        # Compose.fill's (compose_fill.rb).
        # rubocop:disable-next Metrics/ParameterLists
        def self.frame(figure, title: nil, style: nil, pad: 1,
                       ascii: Target.ascii?, fill: nil, halo: true)
            block, = blocks([figure], ascii)
            text!("title", title, ascii)
            g = Borders.fetch(style, ascii: ascii)
            field = frame_field(block, title, count!("pad", pad), g.h)
            framed = Block.new([frame_top(g, title, field),
                                *frame_rows(block, g, pad, field),
                                g.bl + Width.run(g.h, field) + g.br])
            fill ? fill_frame(framed, fill, ascii, halo) : framed
        end

        # The width inside the frame: the block and its pads, or room
        # for the title and a run of border on each side, in whole h.
        def self.frame_field(block, title, pad, h)
            least = [block.width + (2 * pad),
                     title ? Width.of(title) + 4 : 0].max
            Width.round_up(least, Width.of(h))
        end

        def self.frame_rows(block, g, pad, field)
            inner = field - (2 * pad)
            margin = " " * pad
            block.lines.map do |l|
                g.v + margin + Width.ljust(l, inner) + margin + g.v
            end
        end

        def self.frame_top(g, title, field)
            return g.tl + Width.run(g.h, field) + g.tr unless title

            g.tl + titled(g.h, deco(title, field, Width.of(g.h)), field) +
                g.tr
        end

        # " title ", a blank more when the border around it would
        # otherwise end half a glyph short.
        def self.deco(title, field, unit)
            deco = " #{title} "
            deco += " " until ((field - Width.of(deco)) % unit).zero?
            deco
        end

        # deco centred in a run of h field columns long, the odd one
        # right; h whole, so under :cjk a two-column one splits evenly.
        def self.titled(h, deco, field)
            rest = field - Width.of(deco)
            unit = Width.of(h)
            left = (rest / unit / 2) * unit
            Width.run(h, left) + deco + Width.run(h, rest - left)
        end
    end

    # beside: blocks side by side, each padded to its own width, the
    # shorter ones filled vertically by align:.
    module Compose
        def self.beside(*figures, gap: 1, align: :top, ascii: Target.ascii?)
            raise ArgumentError, "beside takes two figures or more" if
                figures.size < 2

            cols = columns(blocks(figures, ascii), align!(align))
            sep = " " * count!("gap", gap)
            Block.new((0...cols.first.size).map do |i|
                cols.map { it[i] }.join(sep)
            end)
        end

        def self.columns(blocks, align)
            height = blocks.map(&:height).max
            blocks.map do |b|
                w = b.width
                vertical(b.lines.map { Width.ljust(it, w) }, height, align, w)
            end
        end

        def self.vertical(lines, height, align, width)
            extra = height - lines.size
            top = { top: 0, middle: extra / 2, bottom: extra }.fetch(align)
            blank = " " * width
            ([blank] * top) + lines + ([blank] * (extra - top))
        end
    end

    # stack: blocks one under another; rule: draws one separator line
    # as wide as the widest block, gap: blank rows around it (or between
    # blocks without one); center: centres a narrower block as a whole.
    module Compose
        def self.stack(*figures, gap: 0, rule: nil, center: false,
                       ascii: Target.ascii?)
            raise ArgumentError, "stack takes two figures or more" if
                figures.size < 2

            list = blocks(figures, ascii)
            width = list.map(&:width).max
            list = list.map { centred(it, width) } if center
            Block.new(joined(list, separator(gap, rule!(rule, ascii), width)))
        end

        def self.rule!(rule, ascii)
            return nil if rule.nil?
            unless rule.length == 1
                raise ArgumentError,
                      "rule must be one character: #{rule.inspect}"
            end

            text!("rule", rule, ascii)
        end

        def self.centred(block, width)
            own = block.width
            left = (width - own) / 2
            margin = [" " * left, " " * (width - own - left)]
            Block.new(block.lines.map do |l|
                margin[0] + Width.ljust(l, own) + margin[1]
            end)
        end

        # gap blank rows between blocks, or gap on each side of a rule.
        def self.separator(gap, rule, width)
            rows = [""] * count!("gap", gap)
            rule ? rows + [rule * width] + rows : rows
        end

        def self.joined(blocks, separator)
            blocks.each_with_index.flat_map do |b, i|
                i.zero? ? b.lines : separator + b.lines
            end
        end
    end

    # indent: prefix: on every line, a blank line taking the prefix
    # without its trailing blank; caption: one centred line of text:,
    # above: or below the block, a blank line between.
    module Compose
        def self.indent(figure, prefix:, ascii: Target.ascii?)
            block, = blocks([figure], ascii)
            text!("prefix", prefix, ascii)
            Block.new(block.lines.map do |l|
                l.empty? ? prefix.rstrip : prefix + l
            end)
        end

        def self.caption(figure, text:, above: false, ascii: Target.ascii?)
            block, = blocks([figure], ascii)
            cap = Width.center(text!("text", text, ascii), block.width)
            Block.new(above ? [cap, "", *block.lines] : [*block.lines, "", cap])
        end
    end

    def self.frame(...) = Compose.frame(...)
    def self.beside(...) = Compose.beside(...)
    def self.stack(...) = Compose.stack(...)
    def self.indent(...) = Compose.indent(...)
    def self.caption(...) = Compose.caption(...)
end
