# Enhancement Plan — claude-toolkit

_Drafted 2026-07-17 for `claude-vault`, `claude-toggle`, `core-db` (now `db-conn`). Extended 2026-07-27 as the token-optimization suite shipped: `squeeze` 1.0, `cindex` 1.3 (incl. `.claudeignore` support), `dbindex` 1.0, `csession` 1.0, the `claude-toggle` directive system (1.4.1, blocks compressed to ~28 CLAUDE.md lines), the cindex-refresh launchd sweep, `Scripts/atlassian/atl` (offline Jira/Confluence fetcher, live-verified), skills `sprint-briefing` + `build-release-email` ported from Promt, and `docs/token-optimization.md`._

## Real scenarios that motivated this plan

These all happened in practice and each maps to a feature below:

| # | Scenario | Feature |
|---|----------|---------|
| S1 | Prod password in the vault was stale (missing trailing `!`); three failed logins before the user pasted the right one | V6 verify, V5 rotation reminders |
| S2 | `claude-vault get stg-code-db` returned a value but `list` didn't show it — Keychain and `vault-index.json` had drifted | V4 doctor/sync |
| S3 | Renaming `prod-code-db` → `prod-core-db` required manual get + set + delete | V2 rename |
| S4 | Updating only the password inside a JSON secret required rebuilding the whole JSON via Python | V3 field update |
| S5 | `set` prompts interactively; from an AI/scripted session the value had to be piped via stdin, discovered by trial and error | V1 first-class non-interactive set |
| S6 | User pasted `.env`-style blocks (`POSTGRES_HOST=...`) in chat to get them into the vault | V7 import |
| S7 | RDS endpoint resolves to a private IP; connection just hung until VPN was diagnosed | C2 VPN pre-check |
| S8 | Vault entries were renamed and `core-db` silently broke (it referenced the old names) | C1 (fixed 2026-07-17), V8 references |
| S9 | Four environments now exist (`local/test/stg/prod-core-db`) but `core-db` only talks to prod | C3 `--env` |
| S10 | Repo moved `~/Desktop/claude-toggle` → `~/Workspace/Claude-toolkit`; all `~/.local/bin` symlinks silently broke — `claude-vault`/`db-conn` were dead on PATH for days, discovered only by accident (2026-07-27) | G1 doctor/install |
| S11 | The first cindex cron sweep called `build` (full re-parse of every repo) when the mtime-incremental `refresh` path already existed — caught by the user, fixed same day | (fixed 2026-07-27) |
| S12 | Directive text lives in `claude-toggle` source; a wording improvement in a newer version never reaches an already-enabled block in `CLAUDE.md` — the 2026-07-27 directive compression needed manual off+on ×4 | T9 directive refresh |
| S13 | Jira answers a bad-auth JQL search with **HTTP 200 and zero issues** (anonymous degradation) instead of an error — `atl` looked "working but empty" until `/myself` was checked | A2 identity guard (partially fixed: gateway mode persisted in atl-cache) |
| S14 | Atlassian **scoped** API tokens 401 on the site URL (work only via `api.atlassian.com/ex/<product>/<cloudId>`) and are product-scoped — the Jira token couldn't read Confluence | (fixed 2026-07-27: gateway fallback + path-aware token choice) |
| S15 | A scheduled headless tick hung 91 min with no output and had to be killed (2026-07-28). The only way to stop the *schedule* was `launchctl bootout` — after which the job is indistinguishable, to `toolkit doctor` and to the user, from a broken install. Two weeks later nobody would know it was paused on purpose | G4 pause/resume with state |
| S16 | The plists exist only in `~/Library/LaunchAgents/` — nothing in the repo, and launchd will not expand `~` inside one. `toolkit install` relinks all 9 binaries but cannot (re)create an agent, so an S10-style repo move leaves plists pointing at dead paths with no source of truth to re-render from | G5 versioned plist templates |
| S17 | The public repo carried the employer's Jira tenant + a work email hardcoded in `Scripts/atlassian/atl`, an internal MCP server name in `docs/launch-agent.md`, and a `$HOME` username in `csession` — pushed across 8 commits before anyone looked (2026-07-28) | (fixed 2026-07-28: config moved to `~/.claude/atl-config.json`; **history rewrite still outstanding**) |

---

## claude-vault

### V1. ~~First-class non-interactive `set`~~ — **done 2026-07-17** (vault 1.1.0; `--stdin`, `--from-clipboard`, hidden prompt)
Today stdin piping works by accident of `sys.stdin.isatty()`. Make it official:
`claude-vault set <name> --stdin`, plus `--from-clipboard` (reads `pbpaste`, offers to clear the clipboard after). Document both in help. Never accept the value as an argv argument (would leak into shell history / `ps`).

### V2. ~~`rename` command~~ — **done 2026-07-17** (vault 1.1.0)
`claude-vault rename <old> <new>`: copy Keychain item, update index, delete old — atomic from the user's view. (S3 did this by hand.)

### V3. ~~Update a single JSON field~~ — **done 2026-07-17** (vault 1.1.0; `set --field`, `get --field`)
`claude-vault set <name> --field password` prompts for just that field, merges into the existing JSON. Avoids the rebuild-whole-blob dance of S4 and avoids re-pasting fields that were already correct.

### V4. ~~`doctor` — reconcile Keychain vs index~~ — **done 2026-07-27** (vault 1.3.0; report by default, `--fix` adopts/prunes)
Scan the Keychain for `claude-vault.*` service items and diff against `vault-index.json`:
- item in Keychain but not index → offer to adopt (S2)
- index entry with no Keychain item → offer to prune
- JSON-typed entries that fail `json.loads` → flag
Run automatically (cheap check) at the top of `list`.

### V5. ~~Rotation metadata + staleness warnings~~ — **done 2026-07-27** (vault 1.4.0; `set --rotate-days N`, list/get warn when stale)
Optional `--rotate-days N` on `set`; `list` and `get` print a warning once an entry is older than its rotation window. Would have surfaced S1 before the failed logins.

### V6. ~~`test <name>` — live credential check~~ — **done 2026-07-27** (vault 1.3.0; ok / AUTH FAILED / UNREACHABLE-with-VPN-hint, resolves per-member password entries, `--all`)
For JSON secrets that look like DB credentials (have host/user/password), attempt a real connection (`psql`/`mysql` picked by port or a `type` field) and report ok/auth-failed/unreachable. Distinguishes "wrong password" from "VPN off" — exactly the S1 vs S7 ambiguity. `--all` flag to health-check the whole vault.

### V7. ~~Import from `.env` / bulk add~~ — **done 2026-07-27** (vault 1.3.0; POSTGRES_*/DB_*/MYSQL_* auto-map + `--map`)
`claude-vault import <file|-> --name core-db --map POSTGRES_HOST=host,POSTGRES_USER=user,POSTGRES_PASSWORD=password` (with sane defaults for the common `POSTGRES_*`/`DB_*`/`MYSQL_*` prefixes). Kills the paste-secrets-into-chat pattern of S6.

### V8. ~~Reference tracking / rename safety~~ — **done 2026-07-27** (vault 1.4.0; rename/delete grep consumer dirs — default: the toolkit repo, configurable via ~/.claude/vault-consumers.json)
`rename` and `delete` grep known consumer scripts (start with this repo, configurable list) for the entry name and warn: "`core-db` references `prod-code-db`". Prevents S8-style silent breakage.

### V9. ~~`exec` — inject secrets as env vars~~ — **done 2026-07-27** (vault 1.3.0; `--prefix PG` -> PGHOST/PGUSER/..., os.execvpe so the value never transits the shell)
`claude-vault exec <name> [--prefix PG] -- psql -h ...` runs a child process with fields exported (`PGHOST/PGUSER/PGPASSWORD` mapping built in). The secret never transits the parent shell, command line, or transcript at all — stronger than `$(claude-vault get ...)` substitution.

### V10. ~~Quality-of-life~~ — **done 2026-07-27 except Touch-ID** (vault 1.4.0; `list --json`, `desc`, `--copy --clear N`, zsh completion. Touch-ID ACL gating deliberately skipped: re-adding items with `-T ""` risks locking existing entries — revisit only on concrete need)
- `list --json` (machine-readable, for tooling and AI sessions)
- `desc <name> "text"` — edit description without re-entering the secret
- `get <name> --copy [--clear 30]` — clipboard with auto-clear
- shell completion for entry names
- optional Touch-ID gating via Keychain ACL (`security add-generic-password -T ""` + user-presence) for high-value entries

### V11. Cross-platform backend — **P3, large**
Abstract `kc_set/kc_get/kc_delete` behind a backend interface: macOS `security` (current), Linux `secret-tool`, Windows Credential Manager. Only worth it if the tool is shared beyond this Mac (relevant if it ever ships alongside the PR-review product).

---

## claude-toggle

### T1. ~~Backup retention~~ — **done 2026-07-17** (toggle 1.2.0; `backups prune [--keep N]`, default keep 20)
`~/.claude/backups/` grows without bound (one file per mutation, forever). Add `claude-toggle backups prune [--keep 20]` and auto-prune to the newest N after each backup.

### T2. ~~Profile load is destructive to settings.json~~ — **done 2026-07-17** (toggle 1.2.0; `profile load --all|--settings-only`, MCP-only by default)
`profile load` **replaces** `settings.json` wholesale with whatever was snapshotted, silently dropping anything added since the snapshot (permissions, hooks…). Fix: back up `settings.json` too (today only `.claude.json` is backed up), and add `--mcp-only` / `--settings-only` flags; make `--mcp-only` the default and full overwrite opt-in.

### T3. ~~`status` / `diff`~~ — **done 2026-07-27** (toggle 1.5.0; status includes matching-profile detection and directive states)
- `claude-toggle diff <profile>` — what would change if this profile were loaded
- `claude-toggle status` — current enabled/disabled summary + which profile (if any) it matches
Removes the guess-and-check around "which profile am I on?"

### T4. ~~Server groups~~ — **done 2026-07-27** (toggle 1.5.0; `group set/list/delete`, `disable @work`, stored in ~/.claude/toggle-groups.json)
Named sets in a small config file (e.g. `browser = claude-in-chrome`, `work = atlassian, zoho`): `claude-toggle disable @work`. Cheaper than full profiles when you just want to shed a category.

### T5. ~~`doctor` — consistency checks~~ — **done 2026-07-27** (toggle 1.6.0; double entries, stashed scopes for deleted paths, malformed stash; `--fix`)
Detect: same server present in both `.claude.json` and the stash (double-entry after a manual edit), stashed entries for project paths that no longer exist, malformed stash. Offer fixes.

### T6. ~~Selective restore~~ — **done 2026-07-27** (toggle 1.6.0; `restore --mcp-only` grafts MCP scopes only)
`restore` currently swaps the entire `.claude.json` (which also holds session state, history, OAuth). Add `--mcp-only` to graft only the `mcpServers` scopes out of the backup, leaving the rest of the live file untouched.

### T7. Per-project auto-profile via hooks — **P3, medium**
A SessionStart hook that applies a named profile based on the project directory (mapping in the profile file). Needs care re: the "changes apply to new sessions only" model — evaluate before building.

### T8. Track native disable support — **P3, watch**
If Claude Code grows a first-class `disabledMcpServers` field, migrate from the move-to-stash model to flipping that flag; keeps `claude /config` and other tools consistent with toggle state.

_(2026-07-27: 1.4.0 added the directive system — `squeeze`/`cindex`/`dbindex`/`csession` on|off|status toggling marker-delimited blocks in `~/.claude/CLAUDE.md`, with CLAUDE.md added to the backup/prune set.)_

### T9. ~~`directive refresh`~~ — **done 2026-07-27** (toggle 1.7.0; `<directive> refresh`, `directives refresh`, and drift shown in `status`)
Directive text is baked into the `DIRECTIVES` dict at enable time (S12): improving the wording in a newer claude-toggle leaves stale text in `CLAUDE.md` until someone does off+on by hand. Add `claude-toggle <name> refresh` (and a `refresh --all`) that replaces the block between the markers with the current text; print a note in `status` when the enabled block differs from the current source text.

### T10. ~~`directives` overview~~ — **done 2026-07-27** (toggle 1.7.0; one line per directive: disabled / enabled+current / enabled+OUTDATED)
`claude-toggle directives` — one line per known directive: enabled/disabled, whether the block text is current (see T9), and which tool it belongs to. Today you need four `status` calls.

### T11. Per-project directives — **P3, medium**
Directives currently only target the global `~/.claude/CLAUDE.md`. A `--project <path>` variant writing to `<path>/CLAUDE.md` would let e.g. `cindex` be on globally but off in a docs-only repo. Needs the same marker mechanism plus care about repos where `CLAUDE.md` is committed (write to `CLAUDE.local.md` instead).

---

## core-db

### C1. ~~Fix stale vault references~~ — **done 2026-07-17**
Now reads `prod-core-db`; the `prod-core-pass` fallback is removed.

### C2. ~~Fail fast with a VPN hint~~ — **done 2026-07-17** (db-conn; `nc -z -G 3` probe before psql, names the VPN)
Before running psql, probe the host (`nc -z -G 3 $HOST $PORT`). On failure print: `cannot reach $HOST:$PORT — if this is the prod/stg RDS (private IP), connect to the VPN first.` Turns S7's silent multi-minute hang into an instant, actionable error.

### C3. ~~Multi-environment support~~ — **done 2026-07-17** (db-conn `--env prod|stg|test|local`)
`core-db --env prod|stg|test|local ...` (default `prod`) selecting the `<env>-core-db` vault entry. All four entries already exist with identical shape, so this is just string substitution.

### C4. ~~Prod write guard~~ — **done 2026-07-27** (db-conn; entries matching *prod* block INSERT/UPDATE/DELETE/DDL unless `--write`)
Default to blocking statements matching `INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE` when `--env prod`, unless `--write` is passed. A one-line regex gate that makes the common case (read-only lookups for support requests) safe by construction.

### C5. ~~Convenience output modes~~ — **done 2026-07-27** (db-conn `--md` and `--xlsx <file>`, minimal xlsx via stdlib zipfile)
`--xlsx <file>` / `--md` output via a tiny Python helper, since query results regularly end up in Excel deliverables anyway.

---

## squeeze (new 2026-07-27)

### Q1. ~~Auto-detect content type~~ — **done 2026-07-27** (squeeze 1.1.0; JSON payloads compact automatically, no --json needed. JSONL mode still open)
`--json` is manual today. Sniff the first non-blank byte (`{`/`[`) and switch to JSON mode automatically; add a JSONL mode (compress per line) for log streams.

### Q2. Named profiles — **P2, small**
`squeeze --profile test|build|query` bundles sensible caps + keep-regexes per use case (e.g. `test` keeps `PASS|FAIL|✓|✗` counts, `build` keeps warnings). Profiles in a small JSON next to the tool config.

### Q3. Harness integration — **P3, watch**
If Claude Code hooks ever allow *transforming* Bash tool output (today PostToolUse can only observe/append), auto-apply squeeze to any output over the cap instead of relying on the CLAUDE.md directive being followed.

## cindex (new 2026-07-27)

_(1.3.0 shipped `.claudeignore` support — task outputs/usage/logs excluded from the searchable index per repo; verified on this repo: 122 → 18 indexed files.)_

### X1. ~~Cross-project search~~ — **done 2026-07-27** (cindex 1.4.0; `cindex --all <query>` over every project index)
`cindex --all <query>` searching every index under `~/.claude/code-index/indexes/` at once — "which service defines `SubscriptionRequest`?" spans repos today (18 Workspace projects indexed), and per-repo invocation misses that.

### X2. ~~Ticket/branch tags~~ — **done 2026-07-27** (cindex 1.4.0; ticket ids extracted from branch names at index time, matched by `--all`)
Extract Jira ticket IDs (`NAV-\d+` etc.) from branch names at index time so `cindex NAV-10083` finds the repos/branches where a ticket's work lives. Pairs with csession's ticket search (N3).

### X3. Richer language coverage — **P2, medium**
Method extraction for Java/Kotlin/C# is heuristic and C/C++ only gets types. Consider optional ctags integration when `universal-ctags` is installed (keep the regex fallback so the tool stays dependency-free).

### X4. `grep` via ripgrep — **P3, small**
`cindex grep` shells to `grep` per 200-file chunk; use `rg --files-from` when available for speed on the big repos (a 2.6k-file front-end repo).

## dbindex (new 2026-07-27)

### D1. ~~Staleness hint~~ — **done 2026-07-27** (dbindex 1.1.0; searches warn when an index is >14 days old, naming the rebuild command)
Schemas refresh only via manual `build`. Print a one-line warning on search when an index is older than N days (default 14): "prod-postgres-db schema is 20 days old — `dbindex build prod-postgres-db` after migrations."

### D2. Relationships — **P2, medium**
Crawl `information_schema.key_column_usage`/`table_constraints` for FKs; `dbindex table users --related` then shows what references/is referenced by a table — the question that today needs a live query and a lot of tokens.

### D3. Guarded auto-refresh — **P2, small**
Add an optional weekly leg to the launchd sweep that runs `dbindex build` only when the host is reachable (reuse db-conn's `nc` probe) so home/no-VPN runs skip silently instead of logging failures.

### D4. MySQL validation — **P2, small**
The MySQL path (single crawl split by schema) is written but untested — no MySQL entry exists in the vault yet. Validate against a real MySQL connection before relying on it.

## csession (new 2026-07-27)

### N1. ~~Outcome-aware briefs~~ — **done 2026-07-27** (csession 1.1.0; each prompt paired with the final assistant reply — briefs now read 'asked X -> result Y')
`brief` currently replays *prompts* (what was asked), not *outcomes* (what was done). Extract the final assistant text message per user prompt (capped) so a brief reads "asked X → result Y" — materially better seed context for continuing work.

### N2. SessionStart surfacing — **P2, small**
A SessionStart hook that prints one line when the new session's cwd matches recent indexed work ("3 recent sessions in this project — `csession list --project ...`"). Costs a few injected tokens; measure before defaulting on (see the zero-token principle from the cron decision).

### N3. ~~Ticket linking~~ — **done 2026-07-27** (csession 1.1.0; ticket ids from prompts+branches indexed and weighted in search)
Extract Jira IDs (`NAV-\d+`) from prompts/branches into a `tickets` field: `csession NAV-10083` → every session that touched that ticket. Combines with X2 for a full "ticket → sessions + repos + branches" answer.

### N4. Scheduled prune report — **P3, small**
Monthly launchd leg running `csession prune` (dry-run) and appending candidates to the log — keeps the 100+-session index tidy without ever auto-deleting.

---

## atl — offline Jira/Confluence fetcher (new 2026-07-27)

Live-verified: `whoami`, `jql`, `sprint --mine`, `user`, `page` (Jira via scoped token + gateway; Confluence via the separate `confluence-token`).

### A1. ~~Live-validate `version` and `create`~~ — **done 2026-07-27** (atl 1.1.0; `version` validated live against NAV v1.32.0 — which exposed a real bug: the `version` subcommand was being swallowed by the `--version` flag. `create` gets `--dry-run` (payload + auth check, no POST); a live create still needs an explicit user go-ahead)
`atl version <url>` and `atl create` are written but never run against real data (`create` deliberately — it makes a real ticket). Validate `version` on the next release URL; validate `create` on a throwaway ticket in a sandbox project, then delete it.

### A2. ~~Identity guard against anonymous degradation~~ — **done 2026-07-27** (atl 1.1.0; any empty result is proven via /myself — either 'authenticated as X, genuinely empty' or a hard failure with the token-refresh hint)
S13: Jira returns 200/empty on bad auth. Persisting gateway mode mostly closes this, but a token *revocation* would reopen it silently. Add `--check` (or automatic on empty results): call `/myself`; if unauthenticated, fail loudly with the vault setup hint instead of printing `# 0 issues`.

### A3. ~~Confluence table extraction~~ — **done 2026-07-27** (atl 1.1.0; ac:parameter/ri/macro-id noise dropped, `<time datetime>` resolved — sprint dates now extract, tables render as rows)
`atl page` flattens table macros roughly (`12falselistfalse …` artifacts from Confluence storage format). Parse `<table>` into markdown rows and drop macro metadata elements (`ac:structured-macro` parameters) before stripping tags.

### A4. Bitbucket sibling (`bbt`) — **P2, medium**
`bitbucket-token` already exists in the vault, and PR-fetch scripts live in `Promt/Scripts/MyPRReview`. Fold Bitbucket into the same pattern (one `atl`-style CLI: open PRs, PR diff stat, comments) so the pr-review/pr-dashboard skills get the same offline-first treatment as the Jira skills.

### A5. Rate/pagination hardening — **P3, small**
`page` caps at 15k chars and `jql` paginates, but there's no 429 backoff. Add a single retry-with-wait on 429.

## Skills (new 2026-07-27)

### K1. Single source of truth for skills — **P1, small**
Skills now exist in TWO places: `Promt/Skills/*.md` (older, MCP-first) and `Claude-toolkit/Skill/*/SKILL.md` (newer, offline-first, includes ports of Report/Build). Drift is guaranteed (pr-review vs Review.md already differ). Decide the canonical home (toolkit), convert the remaining Promt-only details into it, and leave pointer stubs in Promt/Skills.

### K2. Offline-first the remaining MCP skills — **P2, small**
`pr-dashboard`/`pr-review` still fetch via MCP/manual flows; once A4 exists, point them at the offline fetcher the same way sprint-retro/jira-ticket now point at `atl`.

---

## toolkit-gui — a macOS front end (new 2026-07-28)

**macOS only for now.** The tools are Keychain-, `launchctl`- and `pbpaste`-bound already (V11 exists precisely because a cross-platform vault backend does not), so a Mac-only shell adds no portability debt that is not already there. Revisit only if V11 ever ships.

The suite is nine CLIs plus three index stores, and its outputs are markdown files under `Output/`. Everything needed to *read* that state — `list`, `status`, `doctor`, `directives`, `dbindex list` — is already a command whose output is a table. A GUI earns its place by making that state visible at a glance and by making the read-only paths clickable; it does **not** earn its place by reimplementing any of it.

### U1. Shell out, never reimplement — **P0, foundational**
Every panel is a rendering of a real command's output, and the command is shown. The GUI parses `--json` where a tool offers it (`claude-vault list --json`, `cindex --json`, `dbindex --json`, `csession --json`) and falls back to text elsewhere. Consequences worth stating up front, because they are the whole design:
- the CLI stays the source of truth, so a GUI bug can never disagree with `toolkit doctor`;
- anything the GUI cannot do, the user can do in the terminal it just showed them;
- G2 (shared helpers) becomes more valuable — a uniform `--json` shape across the index family is what keeps this from being nine bespoke parsers. **Do G2 first.**

### U2. Tools list + directory listing — **P1, medium**
The primary navigation: one row per tool (the nine `toolkit list` entries) with version, symlink health and last-run, mirroring `toolkit doctor`'s per-tool row. Selecting a tool opens its panel.

The **directory listing** hangs off the same sidebar: the indexed projects under `~/Workspace` that `cindex` already knows about, with per-repo index age and branch, drilling into the file tree. Read-only browsing — clicking a file opens it in the markdown/code view (U3), it does not edit. The listing comes from the cindex index rather than a live filesystem walk, so it is instant and it respects `.claudeignore` for free.

### U3. Markdown view — **P1, small**
`Output/` is the suite's deliverable surface: worklogs, reports, review files. Render the selected `.md` with GitHub-ish styling, a file tree of `Output/` on one side, and raw/rendered toggle. Read-only in v1; editing is a separate decision, not a freebie.

### U4. Terminal view — **P1, medium**
An embedded terminal pane, for two distinct jobs that should not be confused:
1. **Echo** — every command the GUI runs appears here with its exit code, so the GUI is auditable and teaches its own CLI.
2. **Drop to a real shell** — a live PTY in the repo/project directory, because the moment a user needs `claude-vault set` or an interactive `psql`, the GUI must get out of the way rather than build a worse version of it.

The PTY is the one genuinely non-trivial piece (`forkpty`, resize, ANSI). If it threatens the schedule, ship U4.1 (echo-only, a log view) and defer the live shell — the rest of the GUI does not depend on it.

### U5. Secrets stay out of the GUI — **P0, non-negotiable**
`claude-vault list` metadata (name, type, rotation age, description) renders; **values never do**. No "reveal" button, no clipboard button that pulls a value through the GUI process. Password-type entries are deliberately terminal-only today, and a GUI that quietly relaxes that has undone the reason the vault exists. Actions that need a value (`set`, `test`, `exec`) hand off to the terminal pane. Same rule for `db-conn`: query *results* may render, connection details may not.

### U6. Build shape — **P2, decision needed**
Not settled. SwiftUI is the honest default for a Mac-only, filesystem-and-subprocess app: native file tree, no runtime to ship, real PTY access via `Process`/`forkpty`. The cost is that the toolkit becomes bilingual — nine Python/zsh tools plus a Swift app — and the GUI cannot be maintained from the same session that maintains the tools without a context switch. The alternative, a local web UI (Python server + browser), keeps one language and gets markdown rendering nearly free, but a browser tab is a worse home for a terminal and for a persistent window. **Decide before U2; it is not reversible cheaply.**

### U7. Non-goals for v1 — **P0, scoping**
No editing of code or config from the GUI. No vault writes. No MCP server toggling that the GUI cannot show the diff for (`claude-toggle` mutates `.claude.json`; doing that behind a button with no preview is how S8-style silent breakage happens). No bundling/notarization/distribution — this is a personal tool until it is not.

## Cross-cutting

### G1. ~~`toolkit doctor` / install script~~ — **done 2026-07-27** (new `toolkit` CLI: install relinks all 9 tools; doctor checks links/versions/PATH/launchd/directives/index age/vault and exits non-zero. First run caught two real faults: `atl` was never on PATH and `db-conn` had no --version)
S10 (all symlinks dead for days) needs a guard: an `install.sh` that (re)links every tool into `~/.local/bin`, plus a `doctor` that checks each symlink resolves, each tool runs `--version`, the launchd agents are loaded, and the directive blocks match source (T9). One command after any repo move.

### G2. Index-family consistency — **P2, small**
`cindex`/`dbindex`/`csession` share conventions (`~/.claude/<x>-index/`, `indexes/`+`logs/`, mtime-incremental, `--limit/--json`, capped compact output). Extract the shared helpers (log-rotate, score/rank, arg parsing) into a small common module vendored into each tool — they've already drifted slightly (score lives in three files).

### G3. ~~Commit the suite~~ — **done 2026-07-27** (pushed to github.com/hardyalsinghdeora/claude-toolkit)
The four new tools, automation/, and the doc updates are uncommitted (`git status` shows them untracked). Commit as the "token-optimization suite" milestone.

### G4. ~~`toolkit agents` — one control surface for the launchd jobs~~ — **done 2026-07-28** (toolkit 1.1.0; `list/status`, `install`, `run`, `stop`, `pause`, `resume`, `logs`, `every`. Pause state in `~/.claude/toolkit-agents.json`; `doctor` now reports a recorded pause as ok-with-reason instead of a false fault)

Today `toolkit doctor` only *reports* whether an agent is loaded; every actual operation is a hand-typed `launchctl` incantation, and the modern (`bootstrap`/`bootout`/`kickstart`) and legacy (`load`/`unload`/`start`) spellings are mixed across `docs/launch-agent.md` and muscle memory. Two jobs run off this repo — `cindex-refresh` (daily 09:00) and `worklog` (daily 21:15), both local-only and token-free.

Neither is expensive, so the case for the command is not cost, it is **legibility**: pause is a two-command sequence that is easy to get half-right, and a half-right pause is indistinguishable from a broken install (S15).

`toolkit agents <verb>`, wrapping the correct `gui/$(id -u)` domain calls:

| Verb | Does | Wraps |
|---|---|---|
| `list` / `status` | table: loaded? enabled? next run, `runs`, `last exit code`, log mtime, paused-since | `launchctl print` + `print-disabled` |
| `run <label>` | fire one tick now, tail the log | `kickstart -k gui/$(id -u)/<label>` |
| `pause <label> [--until 18:00\|--for 4h]` | stop the schedule *and* record why/when in `~/.claude/toolkit-agents.json` | `bootout` **+** `disable` |
| `resume <label>` | undo the above without a surprise `RunAtLoad` tick | `enable` **+** `bootstrap`, then re-arm |
| `stop <label>` | kill the *currently running* tick, leave the schedule intact | `kill TERM gui/$(id -u)/<label>` |
| `logs <label> [-f]` | tail the right file (they do not live in one place) | — |
| `every <label> <spec>` | re-render the schedule (`daily 09:00`, `hourly 9-18`, `30m`) and reload | rewrite plist + `bootout`/`bootstrap` |

Design notes worth encoding, because each is a mistake already made or narrowly avoided:
- **`disable` alone does not stop a loaded job**, and `bootout` alone does not survive login. Only the *pair* is a real pause — this is the single biggest reason to have the command.
- **Pause needs state.** Without the `paused-since / reason / until` record, S15 recurs: `doctor` shows WARN "not loaded" and nobody can tell deliberate from broken. `doctor` should read that file and print `paused (2026-07-28, hung run) — resume with 'toolkit agents resume <label>'` instead of a false alarm.
- **`RunAtLoad` + `bootstrap` = an unintended immediate run.** `resume` should either strip `RunAtLoad` for the reload or say plainly that a tick is about to fire.
- **`--until`** can't rely on launchd alone; the cheapest honest implementation is for `resume` to be checked opportunistically (on the next `toolkit doctor` / `agents list`), not to promise a wake-up.

### G5. ~~Versioned plist templates + `toolkit agents install`~~ — **done 2026-07-28** (`automation/launchd/agents.json` is the source of truth; plists are rendered with `plistlib` from `{{REPO}}`/`{{HOME}}` substitutions, and drift from the manifest is reported by both `agents list` and `doctor`)

The plists are untracked one-offs in `~/Library/LaunchAgents/` (S16), and launchd does not expand `~` or `$HOME` inside a plist, so every one of them hardcodes an absolute path that a repo move invalidates. Add `automation/launchd/*.plist.tmpl` with `{{REPO}}`/`{{HOME}}`/`{{SCHEDULE}}` placeholders, and `toolkit agents install [<label>] [--dry-run]` that renders and bootstraps them — the same idempotent contract `toolkit install` already has for the 9 symlinks. Then a repo move is one command (`toolkit install && toolkit agents install`) instead of hand-edited XML, and `doctor` can diff live plist vs template and flag drift. Pairs with G1.

_(G6, a watchdog for headless `claude -p` agents, was dropped on 2026-07-28 when the pr-dashboard automation was removed from the repo — no scheduled job now runs a model. The requirement survives as a Gotcha in `docs/launch-agent.md`: launchd has no per-job timeout, so any future job that calls a model or the network needs its own `timeout` plus a lockfile in the wrapper.)_

---

## Suggested order of work

**Phase 1 — safety & correctness: ✅ done 2026-07-17** — V1, V2, V3, T1, T2, C2, C3 (claude-vault 1.1.0, claude-toggle 1.2.0)
Everything here is small, and each item prevented or would have prevented a real incident from this week.

**Interlude — team credentials (✅ done 2026-07-17, claude-vault 1.2.0):** password-type entries (never displayed on a terminal; `--copy` for clipboard), DB config split from per-member password entries (`<config>.<dbuser>[.ro|.rw]`, resolved by `core-db --user/--role`), and optional per-entry PIN lock (`pin enable/disable`, PBKDF2+HMAC encrypted at rest, off by default).

**Phase 2 — trust the vault: ✅ done 2026-07-27** — V4, V6, V7, V9, T3, T4, C4 (claude-vault 1.3.0, claude-toggle 1.5.0, db-conn write guard)
After this, credentials are verifiable, importable without chat-pasting, and injectable without shell substitution.

**Phase 3 — polish & reach: ✅ done 2026-07-27** — V5, V8, V10 (minus Touch-ID), T5, T6, C5 (claude-vault 1.4.0, claude-toggle 1.6.0, db-conn output modes). V11/T7/T8 remain deliberately unbuilt — no concrete need yet.

**Phase 4 — token-optimization suite hardening: ✅ core done 2026-07-27** — G1, G3, A1, A2, A3, T9, T10, X1, X2, D1, N1, N3, Q1 (new `toolkit` CLI; claude-toggle 1.7.0, cindex 1.4.0, dbindex 1.1.0, csession 1.1.0, squeeze 1.1.0, atl 1.1.0, db-conn 1.2.0).
Still open, deliberately (no friction yet): G2 shared helpers, A4 Bitbucket `bbt` + K2, A5 backoff, K1 skill dedup, Q2 profiles, X3/X4, D2/D3/D4, N2/N4, T11.

**Phase 5 — scheduled-agent control: ✅ done 2026-07-28** — G4, G5 (toolkit 1.1.0). G6 was dropped with the pr-dashboard removal.
S15 and S16 are both closed: a pause now records *why* and reads as `ok` in `doctor`, and the plists are rendered from a tracked manifest rather than hand-edited in `~/Library/LaunchAgents/`.

Two deviations from the plan as written, both deliberate:
- **Manifest, not `.plist.tmpl` templates.** `automation/launchd/agents.json` holds structured agent definitions and `plistlib` renders the XML. String templates cannot support `agents every` — retiming needs structured schedule data, not text substitution — and `plistlib` output is valid by construction.
- **`--until` is opportunistic, as designed.** launchd cannot wake a job to un-pause it, so expiry is checked whenever `agents list` or `doctor` runs. A pause that expires while nothing looks at it stays paused until something does; the alternative would be a watchdog agent to supervise the agents.

**Phase 6 — `toolkit-gui`, a macOS front end (opened 2026-07-28, not started):** U1–U7.
Order: **U6 first** (SwiftUI vs local web UI — the one irreversible call), then U1 shell-out contract, U2 tools + directory listing, U3 markdown view, U4 terminal view. U5 and U7 are constraints that apply throughout, not steps. **G2 is a prerequisite** — a uniform `--json` shape across the index family is what keeps U1 from becoming nine bespoke output parsers, so G2 graduates from "P2, when friction appears" to blocking work.

**Hygiene — public-repo scrub (2026-07-28):** the pr-dashboard automation was deleted from the repo and the hardcoded tenant/email/username removed (S17). The **git history still contains them** in commits `1af84b3`..`5a8eb78`, already pushed to `origin` and possibly to the `private-old` remote — a history rewrite + force-push is the outstanding half, and needs an explicit decision because it invalidates every existing clone.

Original order of work:
1. **G3 commit the suite** (still pending — now also covers atl, skills, ignore files, docs) + **G1 doctor/install** — S10 must not happen again; everything else builds on a healthy install.
2. **A1 validate version/create** + **A2 identity guard** — atl is now on the critical path of four skills; close its two known gaps first.
3. **T9 directive refresh**, **X1 cross-project search**, **D1 staleness hint**, **N1 outcome-aware briefs** — the four highest-leverage gaps in the index suite.
4. Then K1 (skill dedup), A4+K2 (Bitbucket offline pair), T10, Q1/Q2, X2+N3 (ticket linking pair), D2/D3, N2 — as friction actually appears in sessions.

## Non-goals (for now)

- Syncing secrets between machines or to any cloud — the whole point is local-only Keychain storage.
- ~~A GUI~~ — reversed 2026-07-28: a **read-only macOS front end** is now Phase 6 (`toolkit-gui`, U1–U7). The non-goal it replaces still holds in spirit: the CLIs stay the source of truth and the GUI shells out to them, so this is a viewer over an AI-session-first toolkit, not a second way to drive it.
- Replacing 1Password/real secret managers — this is a personal automation bridge, not a team product.
- Cross-platform anything (see V11). The GUI is macOS-only by the same logic.
