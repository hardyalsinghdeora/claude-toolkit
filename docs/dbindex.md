# dbindex — offline database schema index

**Version 1.1.0** · `dbindex`

Crawls the schemas of every `claude-vault` DB connection and stores the metadata locally, so "which table or column holds X?" is answered offline in milliseconds — no VPN, no connection, no schema dump in context.

## Why it exists

Schema questions are frequent and their natural answer is expensive: connect (needs VPN), run an `information_schema` query, and paste back a result that is mostly noise. Schemas also change rarely, so nearly all of that work is repeated for no new information. Indexing once and searching locally makes the common question effectively free — and answerable from a café without VPN.

## Storage

```
~/.claude/db-index/indexes/<entry>.json   one JSON per vault connection
~/.claude/db-index/logs/dbindex.log       crawl log, auto-rotated
```

The index holds **metadata only**: entry name, database, `schema.table`, column names and types. No host, no credentials, no data. Crawling goes through `db-conn`, so credentials never leave the Keychain.

## Usage

```sh
dbindex <query>                 # search tables + columns across all indexes
dbindex table <name>            # matching tables WITH their column lists
dbindex build [entry ...]       # crawl (default: every db-conn entry)
dbindex build <entry> --db X    # limit to one database
dbindex list                    # indexed connections + freshness
dbindex status                  # same, with per-database table counts
dbindex prune                   # drop indexes for entries gone from the vault
```

Options: `--limit N` (default 25), `--json`, `--db D` (build only).

## Design decisions worth knowing

**Refresh is manual, staleness is loud.** Schemas change on migration, not on a timer, so there is no automatic crawl. Instead searches warn when an index is more than 14 days old and name the exact command to fix it:

```
prod-postgres-db schema is 20 days old — `dbindex build prod-postgres-db` after migrations
```

A guarded weekly auto-refresh — only when the host is reachable, reusing `db-conn`'s probe — is planned (D3) so no-VPN runs skip silently rather than logging failures.

**One index per vault entry, not per database.** A single entry commonly holds dozens of databases; keeping them together means `dbindex <query>` searches everything you have access to in one pass.

## Reading the output

`dbindex status` shows the shape of each environment:

```
prod-postgres-db  [postgres, 22 databases, 301 tables, updated 2026-07-27 15:05:31]
    clientmanagement: 40 tables
    ...
```

Two things worth watching in that output:

- **Environments diverge.** A downstream environment can carry databases that production does not, so a schema answered from the wrong index may describe something that does not exist where you care.
- **Leftovers are indexed as real databases.** Migration shadow databases (`prisma_migrate_shadow_db_<uuid>`) and restore temporaries (`*_restore_temp_1`) are indistinguishable from real ones to the crawler and will appear in search results.

## Gotchas

- **The MySQL path is written but unvalidated** — a single crawl split by schema, never run against a real MySQL server because no such entry exists yet (D4). Treat its first use as a test.
- **Building needs reachability**, i.e. VPN for private endpoints. Searching never does.
- **No foreign-key information yet.** "What references this table?" still needs a live query; FK crawling is planned (D2).
- **Column *values* are never indexed** — this answers "where does this live", not "what is in it".

## Related

`db-conn` (the crawl path, and where you go once you know the table) · `claude-vault` (connection entries) · `claude-toggle dbindex on|off` (the directive)
