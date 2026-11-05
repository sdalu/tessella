# frozen_string_literal: true

# examples/comment.rb: a tree, in ASCII, as a comment block for a
# source file kept to ASCII.
require "tessella"

outline = File.read("outline.txt")
puts Tessella.indent(Tessella.tree(outline, ascii: true),
                     prefix: "# ", ascii: true)
