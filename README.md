# claude-toggle

Enable/disable local MCP servers for Claude Code without losing their configuration, and save/restore whole config profiles.

Claude Code's built-in `claude mcp remove` **deletes** a server's config permanently. This tool instead *moves* the config into a stash file (`~/.claude/mcp-disabled.json`), so re-enabling restores it exactly — auth settings included. Every change first writes a timestamped backup of `~/.claude.json` to `~/.claude/backups/`.

## Install

Requires Python 3 (pre-installed on macOS). No dependencies.

```bash
chmod +x claude-toggle
cp claude-toggle ~/.local/bin/     # or anywhere on your PATH
```

## Usage

```bash
claude-toggle list                                # all MCP servers, per scope, with status
claude-toggle disable <server>                    # disable everywhere it's configured
claude-toggle disable <server> --project <path>   # disable for one project only
claude-toggle disable <server> --global           # disable in global scope only
claude-toggle enable <server> [--project <path>|--global]

claude-toggle profile save <name>                 # snapshot MCP config + settings.json
claude-toggle profile load <name>                 # restore a saved snapshot
claude-toggle profile list
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

## Notes

- Changes take effect in **new** Claude Code sessions, not ones already running.
- Avoid toggling at the exact moment a live session exits — Claude Code rewrites `~/.claude.json` on exit and could overwrite the change (the auto-backup lets you recover).
- The tool manages the **current user's** config only (`~/.claude.json`, `~/.claude/`); each teammate runs it on their own machine.
- Profiles are stored in `~/.claude/config-profiles/`, disabled servers in `~/.claude/mcp-disabled.json`.
