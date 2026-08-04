# Skills — repeatable workflows

`Skill/<name>/SKILL.md` · invoked in a session as `/<name>`

A skill is a packaged set of instructions for a recurring task: review a PR to a fixed rubric, produce a sprint retrospective, draft a release email from a Jira version, create a ticket through a preview-then-confirm flow. It encodes *how this user works* so the workflow does not have to be re-explained each time.

`Skill/README.md` holds the layout and template. This page covers how skills relate to the rest of the toolkit.

## What is and isn't committed

Only `Skill/README.md` and `Skill/_example/SKILL.md` are in git. **Real skills are gitignored** because they encode employer-specific process, project keys, people and URLs — the same category of content that had to be scrubbed out of the tools themselves (see `project-history.md`). The example is a working template implementing every convention with placeholder values.

## The four conventions

1. **Offline-first data fetch.** Any skill needing Jira, Confluence or database data calls a local script — `bin/atl`, `db-conn`, `dbindex` — before considering MCP. Compact TSV or plain text costs a fraction of the equivalent MCP JSON, and works without a VPN.
2. **Dry-run by default.** Skills write to `Output/` and never post, mail or comment externally without an explicit instruction in the moment. A workflow that can publish is a workflow that will eventually publish something unintended.
3. **Credentials via `claude-vault` only.** No token or password ever appears in a `SKILL.md`, a helper script, or an output file.
4. **Keyed outputs.** Files are named by stable ids (`Output/Review/<repo>/<pr>.md`) so a re-run overwrites rather than accumulating near-duplicates.

## Why skills call CLIs instead of doing the work

The same reason the planned GUI will: there is one implementation to debug. When `atl` gained its identity guard — proving that an empty Jira result is genuinely empty rather than a silently revoked token — every skill that fetches through it inherited the fix without being touched. A skill that had inlined its own REST call would still be reporting "no issues" today.

## Known problem: two homes

Skills currently exist in **two places** — an older `Promt/Skills/*.md` set (MCP-first) and this newer `Skill/*/SKILL.md` set (offline-first). They have already drifted: `pr-review` and the older `Review.md` differ. Consolidating on this repo, with pointer stubs left behind, is item **K1** in `../ENHANCEMENTS.md` and the highest-priority open work in the plan.

## Gotchas

- **`disable-model-invocation: true`** in the frontmatter means the skill runs only when explicitly invoked, never picked up automatically. The example sets it; decide deliberately for each skill.
- **A skill is instructions, not code.** It cannot enforce its own dry-run rule — that depends on the instruction being followed, which is why rule 2 is stated in the imperative and repeated in each skill rather than assumed.
- **Skills that still fetch via MCP** (`pr-dashboard`, `pr-review`) are waiting on a Bitbucket equivalent of `atl` before they can go offline-first (A4/K2).

## Related

`Skill/README.md` (layout + template) · `atl`, `db-conn`, `dbindex` (the offline fetchers) · `worklog` (a tool with a skill layered on top)
