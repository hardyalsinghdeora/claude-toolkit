# claude-vault — private credential store

**Version 1.5.0** · `claude-vault` · macOS only (Keychain-backed)

Stores DB credentials, API tokens and personal config in the **macOS Keychain**, so no secret has to land in a plaintext file, a git repo or a prompt. Only an index of *names and descriptions* is kept on disk. Keeping a value out of an AI **transcript** depends on how it is read: use `exec` (below). `get` prints the value to stdout, and when an agent runs it that stdout *is* the transcript.

## Why it exists

AI sessions need credentials at the moment of use — to query a database, call Jira, launch an MCP server. The alternatives are all bad: a `.env` file that gets committed eventually, a value pasted into chat that lives in the transcript forever, or a config file that syncs to a cloud backup. The vault makes "fetch it now, from the OS keystore" the path of least resistance: you tell Claude *"use `claude-vault exec <name> -- <cmd>`"* and the value goes from the Keychain straight into the command's environment, never into the session.

## Storage

| Where | What |
|---|---|
| macOS Keychain, service `claude-vault.<name>` | the secret **value**, encrypted by the OS |
| `~/.claude/vault-index.json` | names, types, descriptions, timestamps, rotation windows — **no values** |
| `~/.claude/vault-consumers.json` | directories grepped for references on rename/delete (default: this repo) |

## Entry types

| Type | Behaviour |
|---|---|
| `plain` | value prints to a terminal |
| `password` | value is **never** printed to a terminal — only into a pipe, a command substitution, or the clipboard via `--copy` |
| `json` | structured blob; individual fields addressable with `--field` |

The `password` type is the important one: it lets a script or an AI session use a credential while a human — or a screen-share audience — never sees it.

## Commands

```sh
# writing (the value is never an argv argument — it would land in shell history and ps)
claude-vault set <name> [--desc "text"]      # hidden interactive prompt
claude-vault set <name> --password           # never-displayed type
claude-vault set <name> --json               # structured blob
claude-vault set <name> --field password     # update ONE field of a JSON entry
claude-vault set <name> --stdin              # for scripts and AI sessions
claude-vault set <name> --from-clipboard     # take it from pbpaste
claude-vault set <name> --rotate-days 90     # staleness window

# reading
claude-vault get <name> [--field password]
claude-vault get <name> --copy [--clear 30]  # clipboard, auto-cleared
claude-vault list [--json]                   # names + metadata, never values

# managing
claude-vault rename <old> <new>              # greps consumers first and warns
claude-vault desc <name> "text"
claude-vault delete <name>
claude-vault doctor [--fix]                  # reconcile Keychain vs index
claude-vault test <name> | --all             # live credential check
claude-vault import <file|-> --name <entry> [--map POSTGRES_HOST=host,...]
claude-vault exec <name> [--prefix PG] -- <cmd> [args...]
claude-vault pin enable|disable <name>
claude-vault completion zsh
```

## Design decisions worth knowing

**`exec` is the agent-safe path; `get` is not.** `get` writes the value to stdout. Run by an AI session, that stdout is tool output and goes into the transcript; and `$(claude-vault get ...)` puts the secret in the parent shell's memory and, when used as an argument, in `ps` output. `exec` uses `os.execvpe` so the value goes straight into the child's environment — it never transits the shell, argv or the transcript. JSON fields become `<PREFIX><FIELD>` variables (a plain entry becomes one variable named after the entry, or `--prefix` itself):

```sh
claude-vault exec prod-db --prefix PG -- psql mydb      # psql reads PGHOST/PGUSER/PGPASSWORD itself
claude-vault exec inventory-db --prefix DB_ -- \
  sh -c 'MYSQL_PWD="$DB_PASSWORD" exec mysql -h "$DB_HOST" -u "$DB_USER" "$DB_DATABASE"'
```

(The single quotes matter: the variables are expanded by the child `sh`, after `exec` has set them, so the password is in the environment and never in an argument.)

Because of this, `get` prints a warning to **stderr** whenever stdout is not a terminal, naming the `exec` alternative. Scripts that consume the value themselves (e.g. `db-conn`) set `CLAUDE_VAULT_QUIET=1` to skip it.

**`set` never puts the value in argv.** The Keychain write runs `security -i` and sends the `add-generic-password … -w <value>` command on its stdin (each argument double-quoted, `\` and `"` escaped), then reads the entry back and fails if it does not match. Values containing a newline are refused.

**Team convention: shared config, per-member passwords.** A DB is one JSON entry with host/port/user and *no password*, plus one password-type entry per person:

```
prod-postgres-db                    {"host":..,"port":..,"user":..}
prod-postgres-db.<dbuser>           password-type, one per member
prod-postgres-db.<dbuser>.ro|.rw    optional view-only vs update variants
```

`db-conn` resolves these automatically via `--user` / `--role`. The config can be shared; the passwords never are.

**`test` distinguishes "wrong password" from "VPN off".** A failed DB login and an unreachable private endpoint look identical from the outside — this cost real debugging time twice. `test` reports `ok` / `AUTH FAILED` / `UNREACHABLE` with a VPN hint, and prints no values. `--all` health-checks the whole vault.

**`import` exists to kill a specific bad habit.** Before it, `.env`-style blocks got pasted into chat to get them into the vault — putting the secret in the transcript, which is exactly what the vault prevents. `claude-vault import` reads the file directly, auto-mapping the common `POSTGRES_*`/`DB_*`/`MYSQL_*` prefixes.

**`doctor` exists because the two stores drift.** The Keychain and `vault-index.json` are separate; a manual `security` call or a partial failure desynchronises them, and the symptom is confusing (`get` works, `list` doesn't show it). `doctor` diffs both directions and `--fix` adopts or prunes.

**PIN lock is opt-in, per entry.** `pin enable <name>` encrypts the stored value with a key derived from your PIN (PBKDF2-HMAC-SHA256, 200k iterations, plus an HMAC integrity check), so Mac-account access alone is not enough to read it. Off by default — it adds a prompt to every read.

## Gotchas

- **Never pass a secret as an argv argument.** It lands in shell history and `ps`. Use the hidden prompt, `--stdin`, or `--from-clipboard`.
- **Rotation warnings only fire if you set `--rotate-days`.** No entry has one by default, so the staleness machinery is inert until you opt in.
- **Entry type is set at write time** and there is no `retype` command — reclassifying a `plain` token as `password` means get + re-set by hand.
- **`rename` and `delete` warn, they do not rewrite.** Consumer scripts referencing the old name still need updating; the grep only tells you where to look.
- **macOS only.** Cross-platform backends (`secret-tool`, Windows Credential Manager) are planned but unbuilt — see V11 in `../ENHANCEMENTS.md`.

## Related

`db-conn` (consumes DB entries) · `atl` (consumes `jira-api-token`) · `toolkit doctor` (runs `vault doctor` as part of the health check)
