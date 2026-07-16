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
claude-toggle list                                # all MCP servers per scope, with status + endpoint
claude-toggle disable <server>                    # disable everywhere it's configured
claude-toggle disable --all                       # disable every server
claude-toggle disable <server> --project <path>   # disable for one project only
claude-toggle disable <server> --global           # disable in global scope only
claude-toggle enable <server>|--all [--project <path>|--global]

claude-toggle profile save <name>                 # snapshot MCP config + settings.json
claude-toggle profile load <name>                 # restore a saved snapshot
claude-toggle profile list

claude-toggle backups                             # list auto-backups of ~/.claude.json
claude-toggle restore                             # roll back to the latest backup
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
claude-vault set asset-db --json --desc "MySQL for asset-logistic"
#  paste: {"host":"...","port":"3306","user":"...","password":"...","database":"..."}
claude-vault set jira-token --desc "Jira API token"

claude-vault list                        # names + descriptions only, no values
claude-vault get asset-db --field host   # one field of a JSON secret
claude-vault get jira-token              # whole value
claude-vault delete jira-token
```

Example — query a DB using stored credentials:

```bash
mysql -h "$(claude-vault get asset-db --field host)" \
      -u "$(claude-vault get asset-db --field user)" \
      -p"$(claude-vault get asset-db --field password)" \
      "$(claude-vault get asset-db --field database)" -e "SELECT ..."
```

In a Claude Code session, just say e.g. *"search the asset DB for X — credentials are in claude-vault under `asset-db`"*.

Install: same as claude-toggle (`cp claude-vault ~/.local/bin/`). macOS only.

## Notes

- Changes take effect in **new** Claude Code sessions, not ones already running.
- Avoid toggling at the exact moment a live session exits — Claude Code rewrites `~/.claude.json` on exit and could overwrite the change (the auto-backup lets you recover).
- The tool manages the **current user's** config only (`~/.claude.json`, `~/.claude/`); each teammate runs it on their own machine.
- Profiles are stored in `~/.claude/config-profiles/`, disabled servers in `~/.claude/mcp-disabled.json`.
