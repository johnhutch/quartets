# Project Todos

Planned work that has been scoped but not yet started. Read this at session start and surface relevant items when related work comes up.

---

## Resolved decisions

- **D1–D4 — settled in ADR-0005** (DECISIONS.md). Public anonymous creation,
  `creator_token` cookie ownership + claim-on-auth, Devise `registerable` +
  `recoverable` (no confirmable), env-configurable SMTP. **D3 (per-creator
  handle / `/u/:handle`) was deferred, not resolved** — see below.

---

## Still open

### Accounts — the last unbuilt pieces

- **Per-creator public homepage `/u/:handle`** (deferred from D3). Needs a stable
  per-account handle/slug and a rule for how free-text `author_name` reconciles
  with a claimed account. Then a public per-creator index listing their published
  puzzles, linkable from the share/CTA flow. *This is the only part of the auth
  epic still unbuilt.*
- **"My puzzles" aggregate stats table** — the dashboard already lists puzzles
  with a per-puzzle `Stats` link; turn that into an at-a-glance table with
  inline aggregates per row: # of completions, # of *successful* completions, and
  avg mistakes. (Builds on `puzzles#index` + `PuzzleStats`.)

### Quick wins (no decisions needed)

- **Richer share payload** — cube + title + direct link in the share sheet
  (verify what commit `b3acb2b` already covers first).
- **Tune the auto-save debounce** — currently 1000ms
  (`data-autosave-debounce-value` on the form). Feel it on a real phone and adjust.

### Ops

- **Fill prod SMTP creds** — forgot-password mail is wired and previews in dev via
  `letter_opener`; production reads `SMTP_ADDRESS`/`SMTP_PORT`/`SMTP_USERNAME`/
  `SMTP_PASSWORD`/`MAILER_SENDER`/`APP_HOST` from the NAS `.env`. Fill at first
  deploy (ADR-0005).

---

## Suggested order

1. **Quick wins, no decisions** — richer share payload → auto-save debounce tune.
2. **"My puzzles" aggregate stats table** — needs no new decision; builds on the
   existing owner-scoped dashboard + `PuzzleStats`.
3. **Per-creator public homepage `/u/:handle`** — settle the deferred D3 (handle
   model) via `grill-me` and record it in DECISIONS.md *first*, then build the
   public index.
