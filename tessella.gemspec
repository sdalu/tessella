# frozen_string_literal: true

require_relative "lib/tessella/version"

Gem::Specification.new do |s|
    s.name = "tessella"
    s.version = Tessella::VERSION
    s.summary = "Text figures for a monospace grid, in Unicode or pure ASCII"
    s.description = "Charts (line, scatter, bar, histogram, box, stem, " \
                    "density) on braille, block or ASCII canvases, trees, " \
                    "tables, bit-field, timing and sequence diagrams, " \
                    "meters and sparklines, composed side by side or " \
                    "framed, and a lint for text figures in documents. " \
                    "No runtime dependency."
    s.authors = ["Stephane D'Alu"]
    s.license = "MIT"
    s.homepage = "https://github.com/sdalu/tessella"
    s.required_ruby_version = ">= 3.4"
    # doc/ and examples/ ship too: doc/library.md is the API reference
    # a caller (or a skill driving the library) is pointed at.
    s.files = Dir["lib/**/*.rb", "exe/*", "LICENSE", "README.md",
                  "doc/**/*", "examples/**/*"]
    s.bindir = "exe"
    s.executables = ["tessella"]
    s.metadata["rubygems_mfa_required"] = "true"
    s.metadata["source_code_uri"] = s.homepage
    s.metadata["documentation_uri"] = "#{s.homepage}/blob/main/doc/README.md"
    s.metadata["changelog_uri"] = "#{s.homepage}/releases"
    s.metadata["bug_tracker_uri"] = "#{s.homepage}/issues"
end
