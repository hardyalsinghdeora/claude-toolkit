#!/bin/zsh
# apidog-mcp.sh — launch the Apidog MCP server for a project.
# The access token is pulled from claude-vault at launch, so it never lives
# in ~/.claude.json or any other plaintext file (matches the Postgres setup).
#
# The project id is deployment-specific and stays out of this repo: set
# APIDOG_PROJECT_ID in the MCP server's env, or store it in
# ~/.claude/apidog-project (a single line).

export PATH="/opt/homebrew/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

PROJECT="${APIDOG_PROJECT_ID:-$(cat "$HOME/.claude/apidog-project" 2>/dev/null)}"
if [[ -z "$PROJECT" ]]; then
  print -u2 "apidog-mcp: no project id — set APIDOG_PROJECT_ID or write ~/.claude/apidog-project"
  exit 1
fi

APIDOG_ACCESS_TOKEN="$(claude-vault get apidog-access-token)" || {
  print -u2 "apidog-mcp: could not read apidog-access-token from vault"
  exit 1
}
export APIDOG_ACCESS_TOKEN

exec npx -y apidog-mcp-server@latest --project="$PROJECT"
