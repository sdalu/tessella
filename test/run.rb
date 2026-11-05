# frozen_string_literal: true

# Every test file, so `make tests` is one process and one report.
Dir[File.join(__dir__, "**", "test_*.rb")].each { require it }
