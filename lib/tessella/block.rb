# frozen_string_literal: true

module Tessella
    # A finished figure as lines of text: what every module returns and
    # what composition takes (DESIGN.md, "Blocks and composition"). A
    # block is never rewritten, only padded on the right; its trailing
    # blank lines are dropped, a tab is refused (its width is up to the
    # viewer), and so is a block with no line left.
    class Block
        attr_reader :lines

        # A Block, a String, or anything whose to_s is the figure (a
        # chart): the composition functions take any of them.
        def self.from(figure)
            figure.is_a?(Block) ? figure : new(figure.to_s.lines(chomp: true))
        end

        def initialize(lines)
            lines = lines.map(&:to_s)
            lines.pop while lines.last&.strip&.empty?
            raise ArgumentError, "empty block" if lines.empty?

            check_tabs!(lines)
            @lines = lines.freeze
            freeze
        end

        def width = @lines.map { Width.of(it) }.max
        def height = @lines.size

        # Every line without its trailing blanks, each ended by "\n".
        def to_s = @lines.map { "#{it.rstrip}\n" }.join

        def ascii? = @lines.all?(&:ascii_only?)

        # The first line over max columns raises, naming its width.
        def check_width!(max)
            @lines.each_with_index do |line, i|
                w = Width.of(line.rstrip)
                next if w <= max

                raise ArgumentError, "output is #{w} columns on line " \
                                     "#{i + 1} (max-width #{max})"
            end
            self
        end

        private

        def check_tabs!(lines)
            i = lines.index { it.include?("\t") }
            raise ArgumentError, "line #{i + 1}: tab character" if i
        end
    end
end
