# cindex — indexed code search

**Version 1.4.0** · `cindex`

Builds a symbol and file-path index per project, then answers "where is `X` defined?" from the index in compact `path:line  kind name` form — a few dozen tokens instead of a raw grep dump.

## Why it exists

Finding a function in a large repo by grep costs two ways: the search prints every incidental match, and the agent often has to read whole files to disambiguate. On a 2,600-file front-end repo that is a meaningful share of a context window, spent before any actual work starts. An index turns the same question into a handful of lines, and turns "which repo defines this?" — previously unanswerable without running the search N times — into one command.

## Storage

```
~/.claude/code-index/indexes/          one JSON index per project
~/.claude/code-index/logs/cindex.log   build/refresh log, auto-rotated
```

Nothing is ever written into the project being indexed.

## Usage

```sh
cindex <query>                  # symbols + file paths (builds the index on first use)
cindex --all <query>            # search EVERY indexed project at once
cindex file <pattern>           # file-path search only
cindex grep <regex> [--ext .py] # content grep over indexed files, capped output
cindex refresh                  # incremental: only files whose mtime/size changed
cindex build                    # force a full re-parse
cindex status                   # this project's index
cindex list                     # all indexed projects
cindex prune                    # drop indexes whose project root is gone
```

Options: `--path P` (root override), `--limit N` (default 25), `--no-refresh` (fastest), `--json`.

## How indexing works

- **Project root** is the nearest `.git` upward from cwd, else cwd.
- **First search builds the index**; later searches refresh incrementally, re-parsing only files whose mtime or size changed. You never run `build` in normal use.
- **`.claudeignore`** is honoured per repo, so generated output, task artefacts, logs and usage data stay out of the searchable set. On this repo that is the difference between 122 and 18 indexed files — the ignored ones were all noise.
- **Ticket ids are extracted from branch names** at index time, so `cindex --all PROJ-123` finds the repos and branches where a ticket's work actually lives.

**Languages:** Python, JS/TS/JSX/TSX, Go, Java, Kotlin, C, PHP, Ruby, Rust, C/C++ (types only), SQL, shell. Everything else is path-indexed — findable by name, not by symbol.

## Design decisions worth knowing

**Refresh, never rebuild, on a schedule.** The scheduled sweep (`automation/cindex-refresh.sh`, run by a launchd agent) calls the mtime-incremental `refresh` path. An early version called `build` — a full re-parse of every repo, nightly, for no benefit. If you add automation around this tool, refresh is almost always the right verb.

**Output is capped and compact by design.** `--limit` defaults to 25 and `grep` caps its output, because an uncapped result set defeats the purpose of having an index.

**Cross-project search is a separate flag, not the default.** Most questions are about the repo you are in; `--all` exists for the ones that aren't ("which service defines this type?").

## Gotchas

- **Symbol extraction is regex-based, not a parser.** Python/JS/TS/Go coverage is good; Java, Kotlin and C# method extraction is heuristic, and C/C++ only yields types. Optional `universal-ctags` integration is planned (X3) — the regex fallback stays so the tool remains dependency-free.
- **`grep` shells out per 200-file chunk**, which is slow on the largest repos; a `ripgrep` fast path is planned (X4).
- **A stale index answers confidently.** `refresh` runs on search, so this is rare, but `--no-refresh` explicitly skips the check — quick, and occasionally wrong.
- **Deleted projects linger** until `cindex prune`.

## Related

`claude-toggle cindex on|off` (the directive that makes sessions reach for it) · `csession` (ticket ids indexed the same way) · `automation/cindex-refresh.sh` + `docs/launch-agent.md` (the scheduled sweep)
