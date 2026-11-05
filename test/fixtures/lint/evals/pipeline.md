# nightly-import

Loads the supplier's nightly CSV exports into the reporting database.

## How it runs

The importer watches the SFTP drop directory. Every file it finds goes
through the validator, which rejects malformed rows and writes the rest
into a work queue. Three identical workers pull rows from the queue and
insert them into Postgres. Once a night the reporter reads Postgres and
mails the summary. Rejected rows never reach the queue; they go to a
rejects file next to the drop directory for the supplier to look at.

## Configuration

| Variable          | Meaning                              | Default    |
| :---------------- | :----------------------------------- | :--------- |
| `IMPORT_DROP`     | SFTP drop directory                  | `/srv/in`  |
| `IMPORT_WORKERS`  | number of workers                    | `3`        |
| `IMPORT_DSN`      | Postgres connection string           | required   |

## Running the tests

```bash
python -m unittest
```
