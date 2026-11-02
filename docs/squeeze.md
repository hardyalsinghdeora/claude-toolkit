# squeeze — compress verbose output before it enters context

**Version 1.2.0** · `squeeze`

Wraps a command (or a pipe) and compresses its output — capping lines, bytes and width, eliding the middle — so build logs, test runs, installs and large query results cost a fraction of the context they otherwise would.

## Why it exists

Command output is the single largest avoidable context cost in an agentic session. A `npm install`, a test run or a `SELECT` against a wide table can be thousands of lines, of which perhaps twenty matter. Worse, that output is *re-sent with every subsequent request* in the conversation, so one verbose command is paid for many times over. `squeeze` puts a bound on it at the moment of capture.

## Usage

```sh
squeeze -- <cmd> [args...]        # run the command, compress stdout+stderr
<cmd> 2>&1 | squeeze              # or compress a pipe
squeeze --json -- <cmd>           # JSON-aware compaction
```

Options:

| Flag | Meaning |
|---|---|
| `-n, --max-lines N` | line cap |
| `-b, --max-bytes N` | byte cap |
| `--head N` / `--tail N` | how much of each end to keep |
| `-w, --width N` | truncate long lines |
| `-k, --keep REGEX` | lines to preserve from the elided middle (`''` disables) |
| `--keep-max N` | cap on preserved lines |
| `--json` / `--json-items N` | JSON mode and per-array item cap |
| `-q, --quiet` | suppress the savings summary |

It reports what it saved, which is how you know whether it was worth it:

```
squeeze: 3,536 → 1,997 bytes (≈884 → ≈499 tokens, 44% saved)
```

## Design decisions worth knowing

**Errors survive elision.** The default keep-regex preserves error/warning/failure lines out of the middle section, so compression never hides the reason a build failed. This is the property that makes it safe to apply by default — a compressor that can swallow the one line you needed is worse than no compressor.

**Both ends are kept.** Output is usually informative at the start (what ran, with what config) and at the end (result, summary, error). The middle — per-file progress, dependency trees, row after row — is what gets elided, with a marker naming how many lines went:

```
··· 54 lines elided ···
```

**JSON is detected, not declared.** As of 1.1.0 a payload starting with `{` or `[` switches to JSON mode automatically; `--json` remains for the ambiguous cases. JSON mode compacts whitespace and caps array items rather than blindly truncating, so the structure stays parseable. As of 1.2.0 JSONL (one object per line) is detected too: each record is trimmed, the stream is elided like text, and the byte cap drops whole records, so every line that survives still parses.

**The cap is in bytes, and so is the report.** Up to 1.1.0 `--max-bytes` and the savings line counted characters, so non-ASCII output could run up to 4x over the cap. Both now count UTF-8 bytes.

**It is invoked by directive, not by hook.** Claude Code hooks can observe tool output but not *transform* it, so `squeeze` cannot be applied automatically to every Bash call. Instead `claude-toggle squeeze on` writes a directive into `~/.claude/CLAUDE.md` telling sessions to run verbose commands through it. That is a behavioural nudge, not an enforcement — see Q3 in `../ENHANCEMENTS.md`.

## When not to use it

Skip it when **every line matters**: a diff you are about to apply, a file you are reading for content, a short command whose output is already small. Compression costs nothing on small input but the summary line is noise, and eliding a diff is actively harmful.

## Gotchas

- **`--` is required before the command.** `squeeze -- npm test`, not `squeeze npm test`.
- **Exit codes pass through**, so `squeeze -- <cmd>` is safe in a conditional — but the compressed output is not the real output, so don't pipe it into something that parses it.
- **Windows:** output is forced to UTF-8, so the `···` markers no longer crash on a legacy console codepage. Install with `python bin/toolkit install` (see `toolkit.md`).
- **No named profiles yet.** Per-use-case caps (`--profile test|build|query`) are planned (Q2); today you pass flags.

## Related

`claude-toggle squeeze on|off` (the directive) · `docs/token-optimization.md` (where this fits in the cost model)
