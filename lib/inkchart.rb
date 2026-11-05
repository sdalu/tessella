# frozen_string_literal: true

# inkchart -- charts for a monospace grid, in Unicode or pure ASCII.
#
# The load order below is the dependency order, and the only place an
# inkchart file is required: tools/bundle.rb concatenates the files in
# exactly this order into one, for vendoring (DESIGN.md). Standard
# library requires live here too, above the parts, and nowhere else.

require "optparse"

require_relative "inkchart/version"
require_relative "inkchart/error"
require_relative "inkchart/check"
require_relative "inkchart/width"
require_relative "inkchart/cell"
require_relative "inkchart/stats"
require_relative "inkchart/axis"
require_relative "inkchart/color"
require_relative "inkchart/canvas"
require_relative "inkchart/canvas/braille"
require_relative "inkchart/canvas/block"
require_relative "inkchart/canvas/dot"
require_relative "inkchart/canvas/ascii"
require_relative "inkchart/canvas/density"
require_relative "inkchart/frame"
require_relative "inkchart/chart"
require_relative "inkchart/kinds/line"
require_relative "inkchart/kinds/bar"
require_relative "inkchart/kinds/box"
require_relative "inkchart/kinds/stem"
require_relative "inkchart/cli"
