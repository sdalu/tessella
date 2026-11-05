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
terminal will. There, the row lines up. An explicit `--ascii` or
`ascii: false` is still honoured; Unicode structure under `cjk` will
not line up where it is read.

## web

A browser may draw an emoji-capable glyph (`▶ ☀ ✔`) as a wide colour
emoji. Under `web` the output carries U+FE0E, the text-presentation
selector, after each such glyph, so it stays a one-column glyph. It
is invisible, and the one exception to tessella's rule of no
invisible characters in its output.

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
