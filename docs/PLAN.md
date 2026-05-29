# Build Plan — Link the Things

The full gameplan to get from "Rails scaffold + styles" to "shipped on Render."
Phased so every step ships something real and testable. We're going TDD —
"build X" always means **spec X red, make it green, refactor.** iPhone is the
primary device, so "works" means "works on a phone."

**Status:** ✅ done · 🚧 in progress · ⬜ not started

This plan is downstream of a full design interview. The decisions behind it live
in [`CLAUDE.md`](../CLAUDE.md) — don't relitigate them here, just execute.

---

## The data model (the backbone everything hangs off)

Sketch first so the phases have something to point at. Refine as specs force it.

```
Puzzle
  title            :string
  author_name      :string         # free text, shown on the puzzle
  status           :enum [draft, published]
  share_token      :string         # public URL slug; unguessable, indexed
  user_id          :references     # the superuser who made it
  timestamps

Group                              # 4 per puzzle, exactly
  puzzle_id        :references
  color            :enum [blue, green, yellow, purple]   # unique per puzzle
  description      :string         # the category name / clue
  words            :string, array  # exactly 4. PG array column for v1.
  position         :integer        # display/form order

Attempt                            # one play-through of a puzzle
  puzzle_id        :references
  player_token     :string         # anonymous cookie id, indexed
  solved           :boolean
  mistakes_count   :integer
  guesses          :jsonb          # ordered list of guesses; each guess is the
                                   # 4 picked words + the color each truly belongs
                                   # to. The emoji cube + "common mistakes" both
                                   # derive from this — no extra tables needed.
  timestamps
```

**Why words-as-array, not a `Card` model:** simpler for v1, and stats key off
the *guess* (stored in `Attempt#guesses`), not off per-card rows. Revisit only
if something needs a stable per-word identity.

**Color vs. difficulty:** NYT difficulty runs yellow(easy) → purple(hard).
Swellgarfo's *form* orders them Blue → Green → Yellow → Purple top-to-bottom —
the authoring form mirrors that order so the user's muscle memory carries over.

---

## Phase 0 — Foundation 🚧

- ✅ `rails new` — PostgreSQL + Sass (dartsass-rails on Propshaft, Rails 8)
- ✅ SMACSS stylesheet structure, compiling clean
- ✅ Project docs (README, CLAUDE.md, this plan)
- ⬜ **RSpec + Capybara + factory_bot** installed; `rails_helper` configured for
  system specs (headless + a mobile-viewport driver). Green `bin/rspec` on an
  empty suite is the gate to leave Phase 0.
- ⬜ **Render deploy wired early** — `render.yaml` (web service + managed
  Postgres), auto-deploy on push to `main`. Deploy the empty app *now* so we
  never hit a "works locally only" wall at the end.
- ⬜ Seed the single superuser (env-driven creds, not committed).

## Phase 1 — Data model + auth ⬜

- ⬜ **Devise**, superuser only. No public sign-up route. Creation/editing is
  gated; everything player-facing is open.
- ⬜ Migrations + models for `Puzzle` and `Group` per the schema above.
- ⬜ Validations — the rules the form *and* the importer both lean on:
  - exactly 4 groups per puzzle
  - exactly 4 words per group
  - the 4 colors are present and unique within a puzzle
  - `share_token` generated on create, unique
- ⬜ Specs: model validations (the 4×4 rules are the heart of correctness),
  factories that build a valid 4-group puzzle.

## Phase 2 — Authoring (the part that fixes the original pain) ⬜

- ⬜ **Creation form** — four color-coded `m-group` blocks in swellgarfo order
  (Blue → Green → Yellow → Purple). Per group: **Answers first** (the 4 words),
  **then Description** — matching swellgarfo's actual field order. Title +
  Author at the **bottom**, not top.
- ⬜ **Auto-save drafts** — the non-negotiable, born from losing work to the iOS
  back button. Debounced Stimulus controller fires a background Turbo save on
  change; a draft is just a `Puzzle` with `status: draft`. No "save" button
  anxiety.
- ⬜ Draft resilience spec: partial puzzle (e.g. 2 groups filled) persists and
  reloads intact.
- ⬜ **Superuser dashboard** — published puzzles + drafts in one list, drafts
  wearing the `.is-draft` badge. Edit / continue / delete / publish.
- ⬜ Publish action: draft → published, generates/confirms `share_token`.
- ⬜ System spec (mobile viewport): author a full puzzle on a phone-sized screen,
  publish, land on the shareable URL.

## Phase 3 — Play ⬜

- ⬜ **Pick the game engine** — survey open-source vanilla-JS / Stimulus
  Connections clones. Criteria: maintained, permissive license, easy to feed our
  JSON, no React, embeddable without a Node build (we're on importmap). Record
  the pick + why in `CLAUDE.md`.
- ⬜ **Public puzzle page** (`/p/:share_token`) — feeds the engine one puzzle's
  data, runs the full loop: pick 4 → submit → reveal-or-mistake → win/lose,
  mistakes capped like NYT.
- ⬜ **Public puzzle index** — browsable list of published puzzles (the Q11 B
  decision: anyone on the internet, not just link-holders).
- ⬜ **Anonymous player identity** — a signed cookie token, persisted per player
  so stats attribute without any login.
- ⬜ System spec: play a puzzle to a win and to a loss; both record correctly.

## Phase 4 — Stats + sharing ⬜

- ⬜ **Record attempts** — on each completed play, write an `Attempt`: solved?,
  mistakes_count, and the ordered `guesses` jsonb (each guess = the 4 words + the
  true color of each).
- ⬜ **Per-puzzle stats view** — total attempts, solve rate, mistakes-per-attempt
  distribution, and **common wrong guesses** (derived by aggregating the
  `guesses` jsonb across attempts — no separate table).
- ⬜ **Emoji result cube** (🟨🟩🟦🟪) — the standard 4×N grid of the tried
  combinations, built from an attempt's guess rows, with copy-to-clipboard for
  bragging over text.
- ⬜ Spec the cube generator hard — it's pure logic (guesses → emoji grid) and
  the shareable artifact, so it deserves tight unit coverage.

## Phase 5 — Import + polish + ship ⬜

- ⬜ **`puzzles:import_obsidian` rake task** — parse the existing archive
  (`~/.../Connections Puzzles.md`). Formats are **inconsistent across the 8
  puzzles** (mixed `###`/`####`, comma-separated vs. bulleted words, description
  placement wanders) — the parser has to be forgiving and normalize on the way
  in. Idempotent (safe to re-run). Spec it against a fixture of the real messy
  formats.
- ⬜ **JSON export** per puzzle — download endpoint, stable schema.
- ⬜ **Mobile pass** — iPhone is *the* device. Real-device check of authoring,
  playing, and sharing. Tap targets, the form's auto-save, the cube copy.
- ⬜ **Production deploy on Render** + a real end-to-end smoke test: create →
  publish → play → see stats → share, on the deployed app.

---

## Open questions / decisions deferred

- **Which game engine** — settle in Phase 3, record the choice.
- **Words storage** — array column for v1; promote to a `Card` model only if a
  real need for per-word identity shows up.
- **Common-wrong-guesses storage** — planning to derive from `Attempt#guesses`
  rather than a dedicated table. If aggregation gets slow at scale, add a
  rollup; not before.
- **Mistake cap on play** — match NYT's 4? Make it configurable per puzzle?
  Decide when the engine's picked, since it may dictate this.
- **Draft auto-save cadence** — debounce interval (1–2s?) to tune once the form
  exists and we can feel it on a phone.
