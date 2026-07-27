# launchd LaunchAgent — Run the PR Dashboard at Laptop Startup

macOS-native way to run the 30-minute PR dashboard refresh **whenever the laptop is on**, independent of any open Claude Code session. This is the answer to "how do I get this started whenever my laptop starts" — session cron jobs and `/loop` both die with the session.

> Status: **proposed, not yet installed** (setup was paused on 2026-07-15 pending the your-mcp-gateway vs. Atlassian Bitbucket access decision).

## How it works

- A **LaunchAgent** is a plist in `~/Library/LaunchAgents/` that launchd (macOS's service manager) runs on your behalf while you're logged in.
- `RunAtLoad = true` → fires once at login/boot.
- `StartInterval = 1800` → fires again every 30 minutes after that.
- Each tick runs `claude -p "<prompt>"` — a fresh **headless** Claude Code session that refreshes the dashboard and exits. No window needs to be open.
- If the laptop is asleep at a tick, launchd coalesces missed runs into one when it wakes.

## Proposed layout

| File | Purpose |
|---|---|
| `~/Workspace/Claude/automation/pr-dashboard-prompt.md` | The refresh prompt (same content as the session cron prompt — see `cron-jobs.md`) |
| `~/Workspace/Claude/automation/pr-dashboard-refresh.sh` | Wrapper script: runs `claude -p "$(cat pr-dashboard-prompt.md)"` with the needed flags |
| `~/Library/LaunchAgents/com.example.pr-dashboard.plist` | The LaunchAgent definition |
| `~/Workspace/Claude/automation/pr-dashboard.log` | stdout/stderr from each run |

## Example plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.pr-dashboard</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>/Users/you/Workspace/Claude/automation/pr-dashboard-refresh.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>1800</integer>
  <key>StandardOutPath</key>
  <string>/Users/you/Workspace/Claude/automation/pr-dashboard.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/you/Workspace/Claude/automation/pr-dashboard.log</string>
</dict>
</plist>
```

## Example wrapper script

```sh
#!/bin/zsh
# pr-dashboard-refresh.sh — headless PR dashboard refresh
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
cd "$HOME"
claude -p "$(cat "$HOME/Workspace/Claude/automation/pr-dashboard-prompt.md")" \
  --allowedTools "Read,Write,Edit,Glob,Grep,mcp__your-gateway__mcp_search_tools,mcp__your-gateway__mcp_get_tool_schema,mcp__your-gateway__mcp_call_tool" \
  >> "$HOME/Workspace/Claude/automation/pr-dashboard.log" 2>&1
```

Notes:

- launchd does not load your shell profile — the script must set `PATH` itself (the `claude` binary lives at `~/.local/bin/claude`).
- `--allowedTools` pre-approves only the tools the job needs, so the headless run never blocks on a permission prompt. Swap the `mcp__your-gateway__*` entries for the Atlassian Bitbucket MCP tools if/when that migration happens.
- The your-mcp-gateway is an HTTP MCP server in user-level config, so headless runs can reach it (verified 2026-07-15). Interactively-authenticated claude.ai connectors (Rovo, Zoho) are **not** available headless.

## Install / manage

```sh
# install (after creating the three files)
launchctl load ~/Library/LaunchAgents/com.example.pr-dashboard.plist

# check it's registered
launchctl list | grep pr-dashboard

# trigger a run right now (test)
launchctl start com.example.pr-dashboard

# watch the log
tail -f ~/Workspace/Claude/automation/pr-dashboard.log

# uninstall
launchctl unload ~/Library/LaunchAgents/com.example.pr-dashboard.plist
rm ~/Library/LaunchAgents/com.example.pr-dashboard.plist
```

(On newer macOS, `launchctl bootstrap gui/$(id -u) <plist>` / `bootout` are the modern equivalents of load/unload.)

## Caveats

- Each tick is a fresh headless Claude session and **bills tokens** — ~48 runs/day at 30-min cadence. Consider `StartInterval 3600` (hourly) if that's too much.
- Avoid double-running: if a session cron job for the dashboard is active in an open Claude Code window at the same time, both will write the dashboard file. Delete the session job once the LaunchAgent is installed.
- LaunchAgents run only while you're logged in (that's what we want here — Keychain and user config are available).
