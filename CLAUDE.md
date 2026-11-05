# CLAUDE.md

ascii-art draws text figures on a monospace grid, in Unicode or pure
ASCII, with no runtime dependency; charts (line, scatter, stairs, bar,
histogram, box, stem, density) are its first module. What it is and
how to use it is in [README.md](README.md); why it is shaped as it
is, in [DESIGN.md](DESIGN.md). This file does not repeat either: it
is the entry point for a session, not a third copy of the facts.

## Gate

Gate: `make tests ORACLE=/path/to/gems`

runs the suite (`test/run.rb`, one minitest process) with the tests
that compare against `unicode_plot`. Without `ORACLE=` those tests
skip and the run reports how many, which does not close a round.
`make check` is the preflight; [CHECKLIST.md](CHECKLIST.md) is what a
round must close.

## Where the decisions are

[DESIGN.md](DESIGN.md) holds the interfaces the parts are built
against, the rules that hold in every part, and why the project is
shaped so. `.claude/LEDGER.md` is the ledger: the goal, the
constraints and facts behind it, and the decision log with its reasons
— read it before changing one of DESIGN.md's rules.

## Traps

- **The rules nothing mechanical catches.** DESIGN.md's "Rules that
  hold in every part" — no runtime dependency, no trailing blank,
  ASCII from the first byte, one load order in `lib/ascii-art.rb` — can
  break with `make check` and `make tests` both green. Read them
  before a change, not after.
- **No oracle installed by default.** The `unicode_plot` copy the
  oracle tests need is not kept anywhere; install one with
  `gem install --install-dir DIR --no-document unicode_plot` and pass
  `ORACLE=DIR`.
