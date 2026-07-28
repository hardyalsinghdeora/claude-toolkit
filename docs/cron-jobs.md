# Claude Code Session Cron Jobs

In-session scheduler built into Claude Code. Claude registers jobs with the `CronCreate` tool; each job re-injects a saved prompt into the **current session** on a cron schedule.

## How it works

- Standard 5-field cron expression in **local time**: `minute hour day-of-month month day-of-week`.
  - `11,41 * * * *` → fires at :11 and :41 past every hour (every 30 min).
  - `0 9 * * 1-5` → weekdays at 9:00 am.
- At each fire time the saved prompt is enqueued into the session as if you typed it.
- Jobs only fire while the session is **idle** — a tick that lands mid-task waits for the current work to finish.
- The scheduler adds small jitter (recurring jobs can fire up to 10% of the period late). Prefer off-minutes (`:11`, `:41`) over `:00`/`:30`.
- One-shot mode (`recurring: false`) for "remind me at 2:30pm" style jobs — fires once, then auto-deletes.

## Managing jobs

Ask Claude in the session:

| Action | Tool Claude uses |
|---|---|
| Create a job | `CronCreate` (cron expr + prompt) |
| List jobs | `CronList` |
| Cancel a job | `CronDelete` (by job ID) |

## Limitations (important)

- **Session-only.** Nothing is written to disk. Closing the Claude Code window, quitting the terminal, or restarting the laptop kills every job — a job you rely on daily has to be recreated each day.
- **7-day auto-expiry** for recurring jobs, even if the session stays open.
- Not suitable for "run whenever my laptop starts" — use a launchd LaunchAgent for that (see `launch-agent.md`).

## Shape of a useful job

A polling/refresh job reads best as a numbered prompt: what to list, which file to update, what to do only when something changed, and — for anything that touches an external system — an explicit standing instruction about what it must **never** do (post, comment, delete). Write the "never" line into the prompt itself; a job that fires unattended every 30 minutes is exactly where an unstated assumption becomes an outbound action.

Keep the outputs under `Output/` (gitignored) so a scheduled job never stages work products into the repo.

## When to use what

| Need | Mechanism |
|---|---|
| Recurring task while this session is open | Session cron (this doc) |
| Model-paced or interval re-run of a prompt in-session | `/loop` (see `loop.md`) |
| Survives reboots / runs at laptop startup | launchd LaunchAgent (see `launch-agent.md`) |
| Runs even when the laptop is off | Scheduled cloud agents (`/schedule`) — but they cannot write local files, so unsuitable for anything that updates `Output/` |
