# Ledger

Goal (2026-11-05, verbatim):
> considere a full rewrite, and our own dedicated gem?

Done when:
- [x] D1: `make tests` in ~/Repos/inkchart passes, and the gemspec declares no runtime dependency — evidence: make tests ORACLE=… 201 runs, 0 failures, 0 skips; make check 38 files clean; runtime_dependencies [] (gemspec loaded); make build makes inkchart-0.1.0.gem (then make clean)
- [x] D2: every unicode_plot 0.0.5 kind (line, scatter, stairs, bar, histogram, box, stem, density) and canvas (braille, block, dot, ascii, density) has an inkchart counterpart, each with an oracle test comparing axis extents, bin edges and counts, percentiles against unicode_plot on the same data — evidence: oracle test classes for every kind (Line, Scatter, Stairs, Density, Bar, Histogram, Box, Stem) and canvas (TestCanvasOracle: braille, block, dot, density exact; ascii structure; TestCanvasDensityFuzz), plus Stats/Axis oracle tests for bins, counts, percentiles, limits; my own fuzz: 2,400 line/density renders, 900 bar/histogram/box, 600 stem, 1,600 canvas cases, all identical
- [x] D3: colour is an option: `--color` (library `color: true`) emits ANSI colour; the default output holds no escape byte — evidence: Inkchart.bar default output holds no escape, color: true does; exe/inkchart --color emits ANSI (15 lines with escapes)
- [x] D4: every kind, Unicode and `--ascii`, passes ascii-art's artlint.rb (and --ascii output is ASCII-only) — evidence: docs/ascii-art/tests/check-plot.sh: all 8 kinds x Unicode/--ascii lint clean through artlint.rb, --ascii ASCII-only (22/22)
- [x] D5: the ascii-art skill renders through a generated, drift-checked copy of inkchart, and its check-plot.sh passes with no gem installed — evidence: check-plot.sh passes with GEM_PATH/GEM_HOME pointing nowhere; INKCHART_SRC=~/Repos/inkchart drift check passes (scripts/inkchart.rb == make bundle)
- [x] D6: nothing published: no `gem push`, no public remote created — evidence: git remote -v empty; no gem push run; Makefile has no publish target
- [x] D7: the project's gate artifacts exist and are honest (README, design note, history, test suite, CHECKLIST.md, CLAUDE.md) per project-gates — evidence: README.md, DESIGN.md, HISTORY.md, test/ (make tests), CHECKLIST.md, CLAUDE.md present; read by me against the code (two README claims and one HISTORY claim corrected); check-doc.py 63 tokens resolve, check_md --strict OK, artlint clean on all four new documents

Constraints (verbatim, where said):
- C1: "inkchart" (the gem's name) — 2026-11-05
- C2: "i want color available as an option" — 2026-11-05
- C3: "Own repo ~/Repos/inkchart" (location) — 2026-11-05
- C4: "Not now" (publishing to rubygems.org) — 2026-11-05
- C5: "considere a full rewrite" — the scope is every unicode_plot feature, not only what plot.rb uses — 2026-11-05
- C6: "go (bars configurable)" — bar glyphs and track are options, the eighths with a · track only the default — 2026-11-05

Facts:
- F1: unicode_plot 0.0.5 (2021-03-23, MIT) is 2,352 lines; its one dependency, enumerable-statistics, is a C extension used only for histogram binning and box-plot percentiles — scratchpad/gems, gem spec
- F2: unicode_plot runs on Ruby 3.4.9 and under --enable-frozen-string-literal, every kind — probed 2026-11-05
- F3: the gem name inkplot is taken on rubygems.org (Yudai Takada, SVG/PNG charts); inkchart was free on 2026-11-05 — gem search -r
- F4: ascii-art's scripts/plot.rb (uncommitted in ~/skills) wraps unicode_plot today: colour off, rstrip, █ bars, --ascii frame rewrite, artlint pass; tests/check-plot.sh holds its contract — docs/ascii-art/
- F5: a copy of unicode_plot for oracle tests lives at the session scratchpad gems/ (GEM_PATH), not installed for the user — scratchpad
- F7: unicode_plot's densityplot is a scatterplot on its density canvas (no kernel estimate) — densityplot.rb
- F9: unicode_plot's histogram bakes ANSI escapes into its bin-label strings even with color: false at render; a frame measuring them counts the escapes — oracle probe 2026-11-05
- F10: the ASCII glyph rule checks density (>= 7 of 9) before crossings: any such cell holds a full row and a full column, so the other order makes # unreachable — P2 run 2
- F11: unicode_plot's DensityCanvas maps pixels to cells with an uncorrected float formula (13.fdiv(23)*23 floors to 12); inkchart's density canvas reproduces it for parity — P2 run 2
- F12: P4 reported make check clean, but its test_line.rb failed Metrics/AbcSize at hand-back; its claim that lines never matched the gem was overstated (599/600 matched): the real cause, from + inc * i against the gem's running sum, was one pixel on rare inputs — fixed by me in Canvas#step_line, and TestLineOracle now compares full bodies — 2026-11-05
- F13: UnicodePlot.stemplot prints to $stdout instead of returning a plot; its oracle tests capture stdout — P9
- F14: unicode_plot's histogram labels crash on bins of width >= 10 (float_round_log10 returns an Integer); inkchart's do not — P8
- F15: both scribes hit the 60-turn cap after writing and before reporting; resumed for the report only. P7a's report marked the bar-settings claim verified while its README said █ (the gem's glyph is ■): my read caught it, and the colour claim (labels are not coloured) — 2026-11-05
- F8: no repo commit yet; the house rule is commit on instruction only — ~/Repos/inkchart
- F6: Ruby 3.4.9 on amd64-freebsd15; the house Ruby style is the ruby skill, a Makefile follows the make skill — ruby -v; ~/skills code/ruby, dev/make

Decisions:
- 2026-11-05 — no runtime dependency: binning, percentiles and density estimation in plain Ruby — the C extension is the dependency most likely to break — by me
- 2026-11-05 — unicode_plot is a test oracle only; no code is copied from it (MIT allows it, but a carried-over line would carry its copyright notice) — by me
- 2026-11-05 — the skill carries a generated, drift-checked single-file copy of the library, as the shelf already does for skillpath.py and workflows (the user chose it with the location) — by user
- 2026-11-05 — colour off by default, an option (`color:` / `--color`) (C2); the off default is mine, the skill's output goes into documents — by user
- 2026-11-05 — house drawing rules built in, not patched on: no trailing blanks, --ascii draws its own frame — by me
- 2026-11-05 — bars configurable (C6): fill glyph, fractional eighths on/off, track glyph or none; default eighths + · track, `#` and no fractions under --ascii (C6); the defaults are mine — by user
- 2026-11-05 — plan approved — by user
- 2026-11-05 — ownership handed to the session named Inkchart; this ledger is its starting point — by user
- 2026-11-05 — the ASCII canvas uses an original glyph rule, not unicode_plot's lookup table (P2 escalated the conflict with no-copy); its glyphs follow the stroke (top/bottom/middle row, column, diagonals); judged by eye against the gem, not by parity — by me
- 2026-11-05 — the density canvas honours sizes below 5 (the gem clamps to 5) (P2's call, kept) — by me
- 2026-11-05 — P4 split: P4 (Chart + grid kinds) then P8 (bar kinds), sequenced on Chart's interface; P5 after P4 — one delegate for eight kinds risks its context — by me
- 2026-11-05 — standard-library requires (optparse, for the CLI) live in lib/inkchart.rb above the parts, and tools/bundle.rb carries them into the single file; CLI logic in lib/inkchart/cli.rb so the bundled copy holds it — by me
- 2026-11-05 — Axis.tick for axis extremes (whole Float without .0, as unicode_plot) beside Axis.label for values as given — P1 found limits are always Floats, so label alone printed 10.0 on every axis — by me
- 2026-11-05 — HISTORY.md dropped: its real history (vendoring rejected, the original ASCII glyph rule, the departures from unicode_plot with reasons, the name) moved to DESIGN.md "Why it is shaped so", which links unicode_plot; the rest restated README and DESIGN — by user
- 2026-11-05 — first commit, local only: no remote, no tag yet — by user
- 2026-11-05 — add(mark:) for ClimatControl's measured points: a marked series is drawn as one glyph per point in place of the kind's own drawing (a second add gives line plus marks), one character, ASCII under ascii: true, legend prefixed; grid kinds only; VERSION left at 0.1.0, bumps are the user's — asked by user, design mine
- 2026-11-05 — bug hunt fixes: CSV/tab lines split on their separator only; exact stem leaves (rounded before truncating); constant data >= 1e16 widened by tens; negative bars drawn about a zero column (user: "correctly draw negative bars"); non-finite or non-numeric values, non-positive width/height/scale, x/y length mismatch and > 1000 stems refused with ArgumentError; labels measured in display columns — all asked by user, designs mine
- 2026-11-05 — scope widened: a general ASCII/Unicode text-figure generator and composer (charts, frames, diagrams, arrows, picture dithering, …), charts its first module — by user
- 2026-11-05 — renamed inkchart -> ascii-art (gem ascii-art, module AsciiArt, require "ascii-art", command `ascii-art COMMAND`, chart as `ascii-art chart`, repo ~/Repos/ascii-art); rubygems.org may refuse the name as too close to ascii_art, moot while unpublished — by user (name, module, directory), subcommands mine
- 2026-11-05 — adoption: core first (grid, width, frame, compose), then the skill scripts as each is finished; artlint stays in the skill (more than a linter), a lint capability in the library to be considered — by user
- 2026-11-05 — the five skill generators (tree, table, bitfield, wave, seq) ported into the library by parallel Sonnet agents, each gated by byte parity with its script (47-77 cases), reviewed and rerun by me; one exit-status contract imposed across commands (unreadable file = 1, --period < 2 = 2); table has its own RFC 4180 reader, csv being a bundled gem in 3.4 — by me
- 2026-11-05 — new name chosen: tessella (free on rubygems.org, no near-duplicate in its full name list), to apply after the ports merge — by user
- 2026-11-05 — renamed ascii-art -> tessella (gem tessella, module Tessella, require "tessella", command `tessella`, repo ~/Repos/tessella); the ascii-art skill keeps its name — by user
- 2026-11-05 — table: multi-line cells, width:/min_width: fitting (widest column only, ArgumentError below min), ANSI kept across wraps, bold header under color:, align: symbols — asked by climat (CCIface) on the user's behalf, design mine, confirmed by CCIface
- 2026-11-05 — images: img2art ported (Tessella.image, `tessella image`); PNM and a built-in pure-Ruby PNG decoder always; every other format through rmagick as a soft dependency, never declared, loaded lazily in rmagick_reader.rb (the one file outside the entries that may require); without it, refused naming the gem and the magick pipe — by user (soft rmagick, PNM+PNG built in)
- 2026-11-05 — the command line is its own entry, lib/tessella/cli.rb (optparse + lib/tessella/cli/*); require "tessella" loads the library alone; the bundle carries both — by user
- 2026-11-05 — artlint ported as Tessella.lint / `tessella lint` (output contract kept, --paranoid dropped), with --fences and --geometry added; geometry opt-in because on by default it changes existing lint results and misreads tables — by user (port, both additions), agreed with Skills (contract, flags, marker spellings), opt-in mine
- 2026-11-05 — PNG/PNM readers hardened (palette bounds, PLTE length, data length before allocation, PNM maxval and samples, consecutive comment lines) after a bug hunt — by user
- 2026-11-05 — lint geometry reads every box-drawing glyph by its arms (light/heavy/double/rounded/dashed/mixed, not light only), with borders: / --border for custom sets; custom border sets for frame and table (Set or 6 glyphs, 11 with a table's tees; never silently replaced under ascii:) — by user ("do all")
- 2026-11-05 — stack gap: without a rule is N rows, not 2N (compose.rb's code contradicted its own help) — found by Tessella:doc, fix mine
- 2026-11-05 — ASCII rule enforced where it leaked: table cells/title, wave names/labels, chart text (checked on the finished figure; a non-ASCII data row is exit 1, a flag exit 2), bitfield names always (a bit-field is ASCII) — found by Tessella:doc, fix mine
- 2026-11-05 — area: true / --area on line and stairs: btop-style fill, one bar per pixel column (two per braille or block cell), y from 0, peaks kept; gradient: / --gradient by height under color: true, plain without; colours gain 0..255 and #rrggbb, an all-hex gradient blends — by user (fill, gradient, no-colour, two bars per char, specifiable gradient); named area: not fill: (bar's fill: is its glyph), mine
- 2026-11-05 — bar/histogram: orientation: (vertical columns) and blocks: (:eighths, :braille two columns or four rows per character, :block two); classic horizontal eighths untouched (oracle); orientation: is to come for box and the line family, meaning the direction of the value axis — by user (vertical histogram, block choice, braille 2 columns / 4 rows, orientation for every kind), naming mine

Pieces:
- P0 [kept: interface judgment, verified] — scaffold the repo (git init, gemspec, Makefile per make, minitest harness, oracle harness) and write the internal interfaces the other pieces share: Canvas (pixel grid → rows), Stats (bins, percentiles, density, scales), Layout (frame, axes, title, legend, colour) — evidence: DESIGN.md; make check 23 files no offences; make tests 3/3; make bundle parses and loads
- P1 [verified] sonnet, effort: medium, skills: ruby — Stats: histogram binning (both closed sides), percentiles, kernel density, log/ln/log2/log10 transforms, tick and label formatting; oracle tests against unicode_plot — evidence: its 23 tests rerun by me with the oracle, 0 failures; my own 300 random data sets (5 shapes, bins nil and 1..12, both closed sides) agree on edges, counts, percentiles and limits; rubocop clean on its 4 files
- P2 [verified] sonnet, effort: medium, skills: ruby — Canvases: braille, block, dot, ascii, density; pixel→cell tests — evidence: run 2; my fuzz on a new seed, 400 cases x braille/block/dot/density, 0 mismatches; ASCII sin/cos render judged legible by eye; build names missing keywords; make tests 80/80 with the oracle
- P3 [verified] sonnet, effort: medium, skills: ruby — Layout and render: frame (Unicode and ASCII), axis labels, title, legend, optional ANSI colour, no trailing blanks — evidence: its 19 tests rerun with the oracle, 0 failures; my own oracle comparison on 4 layouts it did not test (title+xlabel+ylabel+legend, two series, negative axes, long bar labels) identical line for line; rubocop clean; its one disable-next directive probed: scoped to the one line
- P4 [verified] sonnet, effort: medium, skills: ruby — Chart (lib/inkchart/chart.rb) and the grid kinds (kinds/line.rb: line, scatter, stairs, density) with Inkchart.<kind>; oracle tests per kind — evidence: my fuzz, 2,400 random full renders (line on braille/block/dot, density) identical to unicode_plot after the step_line fix; make tests 122/122 with the oracle; make check clean after two fixes of mine (below)
- P8 [verified] sonnet, effort: medium, skills: ruby — bar and histogram (kinds/bar.rb) and box (kinds/box.rb) on P4's Chart; bars configurable (C6); exact parity under the gem's bar settings — evidence: run 2; my fuzz 900/900 identical after it (bar, histogram, box); ASCII box derived glyph for glyph from the Unicode one, legible on spread data, collisions on close percentiles shared by the Unicode form; make tests 178/178 with the oracle
- P9 [verified] sonnet, effort: medium, skills: ruby — stem-and-leaf (kinds/stem.rb); exact parity with stemplot; split from P8 (the gem's largest file, one context each) — evidence: my fuzz, 300 random data sets (integers with negatives, one-decimal floats, 0..99, -1..1 two-decimal) in one- and two-sample form, 600/600 identical to stemplot, none raised; rubocop clean on its 2 files
- P5 [verified] sonnet, effort: medium, skills: ruby — exe/inkchart, the CLI (plot.rb's options and more) — evidence: my runs of every kind through exe/inkchart (header rows, --ascii ASCII-only, bins on bar refused exit 2, unknown option exit 2, non-number exit 1 naming row and field, missing file exit 1, bad --width exit 2); one defect fixed by me: the first series went unnamed (Inkchart.<kind> now takes name:, the CLI passes the header field), with tests; make tests 201/201
- P6 [kept: crosses the shelf, verified] — the ascii-art skill: generated copy, plot.rb on inkchart, check-plot.sh without any gem, docs — evidence: scripts/inkchart.rb vendored (make bundle, 2,088 lines); plot.rb a thin front end over Inkchart::CLI plus artlint; check-plot.sh 22/22 with GEM_PATH pointing nowhere, all 8 kinds x Unicode/--ascii lint-clean, ASCII-only under --ascii; INKCHART_SRC drift check passes against ~/Repos/inkchart; recipes.md sample regenerated; shelf make check, check-artlint, eval fixtures clean; uncommitted in ~/skills
- P7 [verified] sonnet, effort: medium, skills: scribe, project-gates — README, design note, history, CHECKLIST.md, CLAUDE.md for inkchart — evidence: two scribe runs (README+HISTORY, CHECKLIST+CLAUDE.md), both stopped at the turn cap and resumed for reports; my read against the code corrected the gem's bar glyph (■, not █) in README and HISTORY and the colour scope (cells only) in README, and resolved P7b's BLOCKED doc-claim (my own CHECKLIST wording); check-doc.py, check_md --strict, artlint clean

Open:
- nothing committed: ~/Repos/inkchart has no commit yet; the ascii-art changes in ~/skills (docs/ascii-art: plot.rb, inkchart.rb, check-plot.sh, README, tests/README, recipes.md) are uncommitted — asked 2026-11-05
- the oracle copy of unicode_plot lived in the handing-over session's scratchpad and goes with it; reinstall one with gem install --install-dir DIR --no-document unicode_plot and pass ORACLE=DIR — asked 2026-11-05

Out of scope, noticed:
- ~/skills scribe: stamp.py records no file list in a repository with zero commits (it gates on git log -1), so check-report.py's tree-matches check has nothing to subtract; P7a rebuilt before.txt by hand — docs/scribe/scripts/stamp.py
- ~/skills: the delegation Tools: header work (dispatch/delegation/*, a TODO.md hunk) is uncommitted and has no owner in this session
- ~/skills: ascii-art plot.rb and check-plot.sh are uncommitted; they change again in P6
