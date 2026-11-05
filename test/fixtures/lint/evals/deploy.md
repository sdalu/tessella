# Deploy pipeline

A push to `main` builds an image, runs the test job against it, and
promotes the same image through staging to production. The gate before
production is a manual approval.

```text
┌────────┐    ┌────────┐    ┌────────┐    ┌──────────┐    ┌────────────┐
│  push  │───▸│ build  │───▸│  test  │───▸│ staging  │───▸│ production │
└────────┘    └────────┘    └───┬────┘    └────┬─────┘    └────────────┘
                                │              │
                                ▾              ▾
                          ┌───────────┐   ┌──────────┐
                          │ junit.xml │   │ approval │
                          └───────────┘   └──────────┘
```

Figure: one image, four stages; the approval holds the promotion.

Build times over the last eight runs, in minutes:

```text
run   1  2  3  4  5  6  7  8
min   ▃  ▄  ▂  ▅  ▇  ▄  ▃  ▂
```

Nothing is rebuilt between stages: staging and production run the digest
the test job passed.
