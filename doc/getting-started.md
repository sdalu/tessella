# Getting started

## Install

tessella is not on rubygems.org. Install it from a checkout:

```sh
cd tessella
make install      # builds the gem, installs it for this user
```

`make uninstall` removes it. Without installing, `exe/tessella` runs
straight out of the checkout, and `ruby -I lib` finds the library.
It needs Ruby 3.4 and nothing else.

## A first chart

Any file of numbers will do. [examples/langs.csv](../examples/langs.csv)
holds a header and three rows:

```text
$ cat langs.csv
lang,loc
ruby,12
c,30
rust,7.5
```

```text
$ tessella chart --kind bar --width 30 langs.csv
        ┌                              ┐
   ruby ┤██████████▍··············· 12
      c ┤██████████████████████████ 30
   rust ┤██████▌··················· 7.5
        └                              ┘
```

The same, for a document kept to ASCII:

```text
$ tessella chart --kind bar --width 30 --ascii langs.csv
        +                              +
   ruby |##########................ 12
      c |########################## 30
   rust |#######................... 7.5
        +                              +
```

## A first diagram

Each diagram reads a small text format from a file or stdin:

<!-- tessella: allow-mixed -->
```text
$ printf 'Client -> Server: GET /\nServer --> Client: 200\n' | tessella seq
┌─────────┐  ┌─────────┐
│ Client  │  │ Server  │
└────┬────┘  └────┬────┘
     │            │
     │   GET /    │
     │───────────▸│
     │            │
     │    200     │
     │◂┄┄┄┄┄┄┄┄┄┄┄│
     │            │
```

## From Ruby

```ruby
require "tessella"

puts Tessella.bar(%w[ruby c rust], [12, 30, 7.5], width: 30)
```

Every factory returns an object that prints as the figure, and every
figure composes with every other: frame it, set it beside another,
stack, indent or caption it.

```ruby
# frozen_string_literal: true

# examples/load.rb: a bar chart and a table side by side, framed and
# captioned -- composition of any two figures.
require "tessella"

rows = Tessella::Table.parse(File.read("langs.csv"))
labels = rows.drop(1).map(&:first)
values = rows.drop(1).map { Integer(it[1], exception: false) || it[1].to_f }
plot = Tessella.bar(labels, values, width: 20)
table = Tessella.table(rows, style: :rounded)
fig = Tessella.beside(plot, table, gap: 2, align: :middle)
puts Tessella.caption(Tessella.frame(fig, title: "Load"),
                      text: "Figure 1: lines of code, in thousands")
```

```text
$ ruby load.rb
┌───────────────────── Load ─────────────────────┐
│                                 ╭──────┬─────╮ │
│         ┌                    ┐  │ lang │ loc │ │
│    ruby ┤██████▍········· 12    ├──────┼─────┤ │
│       c ┤████████████████ 30    │ ruby │  12 │ │
│    rust ┤████············ 7.5   │ c    │  30 │ │
│         └                    ┘  │ rust │ 7.5 │ │
│                                 ╰──────┴─────╯ │
└────────────────────────────────────────────────┘

      Figure 1: lines of code, in thousands
```

## Where next

- [Charts](charts.md): the eight kinds, their input, options and
  canvases.
- [Composition](composition.md): assembling figures.
- [Trees](tree.md), [tables](table.md), [bit fields](bitfield.md),
  [timing diagrams](wave.md), [sequence diagrams](seq.md),
  [pictures](images.md).
- [Linting](lint.md): checking figures before they ship.
- [The command](cli.md) and [the library](library.md), for reference.
