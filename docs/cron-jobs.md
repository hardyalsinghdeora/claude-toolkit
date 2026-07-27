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

- **Session-only.** Nothing is written to disk. Closing the Claude Code window, quitting the terminal, or restarting the laptop kills every job. This is why the PR-dashboard job has to be recreated each day.
- **7-day auto-expiry** for recurring jobs, even if the session stays open.
- Not suitable for "run whenever my laptop starts" — use a launchd LaunchAgent for that (see `launch-agent.md`).

## Current use: PR dashboard refresh

Job `77b7bf8c` (created 2026-07-15, session-only), schedule `11,41 * * * *`. The prompt:

1. Lists open PRs across the 12 monitored repos (workspace `your-workspace`) — authored by or awaiting review from the reviewer.
2. Updates the dashboard `Workspace/Claude/Output/my-open-prs.md` (timestamp, changes-since-last-cycle, table).
3. Full dry-run review of any **new** PR → `Workspace/Claude/Output/Review/{repo}/{pr}.md` (axis ratings, Critical/Important/Suggestion findings, verdict).
4. **Never posts to Bitbucket** — dry-run only, standing instruction.
5. If nothing changed: timestamp bump + "no changes".

To recreate after a session restart, ask Claude: *"set up the 30-min PR dashboard cron again"* (the loop behavior is documented in the dashboard header and Claude's memory).

## When to use what

| Need | Mechanism |
|---|---|
| Recurring task while this session is open | Session cron (this doc) |
| Model-paced or interval re-run of a prompt in-session | `/loop` (see `loop.md`) |
| Survives reboots / runs at laptop startup | launchd LaunchAgent (see `launch-agent.md`) |
| Runs even when the laptop is off | Scheduled cloud agents (`/schedule`) — but they cannot write local files, so unsuitable for the local dashboard |
