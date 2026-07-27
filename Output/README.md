# Output/ — generated work products (local-only)

Everything the skills and AI sessions *produce* lands here — and stays on the
local machine. Only this README is committed; the rest is gitignored (personal
and company data) and `.claudeignore`d (kept out of the AI-searchable index).

Typical structure that accumulates in real use:

```
Output/
├── Review/<repo>/<pr>.md      # PR review reports (dry-run: never posted)
├── Report/<month>.md          # squad sprint briefings
├── Retro/Sprint-<N>.md        # personal sprint retrospectives
├── build/<PROJ>-<id>.md       # build release announcement emails
├── Dashboard/                 # self-refreshing PR dashboard (html + data)
├── UserDedup/, system-emails/ # ad-hoc task deliverables (SQL, analyses…)
└── .cache/                    # script intermediates (scan JSON etc.)
```

Conventions:

- **Dry-run by default** — review/report generators write here first; nothing
  is posted or emailed without an explicit ask.
- **Keyed filenames** — outputs are keyed by stable IDs (PR number, version ID,
  sprint number) so re-runs overwrite rather than duplicate.
- Deliverables that must leave the machine (email, Jira comment, Excel) are
  produced *from* these files in a separate explicit step.
