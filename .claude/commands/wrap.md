---
description: End-of-session wrap — reconcile PROGRESS / TODOS / DECISIONS / CONTEXT with the work done this session
---

You are wrapping up a work session. Update this project's context files so the next session (or a fresh machine) starts from an accurate picture. Be surgical — match each file's existing voice and structure, and do not pad.

Work through these steps:

1. **Survey what changed.** Run `git log --oneline -15` and `git status --short` to see commits and uncommitted work. Skim this conversation for decisions, blockers, and follow-ups that aren't captured in the docs yet.

2. **PROGRESS.md** — update the "Last updated" date and active branch. Refresh the current-branch state, and prepend a one-line entry to the shipped-log for anything completed this session. Delete any "known not-done" item that is now done or false.

3. **TODOS.md** — remove finished items (delete them, or keep only if they retain reference value). Add any new follow-ups surfaced this session, in the file's existing format.

4. **DECISIONS.md** — only if a genuine architectural decision was made this session, append a new ADR using the template at the bottom of the file. Do not invent ADRs for routine work. If a decision supersedes an existing ADR, compress the old one to a "superseded by NNNN" stub.

5. **CONTEXT.md** — if code changed a model, route, association, env var, helper, or convention, reconcile the affected CONTEXT entry. **Verify every fact you touch against the actual code** — this is exactly where drift accumulates (stale field names, dropped columns, renamed methods).

6. **Report** a short bullet list: which files you changed and why, plus anything you deliberately left alone. Do **not** commit unless explicitly asked.

If nothing in a given file needs changing, say so and move on — don't manufacture edits.
