# CHECKLIST

What closes a round on ascii-art. A round is not closed while any box
is unchecked.

## Gates

Run in this order: `check` is fast and needs no oracle, so a style
break is caught before the slow oracle run.

- [ ] `make check` — every file under `lib exe tools test` parses with
  warnings on, then passes the RuboCop gate in `.rubocop.yml`.
- [ ] `make tests ORACLE=/path/to/gems` — the suite with the
  `unicode_plot` comparisons. `ORACLE` is a `GEM_PATH` holding
  `unicode_plot` (`gem install --install-dir DIR --no-document
  unicode_plot`); bare `make tests` skips those comparisons and does
  not close a round.
- [ ] `make build` — the gem builds from `ascii-art.gemspec`, whose
  errors no other gate loads it to find.
- [ ] `make bundle` — regenerates `dist/ascii-art.rb` from
  `lib/ascii-art.rb`'s require order; a new file or a changed load order
  needs it even when `make check` is silent.
- [ ] `env ASCII_ART_SRC=$PWD sh /home/sdalu/skills/docs/ascii-art/tests/check-plot.sh`
  — passes after `dist/ascii-art.rb` has been copied over the ascii-art
  skill's `scripts/ascii-art.rb`. That tree is not this project's: hand
  the copy to its owner rather than committing it from here.

## Documents

- [ ] `README.md` — does every option, flag, kind and exit status it
  names still exist, and do its renders still come out byte for byte?
- [ ] `DESIGN.md` — if this round changed an interface or took a
  decision, is it written down, with the alternative it rejected and
  why? Did it remove a departure from unicode_plot the "Why" section
  still lists?
- [ ] `CLAUDE.md` — does every file it names exist, does its `Gate:`
  command run, and do the house rules still hold?
- [ ] This file — did the round run a gate it does not list, or skip
  one that no longer applies?

## Release

- [ ] Does the number move? `lib/ascii_art/version.rb` is the one place
  `VERSION` is written (`make version` prints it). The user bumps it,
  never a session: a round that changes behaviour says so in its report
  and leaves the number alone.

No round closes by publishing: there is no deploy or publish target,
and nothing here pushes a gem or creates a public remote.
