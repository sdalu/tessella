# Trees

`tree` draws an indented outline as a box-drawing tree: a directory
layout, a class hierarchy, a table of contents.

```ruby
Tessella.tree(outline, style: nil, ascii: false, root: nil)  # => Block
```

```text
tessella tree [--style S] [--ascii] [--root NAME] [--max-width N] [file]
```

## The outline

One node per line; depth is the leading spaces. The indent unit is
whatever the first indented line uses, and every indent must be a
whole multiple of it.

```text
$ cat outline.txt
tessella
  lib            # the library
    tessella.rb  # the entry
    tessella
      cli
  exe
    tessella     # the command
  test
```

- A leading `- ` or `* ` bullet is dropped, so a Markdown list reads
  as is.
- Two or more spaces then `#` start a note. Notes are lined up in one
  column across the whole tree.
- A line may go at most one level deeper than the line above it.

```text
$ tessella tree outline.txt
tessella
├── lib              # the library
│   ├── tessella.rb  # the entry
│   └── tessella
│       └── cli
├── exe
│   └── tessella     # the command
└── test
```

## Styles

`--style light` (the default), `heavy` or `rounded`; `--ascii` draws
`|--` and `` `-- `` instead, and allows no other style.

```text
$ tessella tree --style rounded outline.txt
tessella
├── lib              # the library
│   ├── tessella.rb  # the entry
│   ╰── tessella
│       ╰── cli
├── exe
│   ╰── tessella     # the command
╰── test
```

```text
$ tessella tree --ascii outline.txt
tessella
|-- lib              # the library
|   |-- tessella.rb  # the entry
|   `-- tessella
|       `-- cli
|-- exe
|   `-- tessella     # the command
`-- test
```

## Forests and roots

Several lines at the top level are a forest: each is drawn as a root
of its own. `--root NAME` (`root: "NAME"`) gathers them under one
root instead:

<!-- tessella: allow-mixed -->
```text
$ printf -- '- lib\n- exe\n- test\n' | tessella tree --root tessella
tessella
├── lib
├── exe
└── test
```

## Errors

Bad input raises `ArgumentError` naming the line (exit 1 on the
command line): a tab, an indent that is not a whole multiple of the
unit, a line two levels deeper than the one before it, an empty
label, no node at all, and a non-ASCII label under `--ascii`.

```text
$ printf 'a\n   b\n  c\n' | tessella tree
tessella tree: line 3: indentation is not a multiple of 3
```

An unknown style, or a style other than the default with `--ascii`,
is a usage error (exit 2). `--max-width N` refuses (exit 1) a tree
wider than N columns, naming the node that overflows.
