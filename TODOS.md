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

### Follow-ups from the one-play-per-user work (ADR-0009)

- **Gate the home page's featured board too.** `home#show` renders a replayable
  board even if the signed-in user already finished that featured puzzle (a replay
  won't duplicate the attempt, but it's inconsistent with `play#show`). Apply the
  same `@my_attempt` → result-view treatment, or just send finished players to the
  result.
- **Claim anonymous attempts on login.** Like the `creator_token` claim (ADR-0005),
  optionally reassign a player's cookie-attributed attempts to their account on
  sign-in so pre-login plays count toward the one-play cap + "✓ Played" badges.
  Deliberately skipped for now.

### Slug migration ↔ unlisted (reminder)

The visibility model (ADR-0008) shipped. When the play URL becomes
`/p/<name-slug>-<random-suffix>`, the random suffix is what keeps unlisted puzzles
unadvertised — resolve by the suffix (so a title edit doesn't break shared links),
and give unlisted puzzles a suffix like any other. Visibility is low-stakes by
design — no access control.

### Discovery surfacing — the deferred half of ADR-0010

Authoring captures `specialized` + tags + `description`; none of it is surfaced
yet. To build (data + form already exist):
- **`/play` "Classic-style only" toggle** (`?classic=1` → `where(specialized: false)`,
  default off/all). Specialized rows show their **clickable tag chips** → a
  tag-filtered list at **`/play?tag=star-wars`** (`Tag#puzzles`). Classic rows stay
  chip-less. Show page mirrors the chips.
- **`description` → `og`/`twitter:description`** on `play#show` (fallback to the
  current generic line); show it under the byline + as a browse teaser.
- **Full-text search** over title + description (+ tags) — defer until there's a
  corpus worth searching; then Postgres `tsvector`. Pretty `/t/:tag` hubs later.
- **Difficulty from stats** (ADR-0010) — a future job deriving difficulty from
  completion success/failure rates (maybe reputation-weighted); not authored.

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
- **Superuser admin page** — a role-gated admin surface (needs a `superuser`/role
  mechanism on `User` — doesn't exist yet) with **user**, **puzzle**, and **tag**
  admin. Lists **all** puzzles (every author's); manages users; and — key for the
  tags cold-start (see below) — lets an admin **edit/merge/delete tags** to clean
  up spelling divergence ("Star Wars" vs "starwars"). The one place
  creation/ownership stays account-gated post-ADR-0005.
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
- **Finish the "quartet" rename in body copy** — chrome (nav/buttons/titles/
  headings) now says "quartet"; *prose* still says "puzzle" (dashboard/play empty
  states, claim CTA, privacy page, `og:description`). Sweep if full consistency is
  wanted — left alone on purpose since the ask was scoped to buttons/nav.

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
