# frozen_string_literal: true

require_relative "test_helper"

# The scaffold's own promises: the library loads in its declared order,
# and the gemspec ships no runtime dependency (D1).
class TestScaffold < Minitest::Test
    def test_loads
        assert_match(/\A\d+\.\d+\.\d+\z/, Tessella::VERSION)
    end

    def test_no_runtime_dependency
        path = File.expand_path("../tessella.gemspec", __dir__)
        spec = Gem::Specification.load(path)
        assert_empty spec.runtime_dependencies
    end

    LIB = File.expand_path("../lib", __dir__)
    SOFT = "#{LIB}/tessella/rmagick_reader.rb".freeze

    CLI_ENTRY = "#{LIB}/tessella/cli.rb".freeze

    # Two entries require: lib/tessella.rb (the library) and
    # lib/tessella/cli.rb (the command line, on top of it). The one
    # other exception (DESIGN.md, "Images"): rmagick_reader.rb loads
    # the optional rmagick gem, and nothing else.
    def test_only_the_entries_require_tessella_files
        files = Dir["#{LIB}/tessella/**/*.rb"] - [SOFT, CLI_ENTRY]
        offenders = files.select do |path|
            File.read(path).match?(/^\s*require(_relative)?\b/)
        end
        assert_empty offenders, "only the two entry files may require"
    end

    # require "tessella" is the library alone: no command line class,
    # and no optparse, loaded in a fresh process to be sure.
    def test_the_library_loads_without_the_command_line
        probe = "require 'tessella'; " \
                "print [defined?(Tessella::CLI), defined?(OptionParser), " \
                "defined?(Tessella.table)].inspect"
        out = IO.popen([RbConfig.ruby, "-I", LIB, "-e", probe], &:read)
        assert_equal('[nil, nil, "method"]', out)
    end

    def test_the_soft_dependency_loads_only_rmagick
        loads = File.readlines(SOFT, chomp: true).grep(/^\s*require/)
        assert_equal(["            require GEM"], loads)
        assert_equal("rmagick", Tessella::RMagickReader::GEM)
    end
end
