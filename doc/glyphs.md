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
kind, its name, its classes, the [width targets](targets.md) it is
safe for, and its glyphs. Every set suits `term`; a set suits `cjk`
when it holds no ambiguous glyph, and `web` when it holds no wide or
emoji-capable one. A kind narrows the list to one kind:

<!-- tessella: allow-mixed -->
```text
$ tessella glyphs border
border   light              A    term web      ┌┐└┘─│
border   heavy              A    term web      ┏┓┗┛━┃
border   double             A    term web      ╔╗╚╝═║
border   rounded            A    term web      ╭╮╰╯─│
border   dashed             A    term web      ┌┐└┘┄┆
border   dashed_fine        A    term web      ┌┐└┘┈┊
border   heavy_dashed       A    term web      ┏┓┗┛┅┇
border   heavy_dashed_fine  A    term web      ┏┓┗┛┉┋
border   double_h           A    term web      ╒╕╘╛═│
border   double_v           A    term web      ╓╖╙╜─║
border   ascii              N    term cjk web  ++++-|
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
(`kind`, `name`, `glyphs`, `note`, `classes`, `mixed?`, `targets`),
`Tessella::Glyphs.targets(glyphs)` the targets any glyphs suit, and
`Tessella::Glyphs.all` every set. An unknown kind or name raises
`ArgumentError`, listing the names there are. A name may say `-` for
`_`.

`--target T` lists only the sets safe for a target, here the meter
styles a CJK terminal draws as counted:

```text
$ tessella glyphs --target cjk meter
meter    arrow              N    term cjk web  ▸▹
meter    chevron            N    term cjk web  ›
meter    classic            N    term cjk web  =
meter    rectangle          N    term cjk web  ▮▯
meter    wave               N    term cjk web  ~_
meter    blade              N    term cjk web  ▰▱  (patchy font coverage)
meter    button             N    term cjk web  ⦿⦾  (patchy font coverage)
```

### Arrow heads

The registry also holds the arrow heads, as kind `head`, with the rule
for choosing one in their targets and notes:

```text
$ tessella glyphs head
head     full               N+A  term web      ►◄▲▼  mixed  (▴ ▾ for ▲ ▼ under cjk)
head     small              N    term cjk web  ▸◂▴▾
head     emoji              A    term          ▶◀  (U+FE0E after it on the web)
```

`full` (`►◄▲▼`) is mixed: `► ◄` are narrow, `▲ ▼` ambiguous, so in a
CJK terminal use `▴ ▾` for up and down; `tessella lint --target cjk`
says so when it finds `▲` or `▼` on a row that must line up. `small`
(`▸◂▴▾`) suits every target. `emoji` (`▶◀`) suits the terminal only,
and needs U+FE0E after it on the web ([width targets](targets.md#web)).

## Checking a set of one's own

`--check GLYPHS` classifies any glyphs: it prints their class and the
targets they are safe for, and exits 1 when they are mixed, so a
build can refuse a glyph set before a figure uses it:

```text
$ tessella glyphs --check '┌┐└┘─│'
A
safe for: term web
```

```text
$ tessella glyphs --check '░▒▓█'
mixed: N A
safe for: term web
```

The [lint](lint.md) measures widths with the same tables, so what
`glyphs` calls narrow, the lint counts as one column.
