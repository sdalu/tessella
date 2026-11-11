# Sequence diagrams

`seq` draws a UML-style sequence diagram: participants across the
top, their lifelines down, and messages between them in order.

```ruby
Tessella.seq(text, ascii: false, numbered: false, footer: false)
                                                       # => Block
```

```text
tessella seq [--ascii] [--numbered] [--footer] [--max-width N] [file]
```

## Input

One statement per line; blank lines and `#` comments are skipped.

| Statement               | Draws                                   |
|-------------------------|-----------------------------------------|
| `participant A`         | declares A, fixing its column           |
| `A -> B: text`          | a call, solid arrow                     |
| `A --> B: text`         | a reply, dashed arrow                   |
| `A ->> B: text`         | an asynchronous message, double head    |
| `A -> A: text`          | a self call, a loop right of A          |
| `note over A: text`     | a note on A's lifeline                  |
| `note over A,B: text`   | a note spanning A to B                  |

A name is a run of letters, digits, `_`, `.` or `-`, not ending in
`-`, so `A-->B` reads as a reply with or without blanks. Participants
take their columns in the order they are declared, or first appear;
columns widen to fit every label, never truncating one. A message
that skips participants carries its label in the gap beside its
sender, so the label never covers a lifeline the arrow passes.

```text
$ cat login.txt
participant Browser
participant Server
participant DB
Browser -> Server: POST /login
Server -> DB: SELECT user
DB --> Server: row
Server -> Server: check hash
note over Server,DB: bcrypt, cost 12
Server ->> DB: log attempt
Server --> Browser: 200 + cookie
```

```text
$ tessella seq login.txt
┌─────────┐    ┌─────────┐        ┌─────┐
│ Browser │    │ Server  │        │ DB  │
└────┬────┘    └────┬────┘        └──┬──┘
     │              │                │
     │ POST /login  │                │
     │─────────────►│                │
     │              │                │
     │              │  SELECT user   │
     │              │───────────────►│
     │              │                │
     │              │      row       │
     │              │◄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│
     │              │                │
     │              │──┐             │
     │              │  │ check hash  │
     │              │◄─┘             │
     │              │                │
     │              ├────────────────┤
     │              │bcrypt, cost 12 │
     │              ├────────────────┤
     │              │                │
     │              │  log attempt   │
     │              │──────────────►►│
     │              │                │
     │ 200 + cookie │                │
     │◄┄┄┄┄┄┄┄┄┄┄┄┄┄│                │
     │              │                │
```

## Arrow heads

Calls and replies end in `►` or `◄`, asynchronous messages in a
double head, `►►` or `◄◄`, in every [width target](targets.md). These
heads read at a glance and never turn into emoji in a browser, but a
font that lacks them draws them at a fallback width
([on the web](targets.md#web)). Under `--ascii` they are `>` and `<`,
and `>>` and `<<` for an asynchronous message.

## Options

`--numbered` numbers the messages; `--footer` repeats the participant
boxes under the lifelines, which helps a long diagram:

```text
$ tessella seq --numbered --footer login.txt
┌─────────┐       ┌─────────┐           ┌─────┐
│ Browser │       │ Server  │           │ DB  │
└────┬────┘       └────┬────┘           └──┬──┘
     │                 │                   │
     │ 1. POST /login  │                   │
     │────────────────►│                   │
     │                 │                   │
     │                 │  2. SELECT user   │
     │                 │──────────────────►│
     │                 │                   │
     │                 │      3. row       │
     │                 │◄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│
     │                 │                   │
     │                 │──┐                │
     │                 │  │ 4. check hash  │
     │                 │◄─┘                │
     │                 │                   │
     │                 ├───────────────────┤
     │                 │  bcrypt, cost 12  │
     │                 ├───────────────────┤
     │                 │                   │
     │                 │  5. log attempt   │
     │                 │─────────────────►►│
     │                 │                   │
     │ 6. 200 + cookie │                   │
     │◄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│                   │
     │                 │                   │
┌────┴────┐       ┌────┴────┐           ┌──┴──┐
│ Browser │       │ Server  │           │ DB  │
└─────────┘       └─────────┘           └─────┘
```

`--ascii` draws in `+ - |`, with `- - -` for a reply:

```text
$ tessella seq --ascii login.txt
+---------+    +---------+        +-----+
| Browser |    | Server  |        | DB  |
+----+----+    +----+----+        +--+--+
     |              |                |
     | POST /login  |                |
     |------------->|                |
     |              |                |
     |              |  SELECT user   |
     |              |--------------->|
     |              |                |
     |              |      row       |
     |              |<- - - - - - - -|
     |              |                |
     |              |--+             |
     |              |  | check hash  |
     |              |<-+             |
     |              |                |
     |              +----------------+
     |              |bcrypt, cost 12 |
     |              +----------------+
     |              |                |
     |              |  log attempt   |
     |              |-------------->>|
     |              |                |
     | 200 + cookie |                |
     |<- - - - - - -|                |
     |              |                |
```

## Errors

A line that is none of the statements above is refused, quoting it
(exit 1); so is input with no statement, and a non-ASCII name under
`--ascii`.

```text
$ printf 'A => B: x\n' | tessella seq
tessella seq: line 1: A => B: x
```
