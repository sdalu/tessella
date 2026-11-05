# frozen_string_literal: true

module Tessella
    # `tessella lint` (DESIGN.md, "Lint"): checks text figures in files
    # or stdin, as the ascii-art skill's scripts/artlint.rb did -- its
    # options and output contract kept, --paranoid dropped (--ascii is
    # the flag). Findings on stderr as NAME:LINE: message, --ruler rows
    # on stdout; --alphabet prints NAME: ascii|utf-8 ... on stdout and
    # lints nothing. Exit 0 clean (or --alphabet); 1 a finding, or a
    # file that cannot be read; 2 usage.
    class LintCLI
        class UsageError < StandardError; end

        # Raised by --help to short-circuit parsing with the text and
        # status already decided.
        class Halt < StandardError
            attr_reader :status, :text

            def initialize(status, text)
                @status = status
                @text = text
                super(text)
            end
        end

        BANNER = "Usage: tessella lint [options] [file ...]  " \
                 "(stdin if none)\n"

        def self.run(argv, stdin:, stdout:, stderr:)
            opts, mode, paths = Options.parse(argv.dup)
            new(opts, stdout, stderr).run(mode, Inputs.list(paths, stdin))
        rescue Halt => e
            (e.status.zero? ? stdout : stderr).print(e.text)
            e.status
        rescue OptionParser::ParseError, UsageError, ArgumentError => e
            stderr.puts("tessella lint: #{e.message}")
            2
        end

        def initialize(opts, stdout, stderr)
            @opts = opts
            @stdout = stdout
            @stderr = stderr
        end

        # Every input, in order; an unreadable one is named and the
        # rest still linted.
        def run(mode, inputs)
            Tessella.lint("", **@opts) # an option's own value: usage
            statuses = inputs.map do |name, read|
                one(mode, name, read.call)
            rescue SystemCallError => e
                @stderr.puts("tessella lint: #{CLI.cannot_read(name, e)}")
                1
            end
            statuses.max || 0
        end

        private

        def one(mode, name, bytes)
            return alphabet(name, bytes) if mode == :alphabet

            report = Tessella.lint(bytes, **@opts.except(:ruler))
            rulers(name, report) if @opts[:ruler]
            report.findings.each do |f|
                @stderr.puts("#{name}:#{f.line}: #{f.message}")
            end
            report.clean? ? 0 : 1
        end

        def alphabet(name, bytes)
            @stdout.puts("#{name}: #{Tessella.alphabet(bytes)}")
            0
        end

        def rulers(name, report)
            report.rulers.each do |r|
                tail = if r.verticals.empty?
                           ""
                       else
                           "  verticals=" \
                               "#{r.verticals.join(",")}"
                       end
                @stdout.puts("#{name}:#{r.line}: width=#{r.width}#{tail}")
            end
        end
    end

    # The inputs as [name, reader] pairs: each file by its path, or
    # stdin named "stdin"; reading is deferred so an unreadable file
    # fails alone.
    class LintCLI
        module Inputs
            def self.list(paths, stdin)
                return [["stdin", -> { stdin.binmode.read }]] if paths.empty?

                paths.map { |path| [path, -> { File.binread(path) }] }
            end
        end
    end
end
