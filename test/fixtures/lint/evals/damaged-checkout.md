# Checkout flow

The browser talks to the API, which reserves stock and takes payment
before confirming. The sequence, with the reservation held while the
payment provider answers:

```text
 Browser          API            Stock          Payments
    │              │               │               │
	│ POST /order  │               │               │
    │─────────────▶│               │               │
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
    +--------------+---------------+---------------+
```

If the provider declines, the API releases the reservation and answers
402; the browser shows the retry form.
