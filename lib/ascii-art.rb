# frozen_string_literal: true

# ascii-art -- charts and text figures for a monospace grid, in Unicode
# or pure ASCII.
#
# The load order below is the dependency order, and the only place an
# ascii-art file is required: tools/bundle.rb concatenates the files in
# exactly this order into one, for vendoring (DESIGN.md). Standard
# library requires live here too, above the parts, and nowhere else.

require "optparse"

require_relative "ascii_art/version"
require_relative "ascii_art/error"
require_relative "ascii_art/check"
require_relative "ascii_art/width"
require_relative "ascii_art/cell"
require_relative "ascii_art/stats"
require_relative "ascii_art/axis"
require_relative "ascii_art/color"
require_relative "ascii_art/canvas"
require_relative "ascii_art/canvas/braille"
require_relative "ascii_art/canvas/block"
require_relative "ascii_art/canvas/dot"
require_relative "ascii_art/canvas/ascii"
require_relative "ascii_art/canvas/density"
require_relative "ascii_art/frame"
require_relative "ascii_art/chart"
require_relative "ascii_art/kinds/line"
require_relative "ascii_art/kinds/bar"
require_relative "ascii_art/kinds/box"
require_relative "ascii_art/kinds/stem"
require_relative "ascii_art/chart_cli"
require_relative "ascii_art/cli"
