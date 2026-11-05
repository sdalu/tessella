# frozen_string_literal: true

require_relative "test_helper"

# The scaffold's own promises: the library loads in its declared order,
# and the gemspec ships no runtime dependency (D1).
class TestScaffold < Minitest::Test
    def test_loads
        assert_match(/\A\d+\.\d+\.\d+\z/, Inkchart::VERSION)
    end

    def test_no_runtime_dependency
        path = File.expand_path("../inkchart.gemspec", __dir__)
        spec = Gem::Specification.load(path)
        assert_empty spec.runtime_dependencies
    end

    def test_only_the_entry_requires_inkchart_files
        lib = File.expand_path("../lib", __dir__)
        offenders = Dir["#{lib}/inkchart/**/*.rb"].select do |path|
            File.read(path).match?(/^\s*require(_relative)?\b/)
        end
        assert_empty offenders, "only lib/inkchart.rb may require"
    end
end
