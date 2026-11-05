# frozen_string_literal: true

# bundle.rb -- the library and its command line as one file, for
# vendoring where the gem cannot be installed. Concatenates the
# files lib/tessella.rb requires, in its order, then the ones
# lib/tessella/cli.rb requires, in its order, with their require lines
# and per-file magic comments dropped; the standard library requires
# of both on top, under one frozen_string_literal header.
#
# Usage: ruby tools/bundle.rb [OUT]          (stdout if no OUT)

root = File.expand_path("..", __dir__)
lib = File.join(root, "lib")

# Each entry: its file, the pattern of its require_relative lines, and
# the prefix that makes those paths relative to lib/.
entries = [
    ["tessella.rb", %r{^require_relative "(tessella/[^"]+)"$}, ""],
    ["tessella/cli.rb", %r{^require_relative "(cli/[^"]+)"$}, "tessella/"]
].map do |file, pattern, prefix|
    text = File.read(File.join(lib, file))
    parts = text.scan(pattern).flatten.map { "#{prefix}#{it}" }
    abort "bundle.rb: no require_relative lines in lib/#{file}" if parts.empty?
    [text, parts]
end

version = File.read(File.join(lib, "tessella/version.rb"))[/"(.+)"/, 1]
stdlib = entries.flat_map { |text, _| text.scan(/^require "[^"]+"$/) }.uniq
out = +"# frozen_string_literal: true\n\n"
out << "# tessella #{version}, bundled into one file by tools/bundle.rb.\n"
out << "# Generated: edit the gem (lib/), never this copy. MIT licence.\n"
out << "\n" << stdlib.join("\n") << "\n" unless stdlib.empty?
entries.flat_map(&:last).each do |part|
    body = File.read(File.join(lib, "#{part}.rb"))
    body = body.sub(/\A# frozen_string_literal: true\n+/, "")
    out << "\n# --- lib/#{part}.rb\n\n" << body
end

ARGV[0] ? File.write(ARGV[0], out) : $stdout.write(out)
