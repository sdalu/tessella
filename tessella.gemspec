# frozen_string_literal: true

require_relative "lib/tessella/version"

Gem::Specification.new do |s|
    s.name = "tessella"
    s.version = Tessella::VERSION
    s.summary = "Charts for a monospace grid, in Unicode or pure ASCII"
    s.description = "Line, scatter, stairs, bar, histogram, box, stem " \
                    "and density plots with scaled axes, drawn in braille, " \
                    "block, dot or ASCII cells. No runtime dependency."
    s.authors = ["Stephane D'Alu"]
    s.license = "MIT"
    s.required_ruby_version = ">= 3.4"
    # doc/ and examples/ ship too: doc/library.md is the API reference
    # a caller (or a skill driving the library) is pointed at.
    s.files = Dir["lib/**/*.rb", "exe/*", "LICENSE", "README.md",
                  "doc/**/*", "examples/**/*"]
    s.bindir = "exe"
    s.executables = ["tessella"]
    s.metadata["rubygems_mfa_required"] = "true"
end
