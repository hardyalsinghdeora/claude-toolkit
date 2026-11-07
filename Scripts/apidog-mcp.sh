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

# Pinned to an exact version: this process receives the access token, so a
# compromised future release must not be pulled in automatically. To upgrade,
# check `npm view apidog-mcp-server version` and the changelog, then bump.
APIDOG_MCP_VERSION="0.0.18"

# `claude-vault exec` puts the entry into the child's environment as
# APIDOG_ACCESS_TOKEN (derived from the entry name) without the token ever
# passing through this shell.
exec claude-vault exec apidog-access-token -- \
  npx -y "apidog-mcp-server@${APIDOG_MCP_VERSION}" --project="$PROJECT"
