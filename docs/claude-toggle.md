# claude-toggle — MCP servers, config profiles, CLAUDE.md directives

**Version 1.7.0** · `claude-toggle`

Three related jobs, all about controlling what Claude Code loads: enable/disable **MCP servers**, snapshot and restore **config profiles**, and toggle the **directive blocks** in `~/.claude/CLAUDE.md` that teach sessions to use the rest of this toolkit.

## Why it exists

Every enabled MCP server costs context in every session — its tool schemas are loaded whether or not you use them. Disabling one by hand means editing `~/.claude.json`, which also holds session state, history and OAuth tokens, so a botched edit is expensive. `claude-toggle` makes the operation lossless and reversible: a disabled server's config is *moved* to a stash file, not deleted, and every mutation writes a timestamped backup first.

## Storage

| Where | What |
|---|---|
| `~/.claude.json` | live config: global `mcpServers` + per-project `projects.<path>.mcpServers` |
| `~/.claude/mcp-disabled.json` | the stash — configs of disabled servers, restorable verbatim |
| `~/.claude/toggle-groups.json` | named server sets (`@work`, `@browser`) |
| `~/.claude/backups/` | timestamped `~/.claude.json` and `CLAUDE.md` backups, pruned to the newest N |
| `~/.claude/CLAUDE.md` | directive blocks, delimited by markers |

## Commands

```sh
claude-toggle list                     # every server, scope, status, endpoint
claude-toggle status                   # summary + matching profile + directive states
claude-toggle disable <server>|@group|--all [--project <path>|--global]
claude-toggle enable  <server>|@group|--all [--project <path>|--global]

claude-toggle group set <name> <server>...   # named sets
claude-toggle group list | delete <name>

claude-toggle profile save <name>            # snapshot MCP config + settings.json
claude-toggle profile load <name> [--all|--settings-only]
claude-toggle profile list
claude-toggle diff <profile>                 # what loading it would change

claude-toggle squeeze|cindex|dbindex|csession on|off|status
claude-toggle <directive> refresh            # re-apply current block text
claude-toggle directives [refresh]           # all four: off / current / outdated

claude-toggle doctor [--fix]
claude-toggle backups [prune [--keep N]]
claude-toggle restore [latest|<file>] [--mcp-only]
```

## Scopes

MCP servers exist at three levels, and the same server can appear at more than one:

- **global** — `mcpServers` at the top of `~/.claude.json`
- **per-project** — `projects.<path>.mcpServers`, one block per directory
- **stashed** — moved aside by `claude-toggle disable`

With neither `--project` nor `--global`, enable/disable acts on **every scope where the server is found**. This is usually what you want and occasionally surprising: a server can read as "enabled" at `~` while being explicitly disabled under `~/Workspace`, which means it is off in every project you actually work in. `claude-toggle list` shows the scope column for exactly this reason.

## The directive system

Four of this toolkit's tools only pay off if sessions *know to use them*. The directive system writes a short marker-delimited block into `~/.claude/CLAUDE.md` — the file loaded into every session — teaching Claude to reach for `squeeze`, `cindex`, `dbindex` and `csession` at the right moments. The blocks are compressed to roughly 28 lines total, because the instruction itself costs context on every request.

**Directive text is versioned in the tool, not in `CLAUDE.md`.** Improving the wording in a newer `claude-toggle` does not reach an already-enabled block — a real problem when a wording change needed four manual off/on cycles. `<directive> refresh` re-applies the current text between the markers, `directives` lists all four as *disabled / enabled+current / enabled+**OUTDATED***, and `status` flags drift. `toolkit doctor` surfaces the same signal.

## Design decisions worth knowing

**`profile load` defaults to MCP-only.** It used to replace `settings.json` wholesale, silently dropping any permissions or hooks added since the snapshot. Now MCP config is the default and overwriting settings is opt-in (`--all` / `--settings-only`), and `settings.json` is backed up alongside `.claude.json`.

**`restore --mcp-only` grafts, it doesn't swap.** A full `.claude.json` restore also rolls back session state, history and OAuth — usually not what you want when you only meant to undo a server change. `--mcp-only` lifts just the `mcpServers` scopes out of the backup and leaves the rest of the live file alone.

**Backups are pruned automatically.** One file per mutation, forever, was the original behaviour. `backups prune [--keep N]` (default 20) runs after each backup.

**`doctor` catches the states hand-editing produces**: the same server present in both the live file *and* the stash (double entry), stashed scopes for project paths that no longer exist, and malformed stash JSON. `--fix` resolves them.

## Gotchas

- **Changes apply to NEW sessions only.** The running session keeps whatever it loaded at start. This is the single most common source of "it didn't work".
- **Endpoints can contain secrets.** Some MCP server URLs embed a per-install token in the path, and `claude-toggle list` prints endpoints in full — don't paste that output anywhere public.
- **Nothing validates that a server path still exists.** A stdio server pointing at a moved script reads as `enabled` and simply fails at session start; `toolkit doctor` checks the toolkit's own symlinks but not MCP server commands.
- **`--all` really means all**, across every scope. Use a group or an explicit `--project` when you mean something narrower.

## Related

`toolkit doctor` (reports directive freshness) · `docs/token-optimization.md` (what the directives buy you)
