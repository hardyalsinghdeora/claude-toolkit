# launchd LaunchAgents — scheduled jobs that outlive the session

macOS-native way to run toolkit jobs **whenever the laptop is on**, independent of any open Claude Code session. This is the answer to "how do I get this started whenever my laptop starts" — session cron jobs (`docs/cron-jobs.md`) and `/loop` (`docs/loop.md`) both die with the session.

## Current agents

| Label | Runs | Schedule | Log |
|---|---|---|---|
| `com.<you>.cindex-refresh` | `automation/cindex-refresh.sh` | daily 09:00 + at load | `~/.claude/code-index/logs/launchd.log` |
| `com.<you>.worklog` | `Scripts/worklog/worklog check` | daily 21:15 + at load | `~/.claude/code-index/logs/worklog-launchd.log` |

Both are local-only and cost no tokens — an mtime-incremental index sweep and a work-log rollup. Agents that run a headless `claude -p` session per tick are possible but **bill on every tick**; treat that as a deliberate choice, bound the schedule tightly, and read the watchdog note under Gotchas first.

The plists live in `~/Library/LaunchAgents/`, rendered from `automation/launchd/agents.json` by `toolkit agents install` — that manifest, not the plist, is the source of truth.

## How it works

- A **LaunchAgent** is a plist in `~/Library/LaunchAgents/` that launchd (macOS's service manager) runs on your behalf while you're logged in.
- `RunAtLoad = true` → fires once at login/boot **and on every `bootstrap`**.
- `StartInterval = 1800` → fires every 30 minutes; `StartCalendarInterval` instead pins it to wall-clock times (a dict, or an array of dicts for several times a day). Omitted keys mean "every" — a bare `{Minute: 0}` is hourly, all day.
- If the laptop is asleep at a tick, launchd coalesces missed runs into one when it wakes.

## Example plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.myjob</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>/Users/YOU/Workspace/Claude-toolkit/automation/myjob.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/Users/YOU/.local/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/YOU/.claude/code-index/logs/myjob.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/YOU/.claude/code-index/logs/myjob.log</string>
</dict>
</plist>
```

launchd does not expand `~` or `$HOME` in a plist — absolute paths only, which is exactly why these are rendered from a manifest rather than hand-edited.

## Install / manage

**Prefer `toolkit agents`** — it wraps everything below, and gets right the two things that are easy to get half-right (a pause is `bootout` *and* `disable`; a resume is `enable` *before* `bootstrap`). It also records *why* an agent was paused, so `toolkit doctor` stops reporting a deliberate pause as a fault:

```sh
toolkit agents list                       # state, schedule, runs, last exit, log age
toolkit agents run worklog                # fire one tick now
toolkit agents stop worklog               # kill the running tick, keep the schedule
toolkit agents pause worklog --reason "…" --until 18:00
toolkit agents resume worklog
toolkit agents every worklog 'hourly 9-18'
toolkit agents install [--dry-run]        # render plists from automation/launchd/agents.json
```

See `toolkit.md`. The rest of this section is the underlying `launchctl` reference — what the wrapper runs, and what to use for an agent the toolkit does not manage.

`load`/`unload`/`start` are the legacy spellings; on current macOS use the domain-target form. `L` = the label, `P` = its plist path:

```sh
L=com.example.myjob; P=~/Library/LaunchAgents/$L.plist; D=gui/$(id -u)
```

**Start / install (arm the schedule)**
```sh
launchctl enable $D/$L          # clear a persisted disable override, if it was paused before
launchctl bootstrap $D "$P"     # register + arm; RunAtLoad fires one run IMMEDIATELY
```

**Status — is it armed, when does it run next, did it fail?**
```sh
launchctl list | grep example                     # quick: PID, last exit code, label
launchctl print $D/$L | grep -E 'state|runs|last exit code|path'
launchctl print-disabled $D | grep example        # persisted disable overrides
```
`launchctl list` shows `-` for PID when not running; the middle column is the **last exit code**. A label missing from `list` entirely is not loaded at all.

**Manual run — fire one tick right now**
```sh
launchctl kickstart -k $D/$L    # -k restarts it if a tick is already running
```
Runs it on the spot and leaves the schedule untouched. Prefer it over the legacy `launchctl start`.

**Stop the *current run* (keep the schedule)**
```sh
launchctl kill TERM $D/$L       # SIGKILL if it ignores TERM
```
Reach for this when a tick hangs — the next scheduled tick still happens.

**Pause the *schedule*** — both halves are required:
```sh
launchctl bootout $D/$L         # unload now (does NOT survive login on its own)
launchctl disable $D/$L         # persist across login (does NOT stop a loaded job on its own)
```
`bootout` alone = paused until next login. `disable` alone = still runs this session. Only the pair is a real pause.

**Resume**
```sh
launchctl enable $D/$L          # must come first — bootstrap on a disabled label is a no-op
launchctl bootstrap $D "$P"     # ⚠ RunAtLoad means this fires a run immediately
```

**Change the timing** — edit the plist, then reload (launchd caches the loaded copy, so editing alone does nothing):
```sh
plutil -lint "$P"               # validate the XML first
launchctl bootout $D/$L && launchctl bootstrap $D "$P"
```

**Uninstall**
```sh
launchctl bootout $D/$L; rm "$P"
```

## Gotchas that have actually bitten

- **`bootstrap` fires an immediate run** whenever `RunAtLoad` is true — costly if the job is a headless model session. Set it false while you are only editing the schedule.
- **A paused job looks identical to a broken one** at the `launchctl` level — which is why `toolkit agents pause` records the reason and `doctor` reads it back. Pause with the raw commands and you lose that.
- **launchd has no per-job timeout.** A hung tick runs forever — a headless refresh job once idled 91 minutes before being killed by hand. Any job that calls out to the network or a model needs its own `timeout` in the wrapper script, plus a lockfile so a slow tick cannot overlap the next one.
- **launchd does not load your shell profile** — set `PATH` in `EnvironmentVariables` or in the script itself. Tools installed by `toolkit install` live in `~/.local/bin`.
- **Interactively-authenticated MCP connectors are unavailable headless.** Only HTTP/stdio MCP servers configured at user level are reachable from a `claude -p` run; anything that needed a browser login in an interactive session will not be there.
- LaunchAgents run only while you are logged in — which is what you want here, since Keychain (and therefore `claude-vault`) is only unlocked then.
