# atl — offline Jira/Confluence fetcher

**Version 1.2.0** · `Scripts/atlassian/atl`

Direct REST calls to Jira and Confluence with **compact output**, replacing Atlassian MCP round-trips (tool-schema loading plus verbose JSON) for the handful of queries that actually come up.

## Why it exists

The Atlassian MCP server costs context twice: its tool schemas load into every session whether used or not, and its responses are full JSON documents where two fields were wanted. A sprint query that matters as five columns of TSV arrives as tens of kilobytes of nested objects. `atl` issues the same REST call and prints `key<TAB>status<TAB>type<TAB>assignee<TAB>summary`.

## Configuration

Deliberately **not** hardcoded — this repo is public:

| Setting | Source, in order |
|---|---|
| Site | `ATL_SITE` → `~/.claude/atl-config.json` `.site` |
| Account email | `ATL_EMAIL` → `~/.claude/atl-config.json` `.email` → vault `jira-email` |
| Token | vault `jira-api-token` / `confluence-token` |

```sh
claude-vault set jira-api-token --desc "Jira API token"   # id.atlassian.com → Security
echo '{"site":"https://<site>.atlassian.net","email":"you@example.com"}' \
  > ~/.claude/atl-config.json
```

Unconfigured runs exit with those instructions rather than pointing at someone else's tenant.

## Usage

```sh
atl jql "<JQL>" [--limit N] [--desc] [--json]   # issues, compact TSV
atl sprint "<sprint name>" [--mine]             # sprint issues (JQL helper)
atl version <jira-release-url>                  # fix-version name, date + issues
atl user "<display name>"                       # accountId lookup
atl page <confluence-url-or-page-id>            # page as plain text, capped at 15k chars
atl create --project PROJ --type Task --summary "..." [--dry-run]
atl whoami                                      # which account the token actually is
```

## Two Atlassian behaviours this tool exists to survive

**Scoped tokens do not work against the site URL.** Modern Atlassian API tokens carry product scopes and authenticate only via the gateway, `api.atlassian.com/ex/<product>/<cloudId>`, returning 401 on `<site>.atlassian.net`. They are also product-specific — a Jira token cannot read Confluence. `atl` tries the site URL, falls back to the gateway, caches which one worked in `~/.claude/atl-cache.json`, and picks the token by request path (`/wiki/` → Confluence first).

**Jira answers bad auth with HTTP 200 and zero issues.** Not a 401 — an empty result set, indistinguishable from a query that genuinely matched nothing. A revoked token therefore looks like "working, but nothing to show". Every empty result is now proven: `atl` calls `/rest/api/3/myself` and either confirms *"0 issues — authenticated as X, so the query genuinely matched nothing"* or fails loudly with the token-refresh command. This is the single most valuable behaviour in the tool.

## Design decisions worth knowing

**`create` has a `--dry-run` that prints the payload and checks auth without POSTing.** Creating a ticket is the one irreversible operation here; the dry run is the default way to use it, and a real create should be a deliberate act.

**Confluence storage format is cleaned before flattening.** Raw `ac:structured-macro` parameters otherwise concatenate into artefacts like `12falselistfalse` in the middle of prose. Macro metadata is dropped, `<time datetime>` elements are resolved to real dates, and tables render as markdown rows.

**Output is capped** — pages at 15k characters, JQL paginated with an explicit `--limit`.

## Gotchas

- **Two tokens, two products.** If Confluence calls fail while Jira works, you are missing `confluence-token` — the fallback tries the other token but a Jira-scoped token genuinely cannot read pages.
- **No 429 backoff.** A rate limit surfaces as an error rather than a retry (A5).
- **`create` has never been run against a live project** — only `--dry-run`. Validate on a throwaway ticket first.
- **`version` takes a release URL**, not a version name.

## Related

`claude-vault` (tokens) · `Skill/sprint-briefing`, `Skill/build-release-email`, `Skill/jira-ticket` (skills that fetch through this tool)
