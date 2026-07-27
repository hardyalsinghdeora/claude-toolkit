#!/bin/zsh
# apidog-mcp.sh — launch the Apidog MCP server for a project.
# The access token is pulled from claude-vault at launch, so it never lives
# in ~/.claude.json or any other plaintext file (matches the Postgres setup).

export PATH="/opt/homebrew/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

APIDOG_ACCESS_TOKEN="$(claude-vault get apidog-access-token)" || {
  print -u2 "apidog-mcp: could not read apidog-access-token from vault"
  exit 1
}
export APIDOG_ACCESS_TOKEN

exec npx -y apidog-mcp-server@latest --project=$PROJECT
