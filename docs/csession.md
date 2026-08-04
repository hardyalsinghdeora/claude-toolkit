# csession — past-session index and manager

**Version 1.1.0** · `csession`

Indexes **what you worked on** across every Claude Code session — tasks, prompts, outcomes, projects, files touched, ticket ids — so past work is findable, and a new session can be seeded with a compact brief instead of a replayed transcript.

## Why it exists

Session transcripts are large, numerous and unsearchable in practice. Two questions come up constantly: *"did I already do this, and where?"* and *"should I resume that session or start fresh?"* Answering either by opening transcripts is both slow and expensive — resuming a session replays its entire transcript into context. `csession` answers both from an index, and gives you a third option the UI doesn't: start fresh, but paste in a digest of what the old session actually accomplished.

## Storage

```
~/.claude/session-index/index.json      the index
~/.claude/session-index/logs/csession.log
```

Reads `~/.claude/projects/<project>/<session-id>.jsonl` **read-only** — the sole exception being `prune --apply`. Indexing is incremental, keyed on mtime.

## Usage

```sh
csession <query>              # find past sessions by task/topic
csession PROJ-123             # ticket ids, indexed from prompts and branches
csession list [-n 15]         # recent sessions: when, project, task, size
csession show <id-prefix>     # one session's tasks, prompts, files touched
csession brief <id-prefix>    # compact digest to paste into a NEW session
csession suggest "<task>"     # resume vs start fresh, with the command to run
csession journal [--days 7]   # combined what-I-worked-on journal
csession prune [--days 45] [--apply]
csession build                # force full re-index
```

Options: `--limit N` (25), `--project <substr>`, `--json`.

## Design decisions worth knowing

**Briefs pair each prompt with its outcome.** An earlier version replayed *prompts* — what was asked, with no indication of what happened. A brief now reads "asked X → result Y" by extracting the final assistant message for each prompt (capped), which is what makes it usable as seed context rather than a reminder.

**`suggest` encodes a real cost model.** Resuming replays the whole transcript, so it is only recommended for a related session under roughly 60k tokens. Bigger related sessions get "start new + `csession brief`" instead — same continuity, a fraction of the context.

**Ticket ids are first-class.** Extracted from both prompts and branch names into a `tickets` field and weighted in search, so `csession PROJ-123` returns every session that touched a ticket. Paired with `cindex --all PROJ-123`, that answers "ticket → sessions + repos + branches" in two commands.

**Prune is dry-run by default and never automatic.** `--apply` removes stale/empty sessions from resume history and frees disk; without it you get a list. There is deliberately no scheduled deletion — a monthly *report* is the most that is planned (N4).

## Gotchas

- **`prune --apply` is destructive** — it removes sessions from resume history. Run it without `--apply` first, always.
- **Project paths are decoded from directory names**, and Claude's encoding replaces both `/` and `.` with `-`, which is lossy: `Claude` decodes as `Claude/toolkit`. The `$HOME` prefix is recovered correctly; path segments containing hyphens or dots may not be.
- **Only indexed transcripts are searchable.** Sessions from before the index was built are picked up on the next `build`/incremental pass, but transcripts deleted outside the tool are simply gone.
- **The journal reflects session activity, not commits.** For a commit-aware view of the same days, see `worklog`, which combines both.

## Related

`worklog` (consumes this index for daily logs) · `cindex` (ticket ids indexed the same way) · `claude-toggle csession on|off` (the directive)
