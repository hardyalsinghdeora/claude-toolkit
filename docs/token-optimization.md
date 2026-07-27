# Token Optimization Playbook

How Claude Code token costs actually work, what this toolkit automates, and
which habits are worth building. Fact-checked 2026-07-27 against how the
product behaves — several widely-shared claims are corrected below.

## How costs actually work

- Every message resends the conversation history, so **per-message cost grows
  linearly** with history length and cumulative session cost grows roughly
  quadratically. (Not "exponentially" — but long sessions are still the #1 cost.)
- **Prompt caching** makes re-read history far cheaper (~10×) than fresh
  tokens, as long as messages arrive within the cache TTL. The TTL is **not
  universally 5 minutes** — it depends on plan/session (sessions here have run
  with a 1-hour TTL). Don't contort your workflow around a timer; do prefer
  finishing a thought while context is warm.
- Output tokens cost ~5× input tokens; verbose tool output becomes *input* on
  every subsequent turn — which is why compressing it once (squeeze) pays off
  for the whole rest of the session.

## Automated by this toolkit (zero effort once enabled)

| Lever | Tool | Directive |
|---|---|---|
| Compress verbose command output | `squeeze` | `claude-toggle squeeze on` |
| Indexed code search instead of grep dumps | `cindex` | `claude-toggle cindex on` |
| Offline DB schema lookup instead of live queries | `dbindex` | `claude-toggle dbindex on` |
| Cheap past-session context instead of resume/re-explain | `csession` | `claude-toggle csession on` |
| Index freshness at zero token cost | launchd sweep | (no session involvement) |

Directive blocks are deliberately terse — they sit in `~/.claude/CLAUDE.md`,
which loads into **every** session, so their own length is a per-session tax.
Keep the whole file lean (aim well under 200 lines): tech stack, conventions,
directives — never conversation notes.

## Habits worth building (can't be automated)

- **`/clear` between unrelated tasks.** Old-topic history is pure cost on the
  new topic. To continue earlier work after a clear: `csession brief <id>` and
  paste the digest — don't resume a huge transcript.
- **`/compact` deliberately** around ~60% context, with instructions on what to
  keep ("preserve the file list and the failing test names").
- **Batch instructions; edit instead of correcting.** One message with three
  asks beats three messages (each follow-up re-reads everything before it).
  If Claude went wrong, edit the original prompt and regenerate — the edit
  replaces the bad exchange; a correction message stacks on top of it forever.
- **Plan Mode for non-trivial work.** Tokens spent planning are cheaper than
  tokens spent generating code that gets scrapped.
- **Point, don't sweep.** `@file` or `cindex`-found `path:line` beats "find the
  bug in my repo". Surgical context is the cheapest context.
- **Right-size the model.** Default coding on the session model; delegate
  mechanical/simple subtasks (formatting, lookups, browser navigation) to
  Haiku-class subagents where the harness offers the choice.
- **Watch `/context` and `/cost`.** `/context` shows what's eating the window
  (history vs MCP overhead vs files) — MCP servers you're not using are silent
  overhead: `claude-toggle disable <server>` (that's why the tool exists).

## Claims to ignore

- "Costs compound exponentially" — linear per message; see above.
- "Cache always expires in 5 minutes" — plan/session dependent.
- "Usage drains faster at peak hours, schedule work for evenings" —
  unverifiable; limits are quota-based. Schedule work when you're sharp.
- "Force ultra-terse replies" (caveman-style) — saves output tokens but costs
  correctness on non-trivial work; squeeze compresses *tool output* instead,
  which is where the real bulk is.
