# frozen_string_literal: true

# tessella -- charts and text figures for a monospace grid, in Unicode
# or pure ASCII.
#
# The load order below is the dependency order, and the only place an
# tessella file is required: tools/bundle.rb concatenates the files in
# exactly this order into one, for vendoring (DESIGN.md). Standard
# library requires live here too, above the parts, and nowhere else.

require "optparse"

require_relative "tessella/version"
require_relative "tessella/error"
require_relative "tessella/check"
require_relative "tessella/width"
require_relative "tessella/borders"
require_relative "tessella/block"
require_relative "tessella/compose"
require_relative "tessella/tree"
require_relative "tessella/table"
require_relative "tessella/table_cells"
require_relative "tessella/bitfield"
require_relative "tessella/wave"
require_relative "tessella/seq"
require_relative "tessella/cell"
require_relative "tessella/stats"
require_relative "tessella/axis"
require_relative "tessella/color"
require_relative "tessella/canvas"
require_relative "tessella/canvas/braille"
require_relative "tessella/canvas/block"
require_relative "tessella/canvas/dot"
require_relative "tessella/canvas/ascii"
require_relative "tessella/canvas/density"
require_relative "tessella/frame"
require_relative "tessella/chart"
require_relative "tessella/kinds/line"
require_relative "tessella/kinds/bar"
require_relative "tessella/kinds/box"
require_relative "tessella/kinds/stem"
require_relative "tessella/chart_cli"
require_relative "tessella/compose_cli"
require_relative "tessella/compose_options"
require_relative "tessella/tree_cli"
require_relative "tessella/table_cli"
require_relative "tessella/bitfield_cli"
require_relative "tessella/wave_cli"
require_relative "tessella/seq_cli"
require_relative "tessella/cli"
