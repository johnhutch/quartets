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

### Visibility model — unlisted vs published (ADR-0008)

Retire "draft." Two axes: **completeness** stays derived (`Puzzle#complete?`),
**`status`** becomes visibility (`unlisted` default / `published`). Build TDD,
spec-first. Ordered so each step is shippable on its own.

1. **Model — enum rename (no data migration).** `{ draft: 0, published: 1 }` →
   `{ unlisted: 0, published: 1 }`, default `:unlisted`. `unlisted` is a clean
   Ruby symbol (dodges the `Module#private` collision a `private` value would have
   hit) and leaves every `published?` / `Puzzle.published` call site untouched
   (`play`, `home`, `attempts` controllers) while adding `unlisted?` /
   `Puzzle.unlisted`. UI label: "Unlisted." Spec the three derived states
   (incomplete = unlisted & !complete?, unlisted = unlisted & complete?, published).
2. **`play#show` gate — playability keys on `complete?`, not `published`.**
   Replace `head :not_found unless published? || owns?` with: published → anyone;
   complete (any visibility) → anyone with the link; **incomplete** → owner
   redirected to `edit_puzzle_path`, stranger → 404. Request specs for all four
   cells (stranger/owner × complete/incomplete) + the published case.
3. **SEO meta.** `play#show` emits `<meta name="robots" content="noindex,
   nofollow">` when `!published?`; published omits it. **Keep OG/Twitter tags in
   all cases** so unlisted links still unfurl (the favicon/share-image work).
   Request spec asserting the robots tag presence/absence by status.
4. **Editor finish moment.** When `complete?`, the editor's primary CTA is a loud
   **"Publish to the site"** (`m-btn--go`); secondary **"Keep it unlisted (link
   only)"** with copy *"Anyone with the link can play. Won't appear on the site
   or in search."* No auto-publish, no pre-checked default. System spec: complete
   a puzzle → both options present, Publish prominent; publishing lists it,
   unlisted doesn't.
5. **Dashboard relabel** (`puzzles/index`). Status pill: `Incomplete` /
   `Unlisted` / `Published`. Per-row actions already branch on
   `published?`/`complete?` — keep "Publish" for unlisted+complete, "Finish" for
   incomplete; rename "Unpublish?" → **"Make unlisted."** Add the honest one-liner
   near unlisted puzzles.
6. **`unpublish` → unlisted** (was → draft). Keeps data + working link. Update the
   controller flash ("Made unlisted — link still works, just not listed.") and the
   `CONTEXT.md` glossary wording when this lands.
7. **Verify no unlisted leaks.** `featured` scope is already `.published`-gated;
   add/confirm a spec that `/play`, the featured homepage, and `attempts` never
   surface an unlisted puzzle.

**Interplay with the slug migration (in flight this week):** the play URL becomes
`/p/<name-slug>-<random-suffix>` under `/p/`. The random suffix is what keeps
unlisted puzzles unadvertised — make sure resolution keys on the suffix (so a
title edit doesn't break shared links) and that unlisted puzzles get a suffix like
any other. Visibility is low-stakes by design (ADR-0008) — no access control.

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
