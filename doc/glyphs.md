# Glyph sets and width classes

A figure lines up only if every glyph in it takes the columns the
author counted. Most do, everywhere. Some do in a Western terminal
and take two columns in one set up for Chinese, Japanese or Korean:
the box-drawing lines and the shade blocks among them. tessella names
the glyph sets it draws with, and says for each which of these
classes its glyphs fall in.

```ruby
Tessella::Width.class_of("▒")                  # => :A
Tessella::Glyphs.fetch(:ramp, :blocks)         # => a GlyphSet
Tessella::Glyphs.fetch(:ramp, :blocks).mixed?  # => true
```

```text
tessella glyphs [KIND [NAME]]
tessella glyphs --check GLYPHS
```

## Width classes

Every character has one class, from Unicode 15.1's East Asian Width
property:

| Class | Name      | Columns                                          |
|-------|-----------|--------------------------------------------------|
| `N`   | narrow    | one, everywhere                                  |
| `A`   | ambiguous | one in Western terminals, two in CJK-configured ones |
| `W`   | wide      | two, everywhere (CJK ideographs, most emoji)     |

`Tessella::Width.class_of(char)` returns `:N`, `:A` or `:W`. A set
whose glyphs all share one class keeps its shape in any terminal; a
set that spans two is *mixed*: right in a Western terminal, but its
glyphs change width against each other in a CJK one, so a figure
drawn with it stops lining up there.

## The registry

`tessella glyphs` lists every named set the library draws with: its
kind, its name, its classes, and its glyphs. A kind narrows it to one
kind:

<!-- tessella: allow-mixed -->
```text
$ tessella glyphs border
border   light              A    ┌┐└┘─│
border   heavy              A    ┏┓┗┛━┃
border   double             A    ╔╗╚╝═║
border   rounded            A    ╭╮╰╯─│
border   dashed             A    ┌┐└┘┄┆
border   dashed_fine        A    ┌┐└┘┈┊
border   heavy_dashed       A    ┏┓┗┛┅┇
border   heavy_dashed_fine  A    ┏┓┗┛┉┋
border   double_h           A    ╒╕╘╛═│
border   double_v           A    ╓╖╙╜─║
border   ascii              N    ++++-|
```

A kind and a name list one set glyph by glyph, with code points:

```text
$ tessella glyphs ramp blocks
░  U+2591  N
▒  U+2592  A
▓  U+2593  A
█  U+2588  A
```

The `blocks` ramp is mixed: `░` is narrow, the three others are
ambiguous. In a CJK terminal its lightest tone is half as wide as the
others.

From Ruby, `Tessella::Glyphs.fetch(kind, name)` returns a `GlyphSet`
(`kind`, `name`, `glyphs`, `note`, `classes`, `mixed?`), and
`Tessella::Glyphs.all` every set. An unknown kind or name raises
`ArgumentError`, listing the names there are. A name may say `-` for
`_`.

## Checking a set of one's own

`--check GLYPHS` classifies any glyphs: it prints their class, and
exits 1 when they are mixed, so a build can refuse a glyph set before
a figure uses it:

```text
$ tessella glyphs --check '┌┐└┘─│'
A
```

```text
$ tessella glyphs --check '░▒▓█'
mixed: N A
```

The [lint](lint.md) measures widths with the same tables, so what
`glyphs` calls narrow, the lint counts as one column.
