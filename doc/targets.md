# Width targets

A figure lines up only if every glyph takes the columns tessella
counted, and that depends on where the figure is read. tessella can
draw for three targets:

| Target | Where                        | Widths                                                    |
|--------|------------------------------|-----------------------------------------------------------|
| `term` | a Western terminal (default) | ambiguous glyphs 1 column, wide ones (CJK, emoji) 2       |
| `cjk`  | a CJK-configured terminal    | ambiguous glyphs 2 columns: box drawing, blocks, `·`, `é` |
| `web`  | a browser                    | as `term`, but some glyphs may turn into wide emoji        |

([Width classes](glyphs.md#width-classes) explains ambiguous and
wide.)

```text
tessella --target term|cjk|web COMMAND ...
TESSELLA_TARGET=cjk tessella COMMAND ...
```

```ruby
Tessella.target = :cjk                         # for the rest of the fiber
Tessella::Target.with(:web) { Tessella.table(rows).to_s }
```

An unknown target is a usage error:

```text
$ tessella --target vt100 table langs.csv
tessella: unknown target: "vt100" (term, cjk, web)
```

## term

The default. `cities.csv` holds a CJK label, which takes two columns
everywhere, and an accented one:

```text
$ tessella table cities.csv
┌────────┬─────┐
│ city   │ pop │
├────────┼─────┤
│ 東京   │  14 │
│ Paris  │   2 │
│ Zürich │ 0.4 │
└────────┴─────┘
```

An emoji sequence, joined by ZWJ (👨‍👩‍👧) or skin-toned (👍🏽), is
one glyph two columns wide in every target, as terminals draw it.

## cjk

In a CJK-configured terminal box drawing is two columns wide, so a
Unicode frame cannot line up there. Under `cjk` every module's
`ascii:` defaults to true: the structure is drawn in ASCII, while the
text stays as given and is measured with ambiguous glyphs as two
columns.

```text
$ tessella --target cjk table cities.csv
+---------+-----+
| city    | pop |
+---------+-----+
| 東京    |  14 |
| Paris   |   2 |
| Zürich | 0.4 |
+---------+-----+
```

Read here, in a Western font, the `Zürich` row looks one column
short: `ü` is ambiguous, and the table gave it the two columns a CJK
terminal will. There, the row lines up.

`ascii: false` still asks for Unicode structure. A frame and a table
then round every inner width up to a whole number of border glyphs
and count their border runs in columns, so each line has one width in
a CJK terminal and the box closes there. Read in a Western terminal,
as on this page, the box looks a column too wide here and there.
Other figures (trees, waves, charts) drawn in Unicode under `cjk` do
not line up in a CJK terminal: leave them to the ASCII default.

On the command line, `--no-ascii` asks for Unicode under `cjk`;
without it, a Unicode `--style` is refused rather than quietly drawn
in ASCII:

```text
$ tessella --target cjk table --no-ascii --style light cities.csv
┌─────┬───┐
│ city     │  pop │
├─────┼───┤
│ 東京     │   14 │
│ Paris    │    2 │
│ Zürich  │  0.4 │
└─────┴───┘
```

```text
$ tessella --target cjk compose frame --style light note.txt 2>&1 | head -1
tessella compose: --style light conflicts with the cjk target's ASCII default (--no-ascii for Unicode)
```

From Ruby, `ascii: false`:

```ruby
# frozen_string_literal: true

# examples/cjk.rb: a table and a frame asked for in Unicode under the
# cjk target. Their inner widths are rounded up to whole border
# glyphs, so they close in a CJK terminal; read in a Western one, as
# here, the boxes look a column wide here and there.
require "tessella"

Tessella::Target.with(:cjk) do
    rows = Tessella::Table.parse(File.read("cities.csv"))
    puts Tessella.table(rows, ascii: false)
    puts Tessella.frame(File.read("note.txt"), ascii: false)
end
```

```text
$ ruby cjk.rb
┌─────┬───┐
│ city     │  pop │
├─────┼───┤
│ 東京     │   14 │
│ Paris    │    2 │
│ Zürich  │  0.4 │
└─────┴───┘
┌─────────┐
│ ruby is 12 kLOC  │
│ c is the bulk    │
└─────────┘
```

## web

A browser may draw an emoji-capable glyph (`▶ ☀ ✔`) as a wide colour
emoji. Under `web` the output carries U+FE0E, the text-presentation
selector, after each such glyph, so it is drawn as a text glyph, not
an emoji. It is invisible, and the one exception to tessella's rule
of no invisible characters in its output.

The selector fixes a glyph's form, not its width. A glyph the page's
monospace font does not carry is drawn from a fallback font, at that
font's width: in Chrome on GitHub's code fonts `▶` takes two columns
and `↗` 1.4, with or without U+FE0E. On the web, then, only glyphs
the monospace font carries line up: prefer `▸` to `▶`.

## Checking for a target

`tessella lint --target T` measures a figure with the target's widths
([lint](lint.md#the-target)): under `cjk` it names an ambiguous glyph
on a row that must line up.

```text
$ tessella table cities.csv | tessella lint --target cjk
stdin:6: ambiguous U+00FC ü on aligned row (cjk target: 2 columns)
```

`tessella glyphs --target T` lists the glyph sets safe for a target,
and `--check` says which targets a set of one's own suits
([glyph sets](glyphs.md)).
