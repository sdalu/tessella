# A Unicode tree whose label names a long option

The `--` in `--align` is a word, not a drawn rule: a figure is allowed to
name a command-line flag without being reported as mixing the two
structural vocabularies. Regression for the false positive that made
`make tests` fail on a correct README (2026-09-18).

```text
markdown/
├── SKILL.md                 rules the model applying the skill follows
├── scripts/
│   └── check_md.rb          the mechanical gate, and --align
└── tests/                   eval suite, not shipped
```
