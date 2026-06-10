# Project Todos

Planned work that has been scoped but not yet started. Read this at session start and surface relevant items when related work comes up.

---

## Open decisions (settle before the anonymous-creation epic)

These gate the auth/accounts work below. None block the quick wins. **Work
through any of these with the `grill-me` skill** (or `grill-with-docs`, which
updates CONTEXT/ADRs inline) — don't resolve them ad hoc. Write the outcomes
into DECISIONS.md before building Phase 3.

- **D1 · Anonymous-draft ownership** — how does an anonymous puzzle stay
  editable + listable by its creator, and how does it get claimed on signup?
  Candidates: session/cookie identity (like player stats), a per-puzzle edit
  token baked into a "manage" link, or both. Underpins no-login creation,
  claim-on-signup, and the dashboards.
- **D2 · Auth-gate reversal** — does `authenticate_user!` come off
  `PuzzlesController` entirely (fully public creation), or stay for an
  admin-only surface? Reconcile with — and rewrite — the recorded
  "Superuser-only for puzzle creation" decision in CLAUDE.md / DECISIONS.md.
- **D3 · Creator identity for the public homepage** — `author_name` is
  free-text today; a personal homepage (`/u/:handle`) needs a stable per-creator
  identifier. Do accounts get a unique handle/slug, and how does free-text
  `author_name` reconcile with a claimed account?
- **D4 · Devise modules** — which to enable beyond `database_authenticatable`:
  `recoverable` (forgotten password — yes), `confirmable` (email confirmation —
  decide), and whether mailers need real SMTP on the Synology box.

- **Extend the author→publish system spec** to assert landing on the public
  share URL, once the Phase 3 play page (`/p/:share_token`) exists. Today it
  stops at the dashboard. (`spec/system/puzzle_authoring_spec.rb`)
- **Tune the auto-save debounce** — currently 1000ms
  (`data-autosave-debounce-value` on the form). Feel it on a real phone and
  adjust.
- **No-login puzzle creation** (restores original spec — got lost along the
  way). Anyone can create a puzzle without signing in: the creator fills in an
  `author_name` field (already exists on the model), and on publish they get a
  shareable link to hand out. **Blocked on D1 + D2** (ownership model + the
  auth-gate reversal, which also rewrites the "superuser-only creation"
  decision).
- **Richer share payload** — the emoji cube copied on completion should also
  include the puzzle **title** and a **direct link** to the puzzle, not just the
  🟨🟩🟦🟪 grid. (Lives in `game_controller.js`; the play page knows the
  share_token / URL.)

### Auth & accounts

- **Style the login page** — apply the brutalist theme + `.l-container`
  containerized styling (currently a bare Devise view).
- **Clean up the whole signup & login flow** — style every Devise screen on-theme
  and make it quick and frictionless to get through, mobile-first.
- **Wire the standard Devise helpers** — forgotten-password (recoverable) and the
  rest of the expected account flows (confirmation/mailers as needed), styled to
  match. (Scope set by **D4**.)
- **"View my puzzles" dashboard for logged-in users** — a link into an
  admin-style dashboard: a table of the puzzles they've created, each row linking
  through to its stats. Surface aggregate stats per puzzle inline —
  # of completions, # of *successful* completions, and avg mistakes. (Builds on
  the existing `puzzles#index` "Your puzzles" view + `puzzles#stats` /
  `PuzzleStats`; this turns the per-puzzle stats into an at-a-glance table.)
- **Sign-up CTA after anonymous creation** — once someone creates a puzzle while
  logged out, prompt them to sign up to (a) view their puzzle's stats, (b) keep
  all their created puzzles in one place, and (c) get a personal public homepage
  listing all their puzzles to share. This is the bridge between the two auth
  threads: anonymous create → claim-on-signup. **Blocked on D1 + D3** (the
  session/edit-token that ties an anonymous puzzle to the account that claims it,
  plus the creator handle for the public homepage). The "personal homepage" is a
  new public per-creator index (e.g. `/u/:handle`).

---

## Suggested order

Reasoning lives in the session where this was set; the short version:

1. **Quick wins, no decisions** — richer share payload → extend the
   author→publish spec to the share URL → auto-save debounce tune.
2. **Auth polish (works on today's model)** — style login → clean the full
   signup/login flow → wire `recoverable` (per D4) → "view my puzzles" stats
   dashboard (logged-in puzzles already `belong_to` the user, so this needs no
   anonymous-creation decision).
3. **The anonymous-creation epic** — settle **D1–D3** and rewrite the decision
   in DECISIONS.md *first*, then build no-login creation → sign-up CTA /
   claim-on-signup / per-creator public homepage.
