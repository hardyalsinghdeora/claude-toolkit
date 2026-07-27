---
name: example-status-report
description: Template skill showing this repo's conventions — generate a weekly status report for a Jira project and write it to Output/status/<project>-<week>.md. Use as a starting point for new skills; replace the project key, queries, and template with your own.
disable-model-invocation: true
---

# Example — Weekly Status Report

## Data fetch — offline script FIRST (token-light)

Use the local fetcher; fall back to MCP only if it fails, and if credentials
are missing give the user the setup line from `atl --help`.

```bash
Scripts/atlassian/atl jql 'project = PROJ AND updated >= -7d ORDER BY status ASC'
Scripts/atlassian/atl page <status-confluence-page-url>   # optional context
```

## Inputs

| Input | Required | Default / example |
|---|---|---|
| Project key | yes | `PROJ` |
| Week | no | current ISO week |
| Output file | no | `Output/status/PROJ-<week>.md` |

## Rules

- Dry-run: write the report to `Output/` only; never post or send it anywhere
  without an explicit instruction.
- Group issues: Done / In Progress / Blocked (status categories, not raw
  status names).
- Keep the report under a page; link Jira keys, don't paste descriptions.

## Output template

```markdown
# PROJ — Week <NN> Status
**Prepared:** <YYYY-MM-DD> · **Source:** Jira (offline via atl)

## Done
- PROJ-101 — <one-line summary>

## In Progress
- PROJ-102 — <one-line summary> (<status>)

## Blocked / Risks
- <item + what unblocks it>
```
