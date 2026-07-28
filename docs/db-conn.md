# db-conn — query databases with vault credentials

**Version 1.2.0** · `db-conn` · Postgres and MySQL/MariaDB

Runs SQL against any database whose connection details live in `claude-vault`, so no password appears on the command line, in shell history, or in a session transcript.

## Why it exists

The natural thing — `psql -h host -U user` with a password pasted in, or a `PGPASSWORD=...` prefix — puts the credential in shell history and `ps` output, and in an AI session it also puts it in the transcript. `db-conn` takes an *entry name* instead of connection details and resolves everything through the Keychain at call time. It was originally `core-db`, hardcoded to one Postgres instance; the rewrite made it engine-agnostic and multi-environment.

## Credential resolution

A **config entry** is a JSON vault entry with no password in it:

```json
{"engine": "postgres", "host": "...", "port": "5432", "user": "..."}
```

`engine` is optional — guessed from the port (3306 → mysql, otherwise postgres).

The **password** comes from a separate password-type entry, so the config can be shared while the credential is not:

```
<entry>.<dbuser>          the password
<entry>.<dbuser>.ro       optional view-only variant
<entry>.<dbuser>.rw       optional update variant
```

`--user` picks the member, `--role ro|rw` picks the variant. Legacy entries with a `password` field inline still work as a fallback.

## Commands

```sh
db-conn list                                    # config entries in the vault
db-conn <entry> [--user U] [--role ro|rw] databases
db-conn <entry> tables <database>
db-conn <entry> <database> "<SQL>"              # inline SQL
db-conn <entry> <database> -f query.sql         # SQL from a file
db-conn --env prod|stg|test|local ...           # shorthand for <env>-postgres-db

# output modes
db-conn <entry> <db> "<SQL>" --csv
db-conn <entry> <db> "<SQL>" --md               # markdown table
db-conn <entry> <db> "<SQL>" --xlsx out.xlsx    # Excel, stdlib zipfile, no deps
```

## Design decisions worth knowing

**Reachability probe before connect.** A private endpoint (VPC/RDS) with the VPN down does not fail — it *hangs*, for minutes, with no explanation. `db-conn` probes with `nc -z -G 3 host port` first and fails immediately with a named cause:

```
db-conn: cannot reach <host>:<port> (<entry>)
         if this is a private endpoint (VPC/RDS), connect to the VPN and retry
```

**Prod is read-only by default.** Any entry whose name matches *prod* blocks statements matching `INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE` unless `--write` is passed. A one-line regex gate that makes the common case — read-only lookups for a support request — safe by construction. It is a guard against accidents, not a security boundary: anyone who can run `db-conn` can pass `--write`.

**`--xlsx` writes a real workbook with no dependencies**, assembled from `zipfile` and the minimal OOXML parts, because query results routinely end up in a spreadsheet deliverable and installing `openpyxl` into every environment is not worth it.

**`--env` is string substitution.** It expands to `<env>-postgres-db`; if your entries are named differently, pass the entry name directly.

## Gotchas

- **The write guard keys on the entry *name*.** A production database whose vault entry is not named `*prod*` is not protected. Name entries accordingly.
- **The MySQL path is exercised far less than Postgres.** It is implemented, but there is no MySQL entry in the vault today, so treat the first real MySQL use as a validation run (see D4 in `../ENHANCEMENTS.md`).
- **`--role` variants are optional.** If `<entry>.<dbuser>.ro` does not exist, the plain `<entry>.<dbuser>` password is used — you get access, just not the role you asked for. Check with `claude-vault list`.
- **Queries are passed to the engine client verbatim.** Quoting is your problem; prefer `-f query.sql` for anything with nested quotes.

## Related

`claude-vault` (credential storage, `test` for live checks) · `dbindex` (answer schema questions offline, without a query at all)
