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
tessella compose: --style light needs --no-ascii under target cjk
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

A figure read in a browser (a README on GitHub, a page of docs) is at
risk where it draws an arrow head. The arrow glyphs fall in three
groups:

| Glyphs             | On the web                                            |
|--------------------|-------------------------------------------------------|
| `▸ ◂ ▴ ▾`          | text glyphs most monospace fonts carry: they line up  |
| `→ ← ↑ ↓`          | text glyphs most monospace fonts carry: they line up  |
| `► ◄`              | not emoji-capable, bolder; some fonts lack them       |
| `▶ ◀ ↔ ↕ ↗ ↘ ↙ ↖`  | emoji-capable: may become a wide colour emoji         |

So on the web, end a drawn line with a small head, `────▸`, or a
bolder `────►`, and keep `→ ← ↑ ↓` for arrows standing alone. `► ◄`
never turn into emoji, but a font without them still draws them at a
fallback width: they trade a little of `▸`'s safety for a head that
reads at a glance.

tessella's sequence diagrams use the bolder heads in every target,
terminal included: `►` and `◄` for calls and replies, `►►` and `◄◄`
for asynchronous messages ([sequence diagrams](seq.md#arrow-heads)).

When a figure does carry an emoji-capable glyph, `--target web` puts
U+FE0E, the text-presentation selector, right after it. The selector
is invisible; here it is made visible as `[FE0E]`:

```text
$ tessella --target web rule --width 24 --ornament '▶ next' | \
    ruby -pe 'gsub("\u{FE0E}", "[FE0E]")'
──────── ▶[FE0E] next ────────
```

It stops the browser drawing the glyph as an emoji, and is the one
exception to tessella's rule of no invisible characters in its
output. It does not fix the glyph's width: a glyph the page's
monospace font lacks is drawn from a fallback font, at that font's
width. In Chrome on GitHub's code fonts `▶` takes two columns and
`↗` 1.4, with or without the selector. On a row that must line up,
the selector is not enough; `▸` is the arrow head that lines up.

`tessella lint --target web` (the same as `--web`) checks a figure
for this. It flags a bare emoji-capable glyph, and accepts one
followed by U+FE0E:

```text
$ printf 'A ──▶ B\n' | tessella lint --target web
stdin:1: emoji-capable U+25B6 ▶ (web target)
```

```text
$ printf 'A ──▸ B\n' | tessella lint --target web && echo clean
clean
```

To add the selector to a figure edited by hand, use a tool rather
than typing an invisible character:

```sh
ruby -pi -e 'gsub(/([▶◀])(?!\u{FE0E})/, "\\1\u{FE0E}")' FIGURE.md
```

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
