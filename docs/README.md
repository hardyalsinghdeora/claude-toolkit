# claude-toolkit documentation

Per-module reference. `../README.md` is the quick-start (install + usage snippets); these pages cover *why each tool is shaped the way it is*, where it stores state, and the failure modes worth knowing before you trust it.

## Modules

| Doc | Module | Version | What it does |
|---|---|---|---|
| [claude-vault.md](claude-vault.md) | `claude-vault` | 1.5.0 | Credentials in the macOS Keychain, never in files or prompts |
| [claude-toggle.md](claude-toggle.md) | `claude-toggle` | 1.7.0 | MCP servers on/off, config profiles, CLAUDE.md directives |
| [db-conn.md](db-conn.md) | `db-conn` | 1.2.0 | Query Postgres/MySQL using vault credentials |
| [squeeze.md](squeeze.md) | `squeeze` | 1.1.0 | Compress verbose command output before it enters context |
| [cindex.md](cindex.md) | `cindex` | 1.4.0 | Symbol/file index for token-light code search |
| [dbindex.md](dbindex.md) | `dbindex` | 1.1.0 | Offline database schema index |
| [csession.md](csession.md) | `csession` | 1.1.0 | Index of past Claude Code sessions; briefs and journals |
| [atl.md](atl.md) | `atl` | 1.2.0 | Offline Jira/Confluence fetcher |
| [toolkit.md](toolkit.md) | `toolkit` | 1.1.0 | Install, health-check, and control the launchd agents |
| [worklog.md](worklog.md) | `worklog` | 1.0.0 | Zero-token daily work logs from local sources |
| [skills.md](skills.md) | `skills/` | — | Repeatable workflows Claude can invoke |

## Cross-cutting

| Doc | Topic |
|---|---|
| [token-optimization.md](token-optimization.md) | How context cost actually works, and what this toolkit automates |
| [launch-agent.md](launch-agent.md) | launchd scheduled jobs — timing, manual run, pause/resume |
| [cron-jobs.md](cron-jobs.md) | In-session cron scheduler (dies with the session) |
| [loop.md](loop.md) | `/loop` — interval and self-paced re-runs |
| [project-history.md](project-history.md) | What has been built, in order, and why |

## The three principles these tools share

1. **Secrets live in the Keychain, never in a file.** No `.env`, no config with a password in it, no value pasted into a prompt. Tools fetch at the moment of use.
2. **Answer offline where possible.** Code search, DB schemas, Jira issues and past sessions are all indexed locally, so the common question costs a few dozen tokens and no network round-trip.
3. **The CLI is the source of truth.** Skills, automation and (planned) GUI shell out to these commands rather than reimplementing them, so there is exactly one behaviour to debug.

## State written outside the repo

Nothing here writes into the projects it indexes. All state is under `~/.claude/`:

```
~/.claude/vault-index.json        entry names + descriptions (no values)
~/.claude/mcp-disabled.json       stashed MCP server configs
~/.claude/backups/                timestamped ~/.claude.json + CLAUDE.md backups
~/.claude/code-index/             cindex indexes + logs
~/.claude/db-index/               dbindex schema indexes + logs
~/.claude/session-index/          csession index + logs
~/.claude/atl-config.json         Atlassian site + account email
~/.claude/toggle-groups.json      named MCP server groups
~/.claude/toolkit-agents.json     launchd agent pause state + label prefix
```

Secret *values* live only in the macOS Keychain.
