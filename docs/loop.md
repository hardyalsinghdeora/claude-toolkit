# /loop — Recurring Prompt Runner (in-session)

`/loop` is a Claude Code skill that re-runs a prompt or slash command repeatedly inside the current session. It is the interactive cousin of a session cron job.

## Usage

```
/loop <interval> <prompt or /command>     # fixed interval
/loop <prompt or /command>                # no interval → model self-paces
```

Examples:

```
/loop 30m refresh my PR dashboard and review new arrivals dry-run
/loop 5m check whether the deploy finished
/loop keep an eye on my open PRs        # Claude picks the cadence itself
```

## Two modes

1. **Fixed interval** (`/loop 30m …`) — implemented via a session cron job under the hood; fires on the wall clock.
2. **Dynamic / self-paced** (no interval) — Claude schedules its own wake-ups (`ScheduleWakeup`), choosing the delay based on what it's waiting for (e.g., poll a slow CI every ~8 min, idle-tick every 20–30 min). Delays are clamped to 1–60 minutes.

## Stopping

Ask Claude to stop the loop, or interrupt and say so — it cancels the underlying cron job / stops scheduling wake-ups.

## Limitations

- **Session-only**, like session cron jobs: the loop dies when the Claude Code session closes and does not survive laptop restarts.
- Runs consume tokens on every iteration — prefer the longest interval that still meets the need.
- For anything that must outlive the session, use a launchd LaunchAgent (`launch-agent.md`).

## Relation to the PR dashboard

"Yesterday's loop" for the PR dashboard was this pattern: a 30-minute recurring refresh of `Workspace/Claude/Output/my-open-prs.md` with dry-run reviews of new PRs. Equivalent ways to start it:

- `/loop 30m <refresh prompt>` — quickest from the keyboard.
- Ask Claude to create the session cron job directly (current setup, job `77b7bf8c`, `11,41 * * * *`).
- launchd LaunchAgent — the only variant that starts by itself when the laptop boots.
