# frozen_string_literal: true

module Tessella
    # A hierarchy, drawn as a box-drawing tree (ported from the
    # ascii-art skill's scripts/tree.rb -- DESIGN.md names it as a
    # drawing module alongside Compose). `outline` is one node per
    # line, depth given by leading-space indentation (the indent unit
    # is inferred from the first indented line); an optional leading
    # "- " or "* " bullet is stripped, and an optional "label  # note"
    # annotation (two or more spaces, then #) is pulled off and
    # aligned into one comment column across the whole tree. Several
    # top-level lines form a forest; root: gathers them under one
    # synthesized root instead.
    #
    # Bad input (a tab, an indent that is not a whole multiple of the
    # inferred unit, a line more than one level deeper than its
    # predecessor, an empty label, no node at all) raises
    # ArgumentError naming the input line, as does an unknown style,
    # a style other than the default under ascii: true, and -- unlike
    # the script, which lints afterwards -- non-ASCII content under
    # ascii: true, refused at draw time rather than caught by a later
    # pass.
    module Tree
        Result = Data.define(:lines, :entries)

        STYLES = {
            light: { sib: "├── ", last: "└── ", pipe: "│   " },
            heavy: { sib: "┣━━ ", last: "┗━━ ", pipe: "┃   " },
            rounded: { sib: "├── ", last: "╰── ", pipe: "│   " },
            ascii: { sib: "|-- ", last: "`-- ", pipe: "|   " }
        }.freeze
        BLANK = "    "

        def self.bad!(lineno, msg)
            raise ArgumentError, "line #{lineno}: #{msg}"
        end

        def self.glyphs(style, ascii)
            name = (style || (ascii ? :ascii : :light)).to_sym
            if ascii && name != :ascii
                raise ArgumentError, "style #{name} conflicts with ascii: true"
            end

            STYLES.fetch(name) do
                raise ArgumentError, "unknown style: #{name.inspect}"
            end
        end

        def self.render(outline, style: nil, ascii: Target.ascii?, root: nil)
            lines = Parser.parse(outline)
            roots = Builder.forest(lines)
            roots = [Builder.wrap(root, roots)] if root
            g = glyphs(style, ascii)
            entries = []
            Renderer.walk(roots, nil, g, entries)
            rendered = Renderer.align(entries)
            check_ascii!(root, rendered, entries) if
                ascii && !Target.text_free?
            Result.new(rendered, entries)
        end

        def self.check_ascii!(root, rendered, entries)
            if root && !root.ascii_only?
                bad!(0, "--root is non-ASCII under ascii: true")
            end
            i = rendered.each_index.find { |idx| !rendered[idx].ascii_only? }
            return unless i

            bad!(entries[i][:line], "is non-ASCII under ascii: true")
        end

        # Mirrors tree.rb's own --max-width check (naming the source
        # node's line, not the rendered line), not Block#check_width!,
        # whose message and line numbering are generic.
        def self.check_max_width!(result, max_width)
            return result unless max_width

            i = result.lines.each_index.find do |idx|
                Width.of(result.lines[idx]) > max_width
            end
            return result unless i

            w = Width.of(result.lines[i])
            bad!(result.entries[i][:line],
                 "is #{w} columns, over --max-width #{max_width}")
        end
    end

    # Lines to nodes: depth from indentation, an optional bullet
    # stripped, an optional "  # note" annotation split off.
    module Tree
        module Parser
            def self.parse(outline)
                lines = outline.split("\n", -1).each_with_index
                               .map { |raw, i| parse_line(raw, i + 1) }
                               .compact
                Tree.bad!(0, "no nodes in the input") if lines.empty?
                lines
            end

            def self.parse_line(raw, lineno)
                return nil if raw.strip.empty?
                if raw.include?("\t")
                    Tree.bad!(lineno, "a tab in the indentation")
                end

                indent = raw[/\A */].size
                rest = raw[indent..].sub(/\A[-*] /, "")
                label, annotation = split_annotation(rest)
                Tree.bad!(lineno, "an empty node label") if label.empty?
                { indent: indent, label: label, annotation: annotation,
                  line: lineno }
            end

            def self.split_annotation(rest)
                label, _, note = rest.partition(/ {2,}#\s?/)
                [label.rstrip, note.empty? ? nil : note.rstrip]
            end
        end
    end

    # Nodes to a forest: a stack of the open ancestors at each depth,
    # one per indent level; root: wraps the forest under one node.
    module Tree
        module Builder
            def self.forest(lines)
                unit = nil
                stack = []
                roots = []
                lines.each do |l|
                    unit ||= l[:indent] if l[:indent].positive?
                    insert(l, unit, stack, roots)
                end
                roots
            end

            def self.insert(line, unit, stack, roots)
                depth = resolve_depth(line[:indent], unit, line[:line])
                node = make_node(line)
                attach(node, depth, stack, roots)
                stack[depth] = node
                stack.slice!((depth + 1)..)
            end

            def self.resolve_depth(indent, unit, lineno)
                return 0 if indent.zero?

                skewed = (indent % unit).nonzero?
                if skewed
                    Tree.bad!(lineno,
                              "indentation is not a multiple of #{unit}")
                end
                indent / unit
            end

            def self.make_node(line)
                { label: line[:label], annotation: line[:annotation],
                  line: line[:line], children: [] }
            end

            def self.attach(node, depth, stack, roots)
                prev = stack.size - 1
                Tree.bad!(node[:line], "skips a level") if depth > prev + 1
                return roots << node if depth.zero?

                stack[depth - 1][:children] << node
            end

            def self.wrap(name, roots)
                { label: name, annotation: nil, line: 0, children: roots }
            end
        end
    end

    # A forest to text: one line per node, its connector built from
    # whether it is the last child at each ancestor level; notes
    # aligned into one comment column across the whole render.
    module Tree
        module Renderer
            def self.connector(prefix, last, g)
                return "" if prefix.nil?

                prefix + (last ? g[:last] : g[:sib])
            end

            def self.continuation(prefix, last, g)
                return "" if prefix.nil?

                prefix + (last ? Tree::BLANK : g[:pipe])
            end

            def self.walk(nodes, prefix, g, out)
                nodes.each_with_index do |node, i|
                    last = i == nodes.size - 1
                    head = connector(prefix, last, g)
                    out << { text: head + node[:label],
                             annotation: node[:annotation],
                             line: node[:line] }
                    kids = node[:children]
                    next if kids.empty?

                    walk(kids, continuation(prefix, last, g), g, out)
                end
            end

            def self.align(entries)
                column = entries.map { Width.of(it[:text]) }.max + 2
                entries.map do |e|
                    next e[:text] if e[:annotation].nil?

                    "#{Width.ljust(e[:text], column)}# #{e[:annotation]}"
                end
            end
        end
    end

    def self.tree(outline, style: nil, ascii: Target.ascii?, root: nil)
        result = Tree.render(outline, style: style, ascii: ascii, root: root)
        Block.new(result.lines)
    end
end
