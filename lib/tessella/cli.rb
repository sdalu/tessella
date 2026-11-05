# frozen_string_literal: true

# The tessella command line, on top of the library: `require
# "tessella/cli"` for Tessella::CLI and the per-command classes
# (ChartCLI, ComposeCLI, ...); `require "tessella"` alone loads none
# of them, nor optparse. As lib/tessella.rb does for the library,
# this file is the only place the command line's files are required,
# in this order, and tools/bundle.rb follows it after the library's.

require "optparse"

require_relative "../tessella"

require_relative "cli/chart"
require_relative "cli/compose"
require_relative "cli/compose_options"
require_relative "cli/tree"
require_relative "cli/table"
require_relative "cli/bitfield"
require_relative "cli/wave"
require_relative "cli/seq"
require_relative "cli/image"
require_relative "cli/lint"
require_relative "cli/lint_options"
require_relative "cli/main"
