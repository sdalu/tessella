# frozen_string_literal: true

module Tessella
    module Lint
        # One lint run over one text: splits it into sections (the
        # whole text, or each fenced block), runs every check on each
        # in artlint.rb's order -- line by line, then shadows, mixing,
        # anchor drift, and geometry when asked -- and collects the
        # findings and ruler rows.
        class Runner
            include Lines
            include Shadows
            include Mixing
            include Drift
            include Geometry

            def initialize(opts)
                @opts = opts
                @overhead = Lint.width_of(opts[:prefix])
                @findings = []
                @rulers = []
            end

            def run(text)
                lines = text.each_line.map(&:chomp)
                sections(lines).each { check(it) }
                Report.new(findings: @findings, rulers: @rulers)
            end

            private

            def sections(lines)
                return Fences.sections(lines) if @opts[:fences]

                [Section.new(lines: lines, first: 1, exempt: false)]
            end

            def check(sec)
                sec = sanitized(sec)
                sec.lines.each_with_index { |line, i| check_line(sec, i, line) }
                check_shadows(sec)
                check_vocab_mixing(sec) unless @opts[:allow_mixed]
                check_anchor_drift(sec)
                check_geometry(sec) if @opts[:geometry]
            end

            def report(sec, index, message)
                @findings << Finding.new(line: sec.first + index,
                                         message: message)
            end

            # A row's last display column: the prefix, then the row.
            def end_column(line) = @overhead + Lint.width_of(line)

            def vertical_columns(line)
                col = @overhead
                line.each_char.filter_map do |ch|
                    col += Width.char(ch.ord)
                    col if VERTICALS.include?(ch)
                end
            end
        end
    end
end
