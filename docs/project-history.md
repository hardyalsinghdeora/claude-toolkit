# Project history — what has been built, and why

A record of the work in this repo in the order it happened. Every item below started as a real failure or a real cost; the scenario table in `../ENHANCEMENTS.md` (S1–S17) is the index of those, and this page is the narrative.

## Timeline

| Date | Commit | What landed |
|---|---|---|
| 2026-07-17 | `0e2e4ab` | Phase 1 safety fixes + team credentials (vault 1.2.0, toggle 1.2.0) |
| 2026-07-17 | `f7067c4` | Vault entries renamed `<env>-core-db` → `<env>-postgres-db` |
| 2026-07-17 | `93faad4` | `core-db` replaced by `db-conn` — engine-agnostic (Postgres + MySQL) |
| 2026-07-18 | `66b962f` | Prep for public release as `claude-toolkit`; examples genericized |
| 2026-07-27 | `1af84b3` | **Token-optimization suite**: squeeze, cindex, dbindex, csession, atl, directives |
| 2026-07-27 | `2db5cb3` | `Output/` and `Skill/` reference structure |
| 2026-07-27 | `d619f9f` | `worklog` — zero-token daily logs, reports, skill, automation |
| 2026-07-27 | `92fcf3f`, `08520cd` | README: sanitized examples, local-only directories policy |
| 2026-07-27 | `7fa6942` | Phase 2 "trust the vault" — V4 V6 V7 V9 T3 T4 C4 |
| 2026-07-27 | `9bc0794` | Phase 3 "polish & reach" — V5 V8 V10 T5 T6 C5 |
| 2026-07-27 | `5a8eb78` | Phase 4 hardening — `toolkit` CLI, atl guards, cross-project search, outcome briefs |
| 2026-07-28 | `1d9a649` | Public-repo scrub; pr-dashboard automation removed |

## Phase 1 — safety & correctness (2026-07-17)

The starting point was two tools, `claude-vault` and `claude-toggle`, plus a hardcoded `core-db` script. A week of real use produced a list of small, sharp problems, each of which had already cost time:

- Setting a secret non-interactively worked only *by accident* of an `isatty()` check, discovered by trial and error → **`--stdin`**, `--from-clipboard`, and a documented contract that the value is never an argv argument (it would land in shell history and `ps`).
- Renaming an entry meant get + set + delete by hand → **`rename`**.
- Changing one field of a JSON secret meant rebuilding the whole blob in Python → **`set --field`**.
- `claude-toggle profile load` **replaced `settings.json` wholesale**, silently dropping permissions and hooks added since the snapshot → MCP-only by default, settings overwrite opt-in.
- `~/.claude/backups/` grew without bound → **`backups prune`**.
- A private RDS endpoint with the VPN down did not fail, it *hung* → **`nc -z -G 3` probe** with a named cause.

**Interlude — team credentials.** The same day brought the pattern that still shapes the vault: password-type entries that are *never* displayed on a terminal, DB config split from per-member passwords (`<config>.<dbuser>[.ro|.rw]`), and optional per-entry PIN locking (PBKDF2-HMAC-SHA256, 200k iterations). Config can be shared; credentials never are.

`core-db` → `db-conn` followed: engine-agnostic, multi-environment, resolving credentials by entry name.

## Phase 2–3 — trust the vault (2026-07-27)

A credential store you cannot verify is a credential store you will eventually not trust. Two incidents drove this: a stale prod password caused three failed logins before the right value was pasted by hand, and a vault entry that `get` could read but `list` could not show — the Keychain and the index had drifted apart.

- **`doctor [--fix]`** diffs Keychain against index in both directions, adopting or pruning.
- **`test <name>` / `--all`** attempts a real connection and reports `ok` / `AUTH FAILED` / `UNREACHABLE`, which is the only way to tell "wrong password" from "VPN off" — the exact ambiguity that had wasted the debugging time.
- **`import`** reads `.env` files directly, killing the habit of pasting credential blocks into chat to get them into the vault.
- **`exec`** runs a child with fields as environment variables via `os.execvpe`, so the value never transits the shell or the transcript at all.
- **Rotation windows**, **reference tracking** on rename/delete, `list --json`, `desc`, clipboard auto-clear.

`claude-toggle` gained `status`, `diff`, server groups, `doctor` and selective restore; `db-conn` gained the prod write guard and markdown/xlsx output.

**Deliberately not built:** Touch-ID ACL gating (re-adding items with `-T ""` risks locking existing entries) and a cross-platform backend (no second machine yet).

## The token-optimization suite (2026-07-27)

The largest single change. Four new tools built around one observation: **context is re-sent with every request**, so a verbose command is paid for many times, and the cheapest token is the one never emitted.

- **`squeeze`** — caps and elides command output, preserving error lines so compression can never hide a failure.
- **`cindex`** — per-project symbol index; `path:line kind name` instead of a grep dump. `.claudeignore` support cut this repo's indexed set from 122 files to 18.
- **`dbindex`** — offline schema index, so "which table holds X" needs no VPN and no query.
- **`csession`** — index of past sessions, with briefs that pair each prompt with its outcome, and a `suggest` command encoding the real cost of resuming (replaying a transcript) versus starting fresh with a digest.
- **`atl`** — offline Jira/Confluence fetcher, replacing MCP round-trips with compact TSV.
- **The directive system** — marker-delimited blocks in `~/.claude/CLAUDE.md` teaching sessions to use all of the above, compressed to ~28 lines because the instruction itself costs context every request.

`worklog` followed the same principle to its conclusion: it combines the session index and git history into a daily log **at zero token cost**, because neither input needs a model.

## Phase 4 — hardening (2026-07-27)

New tools are unproven tools. This phase closed the gaps that use had exposed:

- **`toolkit` CLI** — after the repo moved from `~/Desktop` to `~/Workspace`, every `~/.local/bin` symlink broke and two tools were dead on PATH **for days**, found by accident. `toolkit install` relinks; `toolkit doctor` verifies links, versions, PATH, launchd agents, directive freshness, index age and vault health, and exits non-zero. Its first run found two more real faults: `atl` had never been on PATH, and `db-conn` had no `--version`.
- **`atl` identity guard** — Jira answers unauthenticated JQL with **HTTP 200 and zero issues**, so a revoked token looks like "working, nothing to show". Every empty result is now proven via `/myself`.
- **Gateway fallback** — scoped Atlassian tokens 401 against the site URL and work only via `api.atlassian.com/ex/<product>/<cloudId>`, and are product-scoped, so a Jira token cannot read Confluence. Path-aware token selection plus a cached gateway mode.
- **Directive refresh** — directive text lives in the tool, so improving the wording never reached an already-enabled block; `refresh` and an `OUTDATED` marker in `directives`/`status`/`doctor` fixed a problem that had needed four manual off/on cycles.
- Cross-project search, ticket-id extraction from branches, schema staleness warnings, outcome-aware briefs, automatic JSON detection in squeeze.

## Public-repo hygiene (2026-07-28)

The repo is public, and a scan found deployment-specific data that had been pushed across eight commits: the employer's Jira tenant URL and a work email hardcoded in `atl`, an internal MCP gateway name in the launchd doc, an Apidog project id, a Bitbucket workspace and reviewer name in the cron doc, and the author's `$HOME` hardcoded in `csession`.

All of it now resolves from `~/.claude/atl-config.json`, environment variables, or `Path.home()`. **No credential was ever committed** — every commit was scanned for token-shaped strings and came back clean.

The **pr-dashboard automation was removed** rather than scrubbed: work-specific, the only scheduled job that spent tokens, and already booted out after a tick hung 91 minutes producing nothing.

> **Outstanding:** the tenant URL and email remain in git history (`1af84b3`..`5a8eb78`), already pushed. Removing them requires a history rewrite and force push, which invalidates every clone — an explicit decision, not yet taken.

## What is next

`../ENHANCEMENTS.md` holds the full plan. In short:

- **Phase 5** — `toolkit agents`: a control surface for the launchd jobs (status, manual run, stop-the-run vs pause-the-schedule, resume, retiming), then versioned plist templates.
- **Phase 6** — `toolkit-gui`: a read-only macOS front end with a tools list, directory listing, markdown view and terminal pane, shelling out to these CLIs rather than reimplementing them.
- **K1**, the highest-priority open item: skills exist in two places and have already drifted.

## The through-line

Every tool here exists because something failed quietly. A broken symlink that nothing detected. A credential store whose two halves disagreed. A Jira query that returned success and nothing. A scheduled job that hung for 91 minutes with no output. The recurring lesson is not "add a feature" but **make the failure visible**: `doctor` commands that exit non-zero, `test` that names the cause, identity guards that prove an empty result, and staleness warnings that name the command to run.
