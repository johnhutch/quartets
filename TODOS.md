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

### Bigger features (scoped, not started)

- **Daily auto-featured puzzle** — pick ONE puzzle to feature on the front page
  for the whole day, for all users; it cycles automatically each day (no manual
  curation). Add a `last_featured` (date) column to puzzles. Selection picks the
  first match in this order:
  1. the never-featured puzzle with the most completions;
  2. the never-featured puzzle with the most views;
  3. a never-featured puzzle with a **positive upvote score**;
  4. the puzzle with the **oldest `last_featured` date**.
  Replaces today's `RANDOM()` featured pick in `HomeController`. (Depends on the
  upvote/downvote feature for step 3, and a views counter for step 2.)
- **Upvote / downvote per puzzle** — thumbs-up / thumbs-down icons shown below
  each puzzle (play surfaces). Upvotes start at **1**, downvotes at **0** — so a
  fresh puzzle's total score is **1**. The total score shows on the puzzle's
  stats page. Anonymous-safe (one vote per player_token, like attempts).
- **Superuser admin page** — a gated view listing **all** puzzles in the system
  (every author's), for the superuser. The one place creation/ownership is still
  account-gated post-ADR-0005.
- **Bulk "Export my puzzles" (CSV)** — export is now a *separate* function: an
  "Export my puzzles" link at the **bottom of Your Puzzles** downloads **all** of
  the owner's puzzles as one CSV. Per-puzzle export is gone from the UI (the
  `/puzzles/:id/export` JSON route still works underneath — no need to rip it
  out). Decide the CSV shape (one row per puzzle with the 4 groups flattened, or
  one row per group).

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
