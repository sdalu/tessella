# frozen_string_literal: true

require_relative "lib/ascii_art/version"

Gem::Specification.new do |s|
    s.name = "ascii-art"
    s.version = AsciiArt::VERSION
    s.summary = "Charts for a monospace grid, in Unicode or pure ASCII"
    s.description = "Line, scatter, stairs, bar, histogram, box, stem " \
                    "and density plots with scaled axes, drawn in braille, " \
                    "block, dot or ASCII cells. No runtime dependency."
    s.authors = ["Stephane D'Alu"]
    s.license = "MIT"
    s.required_ruby_version = ">= 3.4"
    s.files = Dir["lib/**/*.rb", "exe/*", "LICENSE", "README.md"]
    s.bindir = "exe"
    s.executables = ["ascii-art"]
    s.metadata["rubygems_mfa_required"] = "true"
end
