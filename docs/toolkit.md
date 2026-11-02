# toolkit — install, health-check, and scheduled agents

**Version 1.1.0** · `toolkit`

One command to (re)link every tool into `~/.local/bin`, one to verify the whole install is actually working, and one to control the launchd jobs this repo installs.

## Why it exists

The repo moved from `~/Desktop` to `~/Workspace` and every `~/.local/bin` symlink silently broke. `claude-vault` and `db-conn` were dead on PATH **for days** before anyone noticed — discovered by accident, not by a failure. Nothing in the system knew it was broken, because a broken symlink is only detected when someone runs the command.

`toolkit doctor` makes that detectable in one command, and its first run immediately paid for itself: `atl` had never been on PATH at all, and `db-conn` had no `--version` to check.

## Usage

```sh
toolkit install [--bin DIR]   # (re)link every tool into ~/.local/bin
                              #   (Windows: writes .cmd + Git Bash shims instead)
toolkit doctor                # verify the whole install
toolkit list                  # the tools this repo provides
toolkit agents <verb>         # control the launchd jobs — see below
```

`doctor` **exits non-zero** when something is broken, so it can gate automation.

## toolkit agents

```sh
toolkit agents list|status                # state, schedule, runs, last exit, log age
toolkit agents install [name] [--dry-run] # render from the manifest and (re)bootstrap
toolkit agents run <name>                 # fire one tick now
toolkit agents stop <name>                # kill the RUNNING tick; schedule stays armed
toolkit agents pause <name> [--reason "..."] [--until HH:MM | --for 4h]
toolkit agents resume <name>
toolkit agents logs <name> [-n N] [-f]
toolkit agents every <name> <spec>        # 'daily 09:00' | 'hourly 9-18' | '30m'
```

`<name>` is the short name (`worklog`) or the full label.

```
LABEL                       STATE    SCHEDULE     RUNS    LAST    LOG
com.<you>.cindex-refresh    armed    daily 09:00  2 runs  exit 0  25h ago
com.<you>.worklog           armed    daily 21:15  3 runs  exit 0  0h ago
```

**Why this exists rather than a documented `launchctl` recipe.** Two of launchd's behaviours are easy to get half-right, and half-right is worse than wrong because it looks like it worked:

- `bootout` unloads now but **does not survive login**; `disable` persists but **does not stop a loaded job**. A real pause is both, in that order, and `pause` does both.
- An unrecorded pause is indistinguishable from a rotted install. `pause` writes the reason and timestamp to `~/.claude/toolkit-agents.json`, and `doctor` reports it as `ok` — `paused 2026-07-28 (reason) — 'toolkit agents resume worklog'` — instead of a false alarm.

`resume` runs `enable` before `bootstrap`, because bootstrapping a disabled label silently does nothing. It also tells you when `RunAtLoad` means a run just fired.

**Stop versus pause** is the distinction the raw commands blur: `stop` kills the tick that is running right now and leaves the schedule armed; `pause` stops future ticks and leaves any current one alone.

### The manifest

`automation/launchd/agents.json` is the source of truth for what agents exist. `agents install` renders each entry to a plist with `plistlib` and bootstraps it, substituting `{{REPO}}` and `{{HOME}}` — launchd does not expand `~` or `$HOME` inside a plist, which is exactly why a repo move used to break them with nothing to re-render from.

Schedules are structured, not text:

```json
{"type": "daily",    "hour": 9, "minute": 0}
{"type": "hourly",   "from": 9, "to": 18, "minute": 0}
{"type": "interval", "seconds": 1800}
```

Both `agents list` and `doctor` compare each installed plist against what the manifest would render and report **drift**. `agents every` edits the installed plist directly for a quick change and says so — update the manifest too, or the next `install` reverts it.

`--dry-run` prints the rendered XML without writing or bootstrapping anything.

## What doctor checks

| Check | Detects |
|---|---|
| tools | missing from repo, not installed, broken symlink, links elsewhere, `--version` fails |
| launchd agents | plists referencing this repo: script missing, agent not loaded |
| directives | each of the four: disabled, or enabled with **outdated** text |
| indexes | cindex/dbindex/csession presence, size, age of newest |
| vault | runs `claude-vault doctor` — Keychain vs index agreement, JSON parse |
| PATH | whether the bin directory is actually on PATH |

Sample tail:

```
launchd agents:
[  ok  ] com.<you>.cindex-refresh  loaded
[  ok  ] com.<you>.worklog         loaded

vault:
[  ok  ] vault  doctor: Keychain and index agree (14 entries), all JSON entries parse.

PATH: contains /Users/<you>/.local/bin
```

## Design decisions worth knowing

**Install is idempotent.** Already-correct symlinks are reported and skipped; wrong ones are replaced; the source file gets its executable bit set. Running it twice is safe and running it after any repo move is the fix.

**Windows gets shims, not symlinks.** Symlinks need admin or Developer Mode there, and
neither cmd nor PowerShell honours a shebang. So each tool gets `<tool>.cmd` and an
extensionless sh launcher for Git Bash, both exec'ing the interpreter named by the
script's shebang (this Python, or bash). `doctor` flags a shim whose contents no longer
match — e.g. after a repo move or a Python upgrade — as stale.

**Doctor reports, it does not repair.** Each failure line names the command that would fix it (`run 'toolkit install'`, `claude-toggle <name> refresh`, `launchctl bootstrap ...`). Automatic repair of a launchd agent or a directive block is a bigger action than a health check should take on its own.

**Agent discovery is by content, not by name.** `doctor` scans `~/Library/LaunchAgents/*.plist` for any plist referencing this repo's path, so an agent you add by hand is checked without registering it anywhere.

## Gotchas

- **`toolkit install` does not create launchd agents** — that is `toolkit agents install`, deliberately separate: relinking binaries is harmless, while bootstrapping an agent starts running things.
- **MCP server commands are not checked.** Doctor validates this repo's own symlinks; an MCP server in `~/.claude.json` pointing at a moved script still reads as `enabled` and simply fails at session start.
- **`--until` is checked opportunistically**, not by a timer. launchd cannot wake a job to un-pause it, so an expired pause is lifted the next time `agents list` or `doctor` runs. If nothing looks, it stays paused.
- **`agents every` edits the installed plist, not the manifest.** The next `agents install` reverts it. The command says so each time.
- **Directive checks require `claude-toggle` to be installed** — otherwise that section warns rather than failing.

## Related

`docs/launch-agent.md` (managing the agents doctor reports on) · `claude-toggle` (directive freshness) · `claude-vault doctor` (the vault section)
