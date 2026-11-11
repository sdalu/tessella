# Linting

A text figure that looks right in one editor can break on someone
else's screen: a tab that expands differently, a trailing blank a
formatter strips, a glyph that one font draws two cells wide, a box
side one column off. `lint` checks a figure for these before it ships,
whether tessella drew it or a person did.

```ruby
report = Tessella.lint(source, width: 78, prefix: "", suffix: "",
                       web: false, forbid: [], no_wide: false, ascii: false,
                       allow_mixed: false, fences: false,
                       geometry: false, borders: [])
report.findings   # => Array of Finding (line, message)
report.clean?     # => true when there is none
report.rulers     # => Array of Ruler (line, width, verticals)
Tessella.alphabet(source)  # => "ascii", or "utf-8 <classes>"
```

```text
tessella lint [--width N] [--prefix STR] [--suffix STR] [--ruler]
              [--forbid SEQ]...
              [--web] [--no-wide] [--ascii] [--allow-mixed]
              [--fences] [--geometry] [--border GLYPHS]...
              [--target T] [file ...]
tessella lint --alphabet [file ...]
```

`source` is a String or an IO. The command reads its files, or stdin
when none is given.

## Output and exit status

Each finding goes to stderr as `FILE:LINE: message` (`stdin` for
stdin), one per line. The exit status is 0 when every input is clean,
1 on any finding or a file that cannot be read (the other files are
still linted), and 2 on a usage mistake. A clean file prints nothing:

```text
$ tessella lint plot.txt && echo clean
clean
```

`broken.txt` is a four-line figure with a tab on its first line, a
trailing blank on its second, and a box whose right side wanders:

```text
$ tessella lint broken.txt
broken.txt:1: tab character
broken.txt:2: trailing whitespace
```

## What is always checked

- **Characters that have no fixed width:** tabs, invisible glyphs
  (any character a terminal gives no column, such as a zero-width
  space), invalid UTF-8.
- **Look-alike spaces:** a no-break, thin, ideographic or other space
  that is not U+0020, drawn as a blank and told from a space by no
  display.
- **Trailing blanks**, which an editor or a formatter may strip,
  changing the figure behind the author's back.
- **The column budget:** a line wider than `--width` (78 by default)
  once `--prefix` is drawn before it and `--suffix` after it. The
  prefix is what the figure will sit behind: `// `, `# `, ` * `, four
  spaces of Markdown code; the suffix is what closes a comment wrapped
  around each row, ` -->` or ` */`.

```text
$ tessella lint --width 16 --prefix '// ' note.txt
note.txt:1: 18 columns rendered (budget 16)
```

- **ASCII and Unicode structure mixed in one figure**, such as `+--`
  corners on a `│` side, which the reader's font rarely lines up.
  `--allow-mixed` turns this off; a line reading `tessella:
  allow-mixed` (or `artlint: allow-mixed`), in any comment syntax,
  exempts the figure after it.
- **Drift:** a vertical one column off its anchor on a few rows.
- **Shadows:** a `░` drop shadow missing from a row or misplaced.

## Geometry

`--geometry` (`geometry: true`) reads the boxes and connectors as
structure: a box's sides must stay in their columns down to its
bottom edge, and a vertical or an arrow head must hang from something
above it, not from blank space. It knows every box-drawing set (light,
heavy, double, rounded, dashed, mixed junctions) and ASCII `+-|`
boxes:

```text
$ tessella lint --geometry broken.txt
broken.txt:1: tab character
broken.txt:2: trailing whitespace
broken.txt:3: side of box opened at line 2 col 1 is off at col 4
broken.txt:3: connector '│' at col 5 hangs from ' '
```

It is off by default because it reads every `│` and `+` as structure,
so a Markdown table or a `|` in prose would be flagged.

A box drawn in a custom border set is not structure to the lint until
it is declared: `--border GLYPHS` (`borders:`) takes six glyphs in the
order `tl tr bl br h v`, as [frame's custom styles](composition.md#custom-borders)
do. `drift.txt` is a frame in `****=!` whose right side moved on its
third line:

```text
$ tessella lint --geometry drift.txt && \
    echo 'clean: the custom box is not read'
clean: the custom box is not read
```

```text
$ tessella lint --geometry --border '****=!' drift.txt
drift.txt:3: side of box opened at line 1 col 1 is off at col 19
drift.txt:3: connector '!' at col 20 hangs from ' '
```

## Rulers

`--ruler` prints, on stdout, each line's width and the columns of its
verticals. Down a figure the verticals must agree, so a ruler shows a
drift at a glance, even one `--geometry` is not asked to find:

```text
$ tessella lint --ruler table-drift.txt
table-drift.txt:1: width=7
table-drift.txt:2: width=7  verticals=1,4,7
table-drift.txt:3: width=8  verticals=1,5,8
table-drift.txt:4: width=7
```

## Markdown

Linted whole, a Markdown file's prose and tables would be read as
art. `--fences` (`fences: true`) lints each fenced block on its own,
keeping the file's line numbers; a `tessella: allow-mixed` marker just
before a fence exempts that block. `notes.md` holds a table, some
prose, and a hand-drawn diagram whose connector is one column off:

```text
$ tessella lint --fences --geometry notes.md
notes.md:13: connector '│' at col 20 hangs from '─'
```

A Markdown file is usually read on the web, so lint it for that
target too. `--target web` also flags the `▶` at the end of the
diagram's arrow, which a browser may draw as a wide emoji:

```text
$ tessella lint --fences --geometry --target web notes.md
notes.md:11: emoji-capable U+25B6 ▶ (web target)
notes.md:13: connector '│' at col 20 hangs from '─'
```

Redrawn with a small arrow head, `▸`, and the connector back on its
`┬`, the figure in `notes-fixed.md` is clean for the web:

```text
$ sed -n 10,16p notes-fixed.md
┌───────┐     ┌───────┐
│ parse │────▸│ draw  │
└───────┘     └───┬───┘
                  │
              ┌───┴───┐
              │ print │
              └───────┘
```

```text
$ tessella lint --fences --geometry --target web notes-fixed.md && echo clean
clean
```

## The target

The options describe where the figure is going:

- `--no-wide`: every wide (two-cell) glyph is a finding, for a target
  whose font may not draw CJK at double width.

```text
$ tessella lint --no-wide wide.txt
wide.txt:2: wide char U+65E5 日
wide.txt:2: wide char U+672C 本
wide.txt:2: wide char U+8A9E 語
```

```text
$ printf '+---+\n|é  |\n+---+\n' | tessella lint --target cjk
stdin:2: ambiguous U+00E9 é on aligned row (cjk target: 2 columns)
```

- `--target term|cjk|web`: measure with a [width target](targets.md)'s
  widths. `web` is `--web`, and lets a glyph followed by U+FE0E pass;
  `cjk` names an ambiguous glyph that is not box drawing on a row
  that must line up, since it takes two columns there.
- `--web`: a page in a browser. Glyphs some web renderers draw as
  emoji, or two cells wide, are flagged.
- `--ascii`: every non-ASCII glyph is a finding (it implies
  `--no-wide`).
- `--forbid SEQ`: lines holding SEQ are findings. SEQ is a sequence,
  or a preset naming the comment syntax the figure sits in, so a line
  that would end the comment early is caught: `xml`, `html`,
  `c-block`, `rust`, `c-line`, `haskell`, `ocaml`, `pascal`, `d`,
  `lisp`, `lua`, `python-doc`, `cdata`, `markdown-fence`. The option
  repeats.

```text
$ tessella lint --forbid c-block figure.c
figure.c:1: forbidden sequence "/*"
figure.c:2: forbidden sequence "*/"
figure.c:5: forbidden sequence "*/"
```

Here the comment's own opener and closer are caught too: lint the
figure, not the comment around it.

## The alphabet

Before a figure goes into a file, `--alphabet` (`Tessella.alphabet`)
says what that file already holds. It lints nothing and exits 0. A
file that is pure ASCII should get an ASCII figure:

```text
$ tessella lint --alphabet figure.c langs.csv plot.txt notes.md
figure.c: ascii
langs.csv: ascii
plot.txt: utf-8 box-drawing(7) blocks(27) other(1: U+00B7 ·)
notes.md: utf-8 box-drawing(65) geometric(1)
```

## From Ruby

```ruby
# frozen_string_literal: true

# examples/lint.rb: the lint from Ruby -- a figure tessella draws is
# clean by construction; a hand-drawn one is reported line by line,
# and the rulers show where its verticals stopped agreeing.
require "tessella"

chart = Tessella.bar(%w[ruby c rust], [12, 30, 7.5], width: 30)
puts "chart: #{Tessella.lint(chart.to_s, geometry: true).clean?}"

report = Tessella.lint(File.read("broken.txt"), geometry: true)
report.findings.each { puts "broken.txt:#{it.line}: #{it.message}" }

Tessella.lint(File.read("table-drift.txt")).rulers.each do |r|
    puts "line #{r.line}: verticals #{r.verticals.inspect}"
end
```

```text
$ ruby lint.rb
chart: true
broken.txt:1: tab character
broken.txt:2: trailing whitespace
broken.txt:3: side of box opened at line 2 col 1 is off at col 4
broken.txt:3: connector '│' at col 5 hangs from ' '
line 1: verticals []
line 2: verticals [1, 4, 7]
line 3: verticals [1, 5, 8]
line 4: verticals []
```

tessella holds its own output to this lint: a figure it draws is
clean by construction, which is the point of the
[rules every figure keeps](library.md#the-rules-every-figure-keeps).
