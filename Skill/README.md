# Skill/ — personal workflow skills (local-only)

Claude Code skills that encode *how this user works*: PR review conventions,
sprint reports, ticket creation flows, release emails. Only this README and
`_example/` are committed — real skills are gitignored because they encode
employer-specific process, names, and URLs.

## Layout

```
Skill/
├── _example/SKILL.md     # committed: generic template showing the conventions
├── pr-review/SKILL.md    # local: review a PR → Output/Review/<repo>/<pr>.md
├── sprint-retro/SKILL.md # local: my sprint retrospective → Output/Retro/
├── sprint-briefing/…     # local: squad monthly briefing → Output/Report/
├── build-release-email/… # local: release mail from a Jira version URL
├── jira-ticket/…         # local: create a ticket (preview → confirm → create)
└── vault/…               # local: store/use secrets via claude-vault
```

## Conventions these skills follow

1. **Offline-first data fetch** — every skill that needs Jira/Confluence/DB
   data calls a local script (`Scripts/atlassian/atl`, `db-conn`, `dbindex`)
   before falling back to MCP. Scripts return compact TSV/plain text, which
   costs a fraction of the tokens of MCP JSON.
2. **Dry-run by default** — skills write to `Output/` and never post, mail, or
   comment externally without an explicit user instruction.
3. **Credentials via claude-vault only** — no token or password ever appears
   in a SKILL.md, script, or output file.
4. **Keyed outputs** — files named by stable IDs so re-runs overwrite.

See `_example/SKILL.md` for a minimal template implementing all four.
