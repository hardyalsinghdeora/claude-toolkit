# worklog — zero-token daily work logs

**Version 1.0.0** · `bin/worklog`

Builds a per-day summary of what was actually worked on from two purely local sources — the `csession` session index and git commits across `~/Workspace` repos — and writes it to `Output/worklog/<YYYY-MM-DD>.md`.

## Why it exists

"What did I do this week?" is asked at standups, in reviews, and at the end of a sprint, and reconstructing it by hand is both tedious and inaccurate. Both required inputs already exist locally: sessions record what was worked on, git records what shipped. Combining them needs no model at all — so **a generated worklog costs zero tokens**. Only the narrative layer, if you want one, involves an AI session.

## Usage

```sh
worklog generate [--date YYYY-MM-DD] [--force]   # write one day's log
worklog check                                    # automation entry point
worklog week [--date YYYY-MM-DD]                 # aggregate the 7 days ending <date>
worklog status                                   # which recent days have logs / activity
```

`check` is what the scheduled agent runs:

- **backfill** the last 7 days, and
- **today**, but only after 21:00 — a log written at lunchtime would be wrong by evening.

## Output

`Output/worklog/<YYYY-MM-DD>.md`, with machine-readable frontmatter so weekly and monthly reports can be generated from the files rather than re-derived from source. `Output/` is gitignored — these logs are personal data and never enter the repo.

## Design decisions worth knowing

**Absence of activity is not a problem to report.** Weekends and leave produce days with nothing in them; those are skipped, not flagged. An automation that complains every Sunday gets ignored, and an ignored automation is worse than none.

**Zero tokens is a design constraint, not a side effect.** The generator is deterministic. The `worklog` *skill* layers narrative summary and improvement suggestions on top when you want them — that is the part that costs, and it is opt-in.

**Two sources, deliberately.** Sessions alone over-report exploration that went nowhere; commits alone miss the day spent debugging something that never produced a commit. Together they are a reasonable account of a day.

## Scheduling

Run by a launchd agent daily at 21:15 (`RunAtLoad` as well, so a laptop opened late still catches up). See `docs/launch-agent.md` for managing it — status, manual run, pause and resume.

```sh
launchctl kickstart -k gui/$(id -u)/com.<you>.worklog   # run one now
```

## Gotchas

- **Nothing before the session index existed can be reconstructed.** Backfill is limited by what `csession` indexed and what git recorded.
- **Only repos under `~/Workspace` are scanned** for commits.
- **`--force` overwrites an existing day's log**, including any manual edits.
- **The 21:00 rule means a same-day `check` before evening does nothing** — use `generate --date <today> --force` if you want it now.

## Related

`csession` (one of the two inputs) · `skills/worklog` (the narrative layer) · `docs/launch-agent.md` (the schedule)
