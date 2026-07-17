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
claude-toggle profile load <name>                 # restore MCP config from a snapshot
claude-toggle profile load <name> --all           # ...also overwrite settings.json
claude-toggle profile load <name> --settings-only # ...only settings.json
claude-toggle profile list

claude-toggle backups                             # list auto-backups
claude-toggle backups prune --keep 10             # trim old backups (auto-kept at 20)
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
claude-vault set asset-db --field password   # update ONE field, keep the rest
claude-vault set jira-token --from-clipboard # take the value from the clipboard
printf '%s\n' "$VAL" | claude-vault set x --stdin   # scriptable set
claude-vault rename asset-db asset-db-old
claude-vault delete jira-token

claude-vault set my-pw --password        # password-type: NEVER displayed on a
                                         # terminal — usable only via $(...) /
                                         # pipes, or `get my-pw --copy`
claude-vault pin enable my-pw            # optional per-entry PIN lock (default off):
                                         # value stored PBKDF2-encrypted, reads
                                         # prompt for the PIN
claude-vault pin disable my-pw
```

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

Example — query a DB using stored credentials:

```bash
mysql -h "$(claude-vault get asset-db --field host)" \
      -u "$(claude-vault get asset-db --field user)" \
      -p"$(claude-vault get asset-db --field password)" \
      "$(claude-vault get asset-db --field database)" -e "SELECT ..."
```

In a Claude Code session, just say e.g. *"search the asset DB for X — credentials are in claude-vault under `asset-db`"*.

Install: same as claude-toggle (`cp claude-vault ~/.local/bin/`). macOS only.

## core-db — query the CORE Postgres servers

Wrapper around `psql` that pulls the connection config from claude-vault (entries `prod-postgres-db`, `stg-postgres-db`, `test-postgres-db`, `local-postgres-db`) and the password from the matching per-member entry (`<env>-postgres-db.<dbuser>[.ro|.rw]`). Fails fast with a VPN hint when the host is unreachable.

```bash
core-db databases                                  # prod by default
core-db --env stg tables iamdb
core-db --env local iamdb "SELECT id, username FROM users LIMIT 5"
core-db --user teammate2 iamdb "SELECT 1"          # another member's credentials
core-db --role ro iamdb "SELECT ..."               # use the view-only password
core-db iamdb -f lookup.sql --csv > out.csv
```

## Notes

- Changes take effect in **new** Claude Code sessions, not ones already running.
- Avoid toggling at the exact moment a live session exits — Claude Code rewrites `~/.claude.json` on exit and could overwrite the change (the auto-backup lets you recover).
- The tool manages the **current user's** config only (`~/.claude.json`, `~/.claude/`); each teammate runs it on their own machine.
- Profiles are stored in `~/.claude/config-profiles/`, disabled servers in `~/.claude/mcp-disabled.json`.
