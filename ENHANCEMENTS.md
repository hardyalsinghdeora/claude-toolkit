# Enhancement Plan — claude-vault, claude-toggle, core-db

_Drafted 2026-07-17. Grounded in the current source (`claude-vault` v1.0.0, `claude-toggle` v1.1.0, `core-db`) and in real friction hit during actual sessions._

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

---

## claude-vault

### V1. First-class non-interactive `set` — **P0, small**
Today stdin piping works by accident of `sys.stdin.isatty()`. Make it official:
`claude-vault set <name> --stdin`, plus `--from-clipboard` (reads `pbpaste`, offers to clear the clipboard after). Document both in help. Never accept the value as an argv argument (would leak into shell history / `ps`).

### V2. `rename` command — **P0, small**
`claude-vault rename <old> <new>`: copy Keychain item, update index, delete old — atomic from the user's view. (S3 did this by hand.)

### V3. Update a single JSON field — **P0, small**
`claude-vault set <name> --field password` prompts for just that field, merges into the existing JSON. Avoids the rebuild-whole-blob dance of S4 and avoids re-pasting fields that were already correct.

### V4. `doctor` — reconcile Keychain vs index — **P1, medium**
Scan the Keychain for `claude-vault.*` service items and diff against `vault-index.json`:
- item in Keychain but not index → offer to adopt (S2)
- index entry with no Keychain item → offer to prune
- JSON-typed entries that fail `json.loads` → flag
Run automatically (cheap check) at the top of `list`.

### V5. Rotation metadata + staleness warnings — **P2, small**
Optional `--rotate-days N` on `set`; `list` and `get` print a warning once an entry is older than its rotation window. Would have surfaced S1 before the failed logins.

### V6. `test <name>` — live credential check — **P1, medium**
For JSON secrets that look like DB credentials (have host/user/password), attempt a real connection (`psql`/`mysql` picked by port or a `type` field) and report ok/auth-failed/unreachable. Distinguishes "wrong password" from "VPN off" — exactly the S1 vs S7 ambiguity. `--all` flag to health-check the whole vault.

### V7. Import from `.env` / bulk add — **P1, medium**
`claude-vault import <file|-> --name core-db --map POSTGRES_HOST=host,POSTGRES_USER=user,POSTGRES_PASSWORD=password` (with sane defaults for the common `POSTGRES_*`/`DB_*`/`MYSQL_*` prefixes). Kills the paste-secrets-into-chat pattern of S6.

### V8. Reference tracking / rename safety — **P2, small**
`rename` and `delete` grep known consumer scripts (start with this repo, configurable list) for the entry name and warn: "`core-db` references `prod-code-db`". Prevents S8-style silent breakage.

### V9. `exec` — inject secrets as env vars — **P1, medium**
`claude-vault exec <name> [--prefix PG] -- psql -h ...` runs a child process with fields exported (`PGHOST/PGUSER/PGPASSWORD` mapping built in). The secret never transits the parent shell, command line, or transcript at all — stronger than `$(claude-vault get ...)` substitution.

### V10. Quality-of-life — **P2, small each**
- `list --json` (machine-readable, for tooling and AI sessions)
- `desc <name> "text"` — edit description without re-entering the secret
- `get <name> --copy [--clear 30]` — clipboard with auto-clear
- shell completion for entry names
- optional Touch-ID gating via Keychain ACL (`security add-generic-password -T ""` + user-presence) for high-value entries

### V11. Cross-platform backend — **P3, large**
Abstract `kc_set/kc_get/kc_delete` behind a backend interface: macOS `security` (current), Linux `secret-tool`, Windows Credential Manager. Only worth it if the tool is shared beyond this Mac (relevant if it ever ships alongside the PR-review product).

---

## claude-toggle

### T1. Backup retention — **P0, small**
`~/.claude/backups/` grows without bound (one file per mutation, forever). Add `claude-toggle backups prune [--keep 20]` and auto-prune to the newest N after each backup.

### T2. Profile load is destructive to settings.json — **P0, small**
`profile load` **replaces** `settings.json` wholesale with whatever was snapshotted, silently dropping anything added since the snapshot (permissions, hooks…). Fix: back up `settings.json` too (today only `.claude.json` is backed up), and add `--mcp-only` / `--settings-only` flags; make `--mcp-only` the default and full overwrite opt-in.

### T3. `status` / `diff` — **P1, medium**
- `claude-toggle diff <profile>` — what would change if this profile were loaded
- `claude-toggle status` — current enabled/disabled summary + which profile (if any) it matches
Removes the guess-and-check around "which profile am I on?"

### T4. Server groups — **P1, small**
Named sets in a small config file (e.g. `browser = claude-in-chrome`, `work = atlassian, zoho`): `claude-toggle disable @work`. Cheaper than full profiles when you just want to shed a category.

### T5. `doctor` — consistency checks — **P2, small**
Detect: same server present in both `.claude.json` and the stash (double-entry after a manual edit), stashed entries for project paths that no longer exist, malformed stash. Offer fixes.

### T6. Selective restore — **P2, small**
`restore` currently swaps the entire `.claude.json` (which also holds session state, history, OAuth). Add `--mcp-only` to graft only the `mcpServers` scopes out of the backup, leaving the rest of the live file untouched.

### T7. Per-project auto-profile via hooks — **P3, medium**
A SessionStart hook that applies a named profile based on the project directory (mapping in the profile file). Needs care re: the "changes apply to new sessions only" model — evaluate before building.

### T8. Track native disable support — **P3, watch**
If Claude Code grows a first-class `disabledMcpServers` field, migrate from the move-to-stash model to flipping that flag; keeps `claude /config` and other tools consistent with toggle state.

---

## core-db

### C1. ~~Fix stale vault references~~ — **done 2026-07-17**
Now reads `prod-core-db`; the `prod-core-pass` fallback is removed.

### C2. Fail fast with a VPN hint — **P0, small**
Before running psql, probe the host (`nc -z -G 3 $HOST $PORT`). On failure print: `cannot reach $HOST:$PORT — if this is the prod/stg RDS (private IP), connect to the VPN first.` Turns S7's silent multi-minute hang into an instant, actionable error.

### C3. Multi-environment support — **P0, small**
`core-db --env prod|stg|test|local ...` (default `prod`) selecting the `<env>-core-db` vault entry. All four entries already exist with identical shape, so this is just string substitution.

### C4. Prod write guard — **P1, small**
Default to blocking statements matching `INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE` when `--env prod`, unless `--write` is passed. A one-line regex gate that makes the common case (read-only lookups for support requests, like the mse.xlsx task) safe by construction.

### C5. Convenience output modes — **P2, small**
`--xlsx <file>` / `--md` output via a tiny Python helper, since query results regularly end up in Excel deliverables anyway.

---

## Suggested order of work

**Phase 1 — safety & correctness: ✅ done 2026-07-17** — V1, V2, V3, T1, T2, C2, C3 (claude-vault 1.1.0, claude-toggle 1.2.0)
Everything here is small, and each item prevented or would have prevented a real incident from this week.

**Interlude — team credentials (✅ done 2026-07-17, claude-vault 1.2.0):** password-type entries (never displayed on a terminal; `--copy` for clipboard), DB config split from per-member password entries (`<config>.<dbuser>[.ro|.rw]`, resolved by `core-db --user/--role`), and optional per-entry PIN lock (`pin enable/disable`, PBKDF2+HMAC encrypted at rest, off by default).

**Phase 2 — trust the vault (a weekend):** V4, V6, V7, V9, T3, T4, C4
After this, credentials are verifiable, importable without chat-pasting, and injectable without shell substitution.

**Phase 3 — polish & reach (as needed):** V5, V8, V10, T5, T6, C5, then V11/T7/T8 only if a concrete need appears.

## Non-goals (for now)

- Syncing secrets between machines or to any cloud — the whole point is local-only Keychain storage.
- A GUI — these are AI-session-first CLI tools.
- Replacing 1Password/real secret managers — this is a personal automation bridge, not a team product.
