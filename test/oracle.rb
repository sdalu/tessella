# frozen_string_literal: true

# The oracle: unicode_plot, loaded only for tests that compare against
# it. Never installed by this project; point INKCHART_ORACLE (or the
# Makefile's ORACLE) at a GEM_PATH holding it. Without it, oracle tests
# skip, and the run says how many did.
require "stringio"

module Oracle
    def self.load
        path = ENV.fetch("INKCHART_ORACLE", "")
        Gem.paths = { "GEM_PATH" => path } unless path.empty?
        require "unicode_plot"
        true
    rescue LoadError
        false
    end

    AVAILABLE = load

    def self.available? = AVAILABLE

    # unicode_plot's rendering as plain text, colour off.
    def self.render(plot)
        out = StringIO.new
        plot.render(out, color: false)
        out.string
    end

    # In a test: skip unless the oracle is loaded.
    module Test
        def need_oracle
            skip "unicode_plot not available (set ORACLE=)" unless
                Oracle.available?
        end
    end
end
