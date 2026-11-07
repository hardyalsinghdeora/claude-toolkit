# claude-toolkit

Small, dependency-free CLI tools that make AI coding sessions (Claude Code) safer and smoother:

- **claude-toggle** — enable/disable MCP servers without losing their config; profiles, backups, restore
- **claude-vault** — secrets in the macOS Keychain, built to be *used* by AI sessions without ever being *seen* (password-type entries, per-member DB passwords, optional PIN lock)
- **db-conn** — query Postgres/MySQL with vault-stored credentials; no password ever touches the command line or transcript
- **squeeze** — compress verbose command output before it lands in the AI transcript, to manage token utilization
- **cindex** — per-project code index (symbols + files) so code search returns compact `path:line` results instead of raw grep dumps
- **dbindex** — schema index of every vault DB connection (databases → tables → columns), so "which table holds X" is answered offline with no VPN, connection, or token cost
- **csession** — task-level index of all Claude Code sessions: find past work, resume-vs-new-session suggestions, compact context briefs, combined work journal, safe pruning

- **toolkit** — one command to install every tool (`toolkit install`) and one to verify the whole setup (`toolkit doctor`: symlinks, versions, PATH, launchd agents, directive freshness, index age, vault health; non-zero exit when broken)
- **worklog** (`bin/`) — zero-token daily work logs: auto-generated at login and 21:15 from the csession index + git commits (sessions, commits, files touched, improvement flags), backfilling the last 7 days so weekends/leave need no bookkeeping; `worklog week` aggregates for reports, and the `worklog` skill layers AI narrative and coaching on top. See `Output/worklog/README.md` for the file format.

Plus `bin/atl` — an offline Jira/Confluence fetcher (JQL search, sprint issues, fix-version resolution, page-to-plain-text, accountId lookup, issue creation) authenticated via a `jira-api-token` claude-vault entry. The `skills/` workflows call it instead of the Atlassian MCP, turning schema-heavy MCP round-trips into compact TSV/text.

How these fit together — and the manual habits they can't replace — is in [docs/token-optimization.md](docs/token-optimization.md).

**Per-module documentation** — design rationale, storage layout and gotchas for each tool — is in [docs/](docs/README.md). The build history and the failures that motivated each piece are in [docs/project-history.md](docs/project-history.md).

## claude-toggle — MCP servers on/off

Enable/disable local MCP servers for Claude Code without losing their configuration, and save/restore whole config profiles.

Claude Code's built-in `claude mcp remove` **deletes** a server's config permanently. This tool instead *moves* the config into a stash file (`~/.claude/mcp-disabled.json`), so re-enabling restores it exactly — auth settings included. Every change first writes a timestamped backup of `~/.claude.json` to `~/.claude/backups/`.

## Install

Requires Python 3 (pre-installed on macOS). No dependencies.

```bash
./bin/toolkit install    # symlink every tool into ~/.local/bin
./bin/toolkit doctor     # verify links, versions, PATH, agents, directives, indexes
```

On Windows run the same commands with `python bin/toolkit ...`. Instead of symlinks,
`install` writes two launchers per tool into the bin dir: `<tool>.cmd` (cmd/PowerShell)
and an extensionless `<tool>` for Git Bash. squeeze, cindex, csession and the other
pure-Python tools work there; the Keychain and launchd parts (claude-vault, db-conn's
credentials, `toolkit agents`) are macOS only.

Layout:

```
bin/          every executable — the only thing 'toolkit install' links onto PATH
docs/         one reference page per tool
automation/   launchd job scripts + the agent manifests they render from
Scripts/      helper scripts invoked by absolute path, not via PATH (e.g. apidog-mcp.sh)
Output/       local-only work product (gitignored)
skills/       workflow definitions (local-only except README, _example, worklog)
```

`toolkit doctor` exists because of a real incident: the repo moved and every
symlink silently broke — two tools were dead on PATH for days. Run it after any
move, upgrade, or when something behaves oddly; it exits non-zero when broken.

## Usage

```bash
claude-toggle list                                # all MCP servers per scope, with status + endpoint
claude-toggle disable <server>                    # disable everywhere it's configured
claude-toggle disable --all                       # disable every server
claude-toggle disable <server> --project <path>   # disable for one project only
claude-toggle disable <server> --global           # disable in global scope only
claude-toggle enable <server>|--all [--project <path>|--global]

claude-toggle profile save <name>                 # snapshot MCP config + settings.json
claude-toggle profile load <name>                 # restore MCP config from a snapshot
claude-toggle profile load <name> --all           # ...also overwrite settings.json
claude-toggle profile load <name> --settings-only # ...only settings.json
claude-toggle profile list

claude-toggle status                              # enabled/disabled summary, matching
                                                  # profile, directive states
claude-toggle diff <profile>                      # what loading this profile would change
claude-toggle group set work atlassian zoho       # named server sets ...
claude-toggle disable @work                       # ... toggled together

claude-toggle squeeze on|off|status               # toggle the global "compress verbose
                                                  # output via squeeze" directive
                                                  # in ~/.claude/CLAUDE.md
claude-toggle cindex on|off|status                # toggle the global "search code via
                                                  # the cindex index" directive
claude-toggle directives                          # every directive: off / current / outdated
claude-toggle <directive> refresh                 # re-apply current block text after an
                                                  # upgrade changed the wording
claude-toggle doctor --fix                        # fix double entries (live+stash) and
                                                  # stashed scopes for deleted projects
claude-toggle backups                             # list auto-backups
claude-toggle backups prune --keep 10             # trim old backups (auto-kept at 20)
claude-toggle restore                             # roll back to the latest backup
claude-toggle restore --mcp-only                  # graft only the MCP scopes from the backup,
                                                  # leaving session state/OAuth untouched
claude-toggle restore claude.json.<stamp>         # roll back to a specific one
claude-toggle version
```

Example:

```bash
claude-toggle profile save full     # keep a way back
claude-toggle disable zoho
claude-toggle disable atlassian --project ~/Workspace
claude-toggle list                  # verify
# ... later ...
claude-toggle profile load full     # everything back on
```

## claude-vault — private credentials & personal config

Companion tool in this repo. Stores secrets (DB credentials, API keys, personal settings) in the **macOS Keychain** — encrypted by the OS, never in plaintext files, never in a git repo. Only names/descriptions are indexed locally (`~/.claude/vault-index.json`); values live solely in the Keychain.

Built to use with AI sessions: Claude fetches a credential at the moment it needs it instead of the value sitting in prompts, memory, or config files.

```bash
claude-vault set inventory-db --json --desc "MySQL for the inventory service"
#  paste: {"host":"...","port":"3306","user":"...","password":"...","database":"..."}
claude-vault set jira-token --desc "Jira API token"

claude-vault list                        # names + descriptions only, no values
claude-vault get inventory-db --field host   # one field of a JSON secret
claude-vault get jira-token              # whole value
claude-vault set inventory-db --field password   # update ONE field, keep the rest
claude-vault set jira-token --from-clipboard # take the value from the clipboard
printf '%s\n' "$VAL" | claude-vault set x --stdin   # scriptable set
claude-vault rename inventory-db inventory-db-old
claude-vault delete jira-token

claude-vault set my-pw --password        # password-type: NEVER displayed on a
                                         # terminal — usable only via $(...) /
                                         # pipes, or `get my-pw --copy`
claude-vault pin enable my-pw            # optional per-entry PIN lock (default off):
                                         # value stored PBKDF2-encrypted, reads
                                         # prompt for the PIN
claude-vault pin disable my-pw

claude-vault doctor --fix                # reconcile Keychain vs index (adopt/prune drift)
claude-vault test prod-postgres-db       # live check: ok / AUTH FAILED / UNREACHABLE (VPN hint)
claude-vault test --all                  # health-check every JSON entry
claude-vault import .env --name mydb     # .env -> one JSON entry (POSTGRES_*/DB_*/MYSQL_* auto-mapped)
claude-vault exec mydb --prefix PG -- psql   # run with PGHOST/PGUSER/PGPASSWORD... exported;
                                             # the secret never transits the shell or transcript

claude-vault set api-key --rotate-days 90    # list/get warn once the entry is older than 90d
claude-vault desc mydb "new description"     # edit description without re-entering the secret
claude-vault get api-key --copy --clear 30   # clipboard, auto-cleared after 30s
claude-vault list --json                     # machine-readable metadata (no values)
source <(claude-vault completion zsh)        # tab-complete commands + entry names
```

`rename` and `delete` also warn when files in the toolkit (configurable via `~/.claude/vault-consumers.json`) still reference the entry name — no more silently broken scripts.

**Team convention — shared DB config, per-member passwords.** Keep the connection
config (host/port/user, *no password*) as a JSON entry, and each member's password
as a separate password-type entry. Role variants let a view-only password differ
from an update password:

```
prod-postgres-db                     {"host":..,"port":..,"user":..}
prod-postgres-db.<dbuser>            password-type, one per member
prod-postgres-db.<dbuser>.ro / .rw   optional: view-only vs update passwords
```

Never pass the secret itself as a CLI argument — it would land in shell history and `ps` output; use the hidden prompt, `--stdin`, or `--from-clipboard`.

Example — query a DB using stored credentials, with the password kept out of argv
and out of the transcript (`exec` exports each JSON field as `DB_<FIELD>`; the single
quotes make the child `sh` expand them, and mysql reads the password from `MYSQL_PWD`):

```bash
claude-vault exec inventory-db --prefix DB_ -- \
  sh -c 'MYSQL_PWD="$DB_PASSWORD" exec mysql -h "$DB_HOST" -u "$DB_USER" "$DB_DATABASE" -e "SELECT ..."'
```

`claude-vault get` prints the value to stdout; when an AI session runs it, that output is
the transcript, so `get` warns on stderr whenever stdout is not a terminal. Prefer `exec`
in agent sessions (or `db-conn`, which does this for you).

In a Claude Code session, just say e.g. *"search the inventory DB for X — credentials are in claude-vault under `inventory-db`"*.

Install: `./bin/toolkit install` (symlinks `bin/claude-vault` onto PATH). macOS only.

## db-conn — query any database via vault credentials

Engine-agnostic wrapper (Postgres and MySQL/MariaDB) that pulls the connection config from a claude-vault JSON entry — `{"engine":"postgres|mysql","host":..,"port":..,"user":..}`, engine guessed from the port if omitted — and the password from the matching per-member entry (`<entry>.<dbuser>[.ro|.rw]`). Fails fast with a VPN hint when the host is unreachable. (Replaces the old Postgres-only `core-db`.)

```bash
db-conn list                                       # config entries in the vault
db-conn prod-postgres-db mydb "SELECT id, username FROM users LIMIT 5"
db-conn --env stg tables mydb                     # --env X == entry X-postgres-db
db-conn inventory-mysql-db inventorydb "SELECT COUNT(*) FROM items" --csv
db-conn prod-postgres-db --user teammate2 mydb "SELECT 1"
db-conn prod-postgres-db --role ro mydb "SELECT ..."   # view-only password
db-conn prod-postgres-db mydb -f lookup.sql --csv > out.csv
db-conn prod-postgres-db mydb "SELECT ..." --md      # markdown table output
db-conn prod-postgres-db mydb "SELECT ..." --xlsx report.xlsx   # Excel file (stdlib, no deps)
db-conn prod-postgres-db mydb "UPDATE ..." --write   # prod is READ-ONLY unless --write:
                                                     # INSERT/UPDATE/DELETE/DDL are blocked
```

## squeeze — output compression for token-light sessions

Long build logs, test runs, and query dumps eat context-window tokens fast. `squeeze` compresses any command's output before it enters the transcript, while keeping the parts that matter:

- strips ANSI color codes, collapses blank-line runs and repeated lines
- truncates very long lines
- over the line cap, keeps head + tail and elides the middle — but **lines matching an error pattern survive the elision**, shown with their original line numbers (default pattern covers error/fail/exception/traceback/warning/timeout/etc.; override with `-k`, disable with `-k ''`)
- final byte cap as a hard ceiling (default 16 KB ≈ 4k tokens)
- `--json` mode compacts JSON and samples big arrays (first N items + "+N more")
- prints a savings report to stderr: `squeeze: 123,931 → 570 bytes (≈31.0k → ≈142 tokens, 100% saved)`

```bash
npm test 2>&1 | squeeze                    # pipe mode
squeeze -- ./gradlew build                 # wrapper: captures stdout+stderr,
                                           # preserves the command's exit code
db-conn prod-postgres-db mydb -f big.sql | squeeze -n 100
curl -s https://api.example.com/things | squeeze --json
squeeze -k 'FAILED|AssertionError' -- pytest -v
```

Options: `-n/--max-lines` (200), `-b/--max-bytes` (16000), `--head`/`--tail` split (60/40), `-w/--width` line clip (320), `-k/--keep` regex, `--keep-max` (30), `--json`, `--json-items` (5), `-q/--quiet`.

To make Claude use it automatically in every session, run `claude-toggle squeeze on` — it adds a marker-delimited directive block to `~/.claude/CLAUDE.md` telling Claude to pipe verbose commands through `squeeze`. `claude-toggle squeeze off` removes exactly that block (anything else in the file is untouched), `status` shows the current state, and a backup of `CLAUDE.md` is written before every change. Applies to new sessions only.

Install: `./bin/toolkit install`. Pure Python 3, no dependencies, works on any platform.

## cindex — indexed code search for token-light sessions

Raw `grep -r` over a repo dumps hundreds of lines into the AI transcript. `cindex` builds a per-project index of symbols (functions, classes, interfaces, SQL tables, …) and file paths, then answers searches with compact `path:line  kind name` results — a lookup costs a few dozen tokens.

- **auto-detects the codebase**: nearest `.git` upward from the cwd (else the cwd itself; refuses to index `$HOME`)
- **first search builds the index** automatically; later searches refresh incrementally — only files whose mtime/size changed are re-scanned (a warm search on a 250-file repo takes ~80 ms)
- honours `.gitignore` (uses `git ls-files`) **and `.claudeignore`** (glob per line — keep task outputs, usage data, and logs out of the AI-searchable index even when they're in the repo); skips `node_modules`, build dirs, binaries, files > 512 KB
- storage is `~/.claude/code-index/` — `indexes/` holds one JSON per project, `logs/cindex.log` records every build/refresh (auto-rotated at 512 KB); **nothing is written into the project**
- languages: Python, JS/TS/JSX/TSX, Go, Java, Kotlin, C#, PHP, Ruby, Rust, C/C++ (types), SQL, shell; other text files are path-indexed

```bash
cindex authenticate            # symbol + file search (builds index on first use)
cindex file login              # file-path search only
cindex grep 'user_sessions' --ext .sql   # capped content grep over indexed files
cindex --all <query>           # search EVERY indexed project at once (18 repos here);
                               # a ticket id like PROJ-123 matches branch tags too
cindex refresh                 # incremental: re-scan only mtime/size-changed files
cindex build | status | list | prune     # full re-parse / maintain indexes
cindex <query> --limit 50 --json         # tuning / machine-readable
```

To make Claude prefer it in every session, run `claude-toggle cindex on` — same marker-block mechanism as the squeeze directive: adds a "search code via cindex, then Read only the file:line it points at" instruction to `~/.claude/CLAUDE.md`, `off` removes exactly that block, and `CLAUDE.md` is backed up before every change.

**Automated refresh (zero tokens):** `automation/cindex-refresh.sh` + the `com.<user>.cindex-refresh` LaunchAgent run an incremental `cindex refresh` over every code folder in `~/Workspace` at login and daily at 09:00 — pure shell, no Claude session involved. Sweep log: `~/.claude/code-index/logs/cron.log`.

Install: `./bin/toolkit install`. Pure Python 3, no dependencies.

## dbindex — indexed database schemas

Companion to `db-conn`: crawls the schema of **every DB connection configured in claude-vault** (databases → tables → columns with types) into a local index, so schema questions are answered offline — no VPN, no live `information_schema` query, and compact token-light output.

- crawls **via `db-conn`**, so credentials stay on the Keychain path; the index stores only metadata (entry name, database, table, column, type) — never hosts or passwords
- storage mirrors cindex: `~/.claude/db-index/indexes/<entry>.json` + `logs/dbindex.log`
- search is offline and instant (~50 ms); unreachable connections are skipped gracefully during builds with their old index kept
- Postgres and MySQL

```bash
dbindex build                     # crawl all vault connections (needs VPN for private DBs)
dbindex build prod-postgres-db --db coredb   # limit scope
dbindex subscription              # table + column search across all connections
dbindex token_hash                # column search: entry/db  schema.table.column  type
dbindex table user_subscription   # matching tables WITH full column lists
dbindex list | status | prune
```

Re-run `dbindex build` after migrations — schemas change rarely, so there's no automatic refresh. `claude-toggle dbindex on` (enabled by default here) adds the global directive telling Claude to consult dbindex before running live schema queries.

Install: `./bin/toolkit install`. Pure Python 3, no dependencies.

## csession — session & task management

Not a log viewer: it indexes **what you worked on** across every Claude Code session (task titles, prompts, projects, branches, files edited) so past work is findable and reusable, and the resume-vs-new decision is made on token cost, not guesswork.

- reads the session transcripts under `~/.claude/projects/` (read-only, except `prune --apply`); index at `~/.claude/session-index/`, incremental by mtime — 93 sessions index in under a second
- `suggest` encodes the token economics: resuming replays the entire transcript into context, so it recommends `claude --resume <id>` only for related sessions that are small (≤ ~60k tokens) and recent (≤ 14 days); otherwise it recommends a **new session seeded with `csession brief`** — a compact digest (topic, prompts in order, files edited) that continues the work for a fraction of the tokens
- `journal` combines all sessions into a what-I-worked-on digest by day
- `prune` finds empty/stale sessions; **dry-run by default**, deletes only with `--apply` (also removes them from `claude --resume` history)

```bash
csession school onboarding        # find past sessions by task/topic
csession list -n 15               # recent sessions: when, project, task, ~tokens
csession show 59f3a355            # one session: tasks asked, files edited, resume cmd
csession brief 59f3a355 | pbcopy  # context digest → paste into a fresh `claude`
csession suggest "continue the PROJ-1234 work"   # resume vs new, with the command
csession PROJ-1234                # ticket search across sessions (prompts + branches)
csession journal --days 7         # combined work journal
csession prune --days 45          # cleanup candidates (add --apply to delete)
```

`claude-toggle csession on` (enabled by default here) adds the global directive: when you reference past work, Claude searches the index and pulls a brief instead of asking you to re-explain — and answers "continue or new session?" with `csession suggest`.

Install: `./bin/toolkit install`. Pure Python 3, no dependencies.

## Examples — what a session actually looks like

All samples below are sanitized/generic; real outputs stay on the local machine (see *Local-only directories*).

**squeeze** — a 5,000-line test log enters the transcript as ~20 lines; the buried failure survives:

```
$ squeeze -- npm test
INFO processing case 1
…
··· 4,981 lines elided (1 matching lines kept below) ···
  L2501: ERROR: connection refused at row 2500
INFO processing case 5000
squeeze: 123,931 → 570 bytes (≈31.0k → ≈142 tokens, 100% saved)   # ← stderr report
```

**cindex** — "where is the login logic?" costs a handful of lines instead of a grep dump:

```
$ cindex login
src/dal/interface/ILoginTokenRepository.ts:3  interface ILoginTokenRepository
src/dal/login.repository.ts:8                 class LoginTokenRepository
src/dal/queries.sql:130                       table login_tokens
src/services/loginService.ts:17               class LoginService
```

**dbindex** — schema questions answered offline, across every environment at once:

```
$ dbindex token_hash
prod-postgres-db/authdb   public.account_tokens.token_hash   character varying
stg-postgres-db/authdb    public.account_tokens.token_hash   character varying

$ dbindex table sessions
prod-postgres-db/authdb  public.user_sessions
    id  uuid
    user_id  character varying
    expires_at  timestamp with time zone
```

**csession** — the resume-vs-new decision, priced in tokens:

```
$ csession suggest "continue the report-builder work"
  related: 2026-07-27 08:42  ef8baee3  myproject  ~220k tok  Implement report builder
recommendation: START NEW, seeded with a brief — related session found but
~220k-token transcript; resuming would replay it all into context.
  csession brief ef8baee3 | pbcopy   # then paste into:  claude

$ csession journal --days 7
2026-07-27
  09:31  myproject   Review onboarding module task  (2 tasks, ~40k tok)
  08:42  myproject   Implement report builder       (8 tasks, ~220k tok)
```

**atl** — a Jira sprint query as TSV instead of an MCP JSON payload:

```
$ bin/atl sprint "Sprint 42" --mine
PROJ-101  Review       Task  A. Developer  API for visit summary service
PROJ-102  Ready for QA Task  A. Developer  Route-level unit tests for module APIs
# 2 issues: Ready for QA=1, Review=1
```

## Local-only directories (never committed)

The tools separate **engine** (committed, generic) from **work product** (local, personal). `.gitignore` and `.claudeignore` enforce it:

| Path | Holds | Why local-only |
|---|---|---|
| `Output/` | Generated reports, PR reviews, dashboards, SQL deliverables | Company/task data |
| `skills/*` (except README, `_example`, `worklog`) | Personal workflow skills (PR review conventions, sprint reports…) | Encodes employer-specific process |
| `*.log`, `logs/` | Tool/automation run logs | Usage history |
| `.env`, `*.env` | Local config | Secrets belong in `claude-vault` |

Index data never lives in any repo at all — it goes to `~/.claude/{code-index,db-index,session-index}/`, each with an `indexes/` + `logs/` pair. `.claudeignore` additionally keeps these categories out of the AI-searchable code index even where they exist on disk.

## Notes

- Changes take effect in **new** Claude Code sessions, not ones already running.
- Avoid toggling at the exact moment a live session exits — Claude Code rewrites `~/.claude.json` on exit and could overwrite the change (the auto-backup lets you recover).
- The tool manages the **current user's** config only (`~/.claude.json`, `~/.claude/`); each teammate runs it on their own machine.
- Profiles are stored in `~/.claude/config-profiles/`, disabled servers in `~/.claude/mcp-disabled.json`.
