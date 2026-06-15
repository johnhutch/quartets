# Project Context

The durable orientation doc — what an agent must know to work here. Keep it reconciled with the code (CONTEXT drift is the most common failure; `/wrap` checks for it).

---

## Purpose

A Rails app for creating and playing NYT Connections–style puzzles. It replaces a
manual Obsidian → swellgarfo workflow that was brutal on an iPhone (the primary
device). **Anyone can author or play — no login.** Accounts (Devise) are optional:
they let you own and revisit your puzzles across devices (ADR-0005). Full
background in [`CLAUDE.md`](CLAUDE.md) and [`docs/PLAN.md`](docs/PLAN.md).

## Stack

Rails 8, Turbo/Stimulus on importmap (no Node build), PostgreSQL. Sass via
dartsass-rails on Propshaft, organized SMACSS (`app/assets/stylesheets/`, naming
`l-`/`m-`/`is-`). Devise (`registerable` + `recoverable`, no confirmable) for
optional accounts. RSpec + Capybara, TDD.

## Dev Setup

Ruby pinned to 4.0.4 (`.ruby-version`); gems install to the default GEM_HOME — plain
`bundle exec` works, no `BUNDLE_PATH` override (see [Gotchas]). `bin/dev` runs the
Sass watcher; `bin/rails dartsass:build` builds CSS once. Test DB: `bin/rails db:prepare`.
An admin account is seeded from `ADMIN_EMAIL` / `ADMIN_PASSWORD` (`db/seeds.rb`,
idempotent; dev falls back to `admin@example.com` / `password123`) — accounts are
optional now, but this gives you one to log in with. Forgot-password mail previews
in dev via `letter_opener`; prod reads SMTP from ENV (`SMTP_*`, `MAILER_SENDER`,
`APP_HOST`).

## Domain Glossary

- **Puzzle** — one Connections board. `status` enum is **visibility**: `unlisted`
  (default) or `published` (ADR-0008). Whether it's *playable* is derived from
  `#complete?`, independent of visibility — the three author-facing states are
  incomplete (unlisted & !complete?), unlisted (unlisted & complete?), published.
  **Naming:** user-facing chrome (nav, buttons, titles, headings) calls a Puzzle a
  **"quartet"**; the model, table, and routes stay `Puzzle`/`puzzles`.
- **Group** — one of four colored categories in a puzzle. Colors: `blue, green,
  yellow, purple` (enum). Authoring/form order is blue→green→yellow→purple
  (swellgarfo muscle memory), *not* NYT difficulty order.
- **Attempt** — one play-through, keyed by a `player_token` cookie; also
  attributed to `user_id` when the player is logged in (ADR-0009). Logged-in
  players get **one attempt per puzzle** (partial unique index).
- **share_token** — a puzzle's unguessable public slug; the public play URL is
  `/p/:share_token` (`play#show`).
- **creator_token** — a signed, permanent cookie that owns a logged-out author's
  puzzles until they sign in/up (claim-on-auth). Mirrors `player_token`. ADR-0005.

## Models / key modules

- **Puzzle** (`title`, `author_name`, `status` enum, `share_token` unique,
  `featured` bool, and ownership via **either** `user_id` **or** a `creator_token`
  cookie). `has_secure_token :share_token`. `has_many :groups` (ordered by
  `position`), `has_many :attempts`, `accepts_nested_attributes_for :groups`,
  `belongs_to :user, optional: true` (logged-out authors own via the cookie —
  ADR-0005). **All validations are publish-only** — title + the 4×4 structural
  rules (`GROUPS_PER_PUZZLE = 4`, four distinct colors) fire only `if: :published?`.
  `#complete?` (title + 4 groups, each with 4 filled words + a description) is the
  **playability gate** — it drives `play#show`/`attempts` access, the editor's
  "Save"→"Keep it unlisted (link only)" label, and the Publish gate. `status`
  (`unlisted`/`published`) only controls listing/indexing. `MAX_MISTAKES = 4`.
  See ADR 0001 + 0005 + 0008.
- **Group** (`color` enum, `description`, `position`, `words`). `words` is a
  **jsonb** column (defaults to `[]`) — *not* a PG array, despite the PLAN
  sketch. `WORDS_PER_GROUP = 4`. `#filled_words` strips the blanks the form
  leaves. `description`/exactly-four-words validated only when the parent is
  published.
- **Attempt** (`player_token`, optional `user_id`, `solved`, `mistakes_count`,
  `guesses` jsonb). `belongs_to :user, optional:` — anonymous plays carry only a
  `player_token`; logged-in plays also attribute to the account, capped at one per
  puzzle by a partial unique index `(user_id, puzzle_id) WHERE user_id IS NOT NULL`
  (ADR-0009). Stats (emoji cube, common wrong guesses) derive from `guesses` — no
  extra tables. Indexed on `player_token`. The public play loop records these (the
  Stimulus `game_controller.js` POSTs to `play_attempts_path`).
- **PuzzlesController** — **public, no `authenticate_user!`** (ADR-0005). Includes
  the `Creator` concern; every query is scoped to `owned_puzzles` — `current_user`
  if signed in, else the signed `creator_token` cookie (`ensure_creator_token`
  mints it). Cross-owner access 404s. `publish` (PATCH member → redirects to
  `play_path(…, published: 1)`) and `unpublish` (PATCH member → back to `unlisted`)
  flip status; `create`/`update` are autosave-aware and a manual save redirects to
  `/puzzles` (see ADR 0001). `resources :puzzles` defines a `show` route but there's
  no `show` action/view — the public board is `play#show`.
- **Auth concerns** (`app/controllers/concerns/`) — `Creator` (cookie ownership +
  `owned_puzzles` + the `owns?` view helper), `ClaimsPuzzles` (site-wide
  `before_action`: on the first authenticated request, reassigns the cookie's
  puzzles to the account and clears the cookie), `AnonymousPlayer` (the
  `player_token` for stats). `PlayController#show` gates on `complete?` (ADR-0008):
  any complete puzzle plays for anyone with the link (published or unlisted); an
  incomplete one redirects its owner to the editor and 404s everyone else.
  `AttemptsController#create` mirrors that gate (and attributes the attempt to
  `current_user` when signed in, idempotently — ADR-0009). For a signed-in
  non-owner who's already finished a puzzle, `show` renders `play/_result` (their
  cube + revealed answers) instead of the board; `index` badges completed puzzles.

## Gotchas

- **Bundler:** install to the default GEM_HOME; don't set `BUNDLE_PATH` to the
  gem home (it nests gems where plain bundler can't find them). A malformed
  global `~/.bundle/config` was cleaned 2026-06-06.
- **System specs** opt in with `js: true` and run headless Chrome at a phone
  viewport (`spec/support/capybara.rb`); they use Warden `login_as`, not Devise's
  `sign_in`. The driver prefers a Selenium-cached chromedriver matching installed
  Chrome to dodge version drift.
- **Auto-save endpoint contract** (201+`Location` / 204, no redirect) is what
  `autosave_controller.js` depends on — don't "normalize" it back to redirects.
- Never edit `app/assets/builds/` by hand; source is `application.scss`.
