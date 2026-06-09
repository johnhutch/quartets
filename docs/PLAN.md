# Build Plan — Link the Things

The full gameplan to get from "Rails scaffold + styles" to "shipped on the NAS."
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
- ✅ **RSpec + Capybara + factory_bot** installed; generators locked to rspec.
- ✅ **System-spec driver** — headless Chrome at a phone-sized viewport
  (`spec/support/capybara.rb`), `js: true` opt-in. Dodges chromedriver/Chrome
  version drift by preferring a Selenium-cached driver whose major matches the
  installed Chrome. Warden `login_as` for browser-session auth.
- ✅ **Deploy wired (self-host)** — Synology Container Manager: `docker-compose.yml`
  (app + Postgres, shared by Solid cache/queue/cable), image built by CI → GHCR,
  GitHub Action ships on push to `main`, jobs in Puma, entrypoint migrates/seeds.
  See ADR-0002 + `docs/DEPLOY.md`. *(Config committed; first deploy waits on the
  one-time NAS setup + GitHub secrets.)*
- ⬜ Seed the single superuser (env-driven creds, not committed). *(Unblocked
  once Devise lands — see Phase 1.)*

## Phase 1 — Data model + auth 🚧

- ✅ **Devise**, superuser only. No public sign-up route. Creation/editing is
  gated; everything player-facing is open.
- ✅ Migrations + models for `Puzzle`, `Group`, and `Attempt` per the schema.
- ✅ Validations — the rules the form *and* the importer both lean on:
  - exactly 4 groups per puzzle *(enforced on publish)*
  - exactly 4 words per group *(enforced on publish)*
  - the 4 colors are present and unique within a puzzle
  - `share_token` generated on create, unique
  - mistakes capped at 4 (`Puzzle::MAX_MISTAKES`)
- ✅ Specs: model validations + factories (incl. a valid `:published_puzzle`).

## Phase 2 — Authoring (the part that fixes the original pain) 🚧

- ✅ **Creation form** — four color-coded `m-group` blocks in swellgarfo order
  (Blue → Green → Yellow → Purple). Per group: **Answers first** (the 4 words),
  **then Description**. Title + Author at the **bottom**. (Manual save for now;
  auto-save layers on next.)
- ✅ `PuzzlesController` + routes, gated by `authenticate_user!`, every query
  scoped to `current_user` (no cross-user access). `belongs_to :user` wired.
- ✅ **Superuser dashboard** — drafts + published in one list, drafts wearing the
  `.is-draft` badge. New / edit / delete.
- ✅ Publish action: draft → published, enforcing the full 4×4 rules.
- ✅ Request specs: auth gating, draft create, nested groups, publish (complete
  vs. incomplete), ownership.
- ✅ **Auto-save drafts** — the non-negotiable, born from losing work to the iOS
  back button. Debounced Stimulus controller (`autosave_controller.js`) fires a
  background fetch on input: first save POSTs and mints the draft, then flips the
  form to PATCH that record. Title is now publish-only (answers-first form puts
  it last), so untitled partial drafts save. Debounce defaults to **1000ms**.
- ✅ Draft resilience spec: partial puzzle (2 groups filled, untitled) persists
  and reloads intact (`spec/requests/puzzle_autosave_spec.rb`).
- ✅ System spec (mobile viewport, `spec/system/puzzle_authoring_spec.rb`):
  auto-save resilience (half-typed draft survives leaving without saving) +
  author a full puzzle and publish. *(Publish lands on the dashboard for now;
  redirecting to the public share URL waits on the Phase 3 play page.)*

## Phase 3 — Play 🚧

- ✅ **Game engine** — built our own Stimulus `game_controller.js` (no droppable
  vanilla engine exists; ADR-0003). Shuffles 16 tiles, pick-4 → submit →
  reveal-or-mistake loop, mistakes capped at `Puzzle::MAX_MISTAKES`, fires a
  `game:finished` event with the guess log for Phase 4.
- ✅ **Public puzzle page** (`/p/:share_token`) — `PlayController#show` feeds the
  engine one puzzle's groups as JSON; drafts/bad tokens 404; no login.
- ✅ **Public puzzle index** (`/play`) — browsable list of published puzzles only.
- ✅ **Anonymous player identity** — a signed, permanent `player_token` cookie set
  on every play (ready for Phase 4 attribution; not yet recording attempts).
- ✅ System spec: play a puzzle to a win and to a loss (`spec/system/play_spec.rb`).
  *(Attempt *recording* lands in Phase 4 — the engine already emits the data.)*

## Phase 4 — Stats + sharing ✅

- ✅ **Record attempts** — the engine posts a finished play to
  `POST /p/:share_token/attempts` (`AttemptsController`); writes an `Attempt`
  with solved?, mistakes_count, and the ordered `guesses` jsonb (each guess = the
  4 words + the true color of each). Anonymous, tied to the `player_token` cookie.
  Best-effort (a failed save never breaks the game). Request + system specs.
- ✅ **Per-puzzle stats view** — `PuzzleStats` value object + a gated, owner-scoped
  `/puzzles/:id/stats` page (linked from the dashboard): total attempts, solve
  rate, mistakes-per-attempt distribution, and **common wrong guesses** (aggregated
  from the `guesses` jsonb — no separate table). Hard-spec'd logic + request spec.
- ✅ **Emoji result cube** (🟨🟩🟦🟪) — `EmojiCube` value object turns an
  attempt's `guesses` into the 4×N grid; the attempts endpoint returns it and the
  game shows it post-play with copy-to-clipboard.
- ✅ Cube generator spec'd hard — pure logic, 7 unit cases (color mapping, order,
  empty, symbol/string keys, unknown-color fallback). `spec/models/emoji_cube_spec.rb`.

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
- ⬜ **Production deploy on the Synology** + a real end-to-end smoke test: create →
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
- **Draft auto-save cadence** — set to **1000ms** for now (`data-autosave-debounce-value`
  on the form). Tune by feel on a real phone.
