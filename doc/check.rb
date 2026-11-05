#!/usr/bin/env ruby
# frozen_string_literal: true

# Keeps the documents in doc/ true to the code and to examples/.
#
# Two kinds of fence are checked, in every doc/*.md:
#
# - A render: a ```text fence that opens with "$ COMMAND". COMMAND
#   may run over several lines, each but its last ending in a
#   backslash, as sh reads it. The rest of the fence is what COMMAND
#   prints, stdout and stderr merged. COMMAND runs under sh, in
#   examples/, with this checkout's exe/ first on PATH and its lib/
#   on RUBYLIB, so `tessella` and `require "tessella"` are the ones
#   beside these documents.
# - A listing: a ```ruby or ```sh fence holding a line
#   "# examples/NAME" in its first three. Its body is the file
#   examples/NAME, whole.
#
#   ruby doc/check.rb            report each fence that differs
#   ruby doc/check.rb --update   rewrite the fences from what runs now
#
# Exit 0 when every fence agrees (or after --update), 1 otherwise.

require "open3"

ROOT = File.expand_path("..", __dir__)
EXAMPLES = File.join(ROOT, "examples")
RUN_ENV = {
    "PATH" => "#{File.join(ROOT, "exe")}:#{ENV.fetch("PATH")}",
    "RUBYLIB" => File.join(ROOT, "lib")
}.freeze
RENDER = /^```text\n\$ (?<key>(?:[^\n]*\\\n)*[^\n]*)\n(?<body>.*?)^```$/m
LISTING = %r{
    ^```(?<lang>ruby|sh)\n
    (?<body>(?:(?!```)[^\n]*\n){0,2}?\#\ examples/(?<key>[\w.-]+)[^\n]*\n.*?)
    ^```$
}mx

def render(cmd)
    Open3.capture2e(RUN_ENV, "sh", "-c", cmd, chdir: EXAMPLES).first
end

def listing(name) = File.read(File.join(EXAMPLES, name))

def fence(kind, match, body)
    return "```text\n$ #{match[:key]}\n#{body}```" if kind == :render

    "```#{match[:lang]}\n#{body}```"
end

# The text with every fence rewritten from what it should hold; each
# fence that differs is noted in stale.
def refresh(text, doc, stale)
    [[RENDER, :render], [LISTING, :listing]].reduce(text) do |out, (re, kind)|
        out.gsub(re) do
            m = Regexp.last_match
            got = send(kind, m[:key])
            stale << "#{doc}: #{m[:key]}" unless got == m[:body]
            fence(kind, m, got)
        end
    end
end

update = ARGV.delete("--update")
stale = []
Dir[File.join(__dir__, "*.md")].each do |path|
    text = File.read(path)
    out = refresh(text, File.basename(path), stale)
    File.write(path, out) if update && out != text
end
exit 0 if update || stale.empty?

warn "out of date:"
stale.each { warn "  #{it}" }
exit 1
