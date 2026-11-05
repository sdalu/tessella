# Anchor drift fixture

The Stock lifeline sits one column right on the "held 10 min" row and
its reply arrow -- every other row has it at the same column. Taken from
a real repair that left this in (ascii-art eval 0, iteration 2).

```text
 Browser          API            Stock          Payments
    │              │               │               │
    │ POST /order  │               │               │
    │─────────────▸│               │               │
    │              │ reserve(sku)  │               │
    │              │──────────────▸│               │
    │              │   held 10 min  │              │
    │              │◂───────────────│              │
    │              │ charge(card)  │               │
    │              │──────────────────────────────▸│
    │              │               │   approved    │
    │              │◂──────────────────────────────│
    │              │ commit(sku)   │               │
    │              │──────────────▸│               │
    │ 201 Created  │               │               │
    │◂─────────────│               │               │
    ┴──────────────┴───────────────┴───────────────┴
```

If the provider declines, the API releases the reservation and answers
402; the browser shows the retry form.
