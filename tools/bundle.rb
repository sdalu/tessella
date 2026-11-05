# frozen_string_literal: true

# bundle.rb -- the library as one file, for vendoring (the tessella
# skill carries this output). Concatenates the files lib/tessella.rb
# requires, in its order, with their require lines and per-file magic
# comments dropped; one frozen_string_literal header on top.
#
# Usage: ruby tools/bundle.rb [OUT]          (stdout if no OUT)

root  = File.expand_path("..", __dir__)
entry = File.read(File.join(root, "lib", "tessella.rb"))
parts = entry.scan(%r{^require_relative "(tessella/[^"]+)"$}).flatten
abort "bundle.rb: no require_relative lines in lib/tessella.rb" if
    parts.empty?

version = File.read(File.join(root, "lib/tessella/version.rb"))[/"(.+)"/, 1]
stdlib = entry.scan(/^require "[^"]+"$/)
out = +"# frozen_string_literal: true\n\n"
out << "# tessella #{version}, bundled into one file by tools/bundle.rb.\n"
out << "# Generated: edit the gem (lib/), never this copy. MIT licence.\n"
out << "\n" << stdlib.join("\n") << "\n" unless stdlib.empty?
parts.each do |part|
    body = File.read(File.join(root, "lib", "#{part}.rb"))
    body = body.sub(/\A# frozen_string_literal: true\n+/, "")
    out << "\n# --- lib/#{part}.rb\n\n" << body
end

ARGV[0] ? File.write(ARGV[0], out) : $stdout.write(out)
