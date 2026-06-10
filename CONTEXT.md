# Project Context

The durable orientation doc — what an agent must know to work here. Keep it reconciled with the code (CONTEXT drift is the most common failure; `/wrap` checks for it).

---

## Purpose

A Rails app for creating and playing NYT Connections–style puzzles. It replaces a
manual Obsidian → swellgarfo workflow that was brutal on an iPhone (the primary
device). Superusers author puzzles; anyone can play, no login. Full background in
[`CLAUDE.md`](CLAUDE.md) and [`docs/PLAN.md`](docs/PLAN.md).

## Stack

Rails 8, Turbo/Stimulus on importmap (no Node build), PostgreSQL. Sass via
dartsass-rails on Propshaft, organized SMACSS (`app/assets/stylesheets/`, naming
`l-`/`m-`/`is-`). Devise for auth. RSpec + Capybara, TDD.

## Dev Setup

Ruby pinned to 4.0.4 (`.ruby-version`); gems install to the default GEM_HOME — plain
`bundle exec` works, no `BUNDLE_PATH` override (see [Gotchas]). `bin/dev` runs the
Sass watcher; `bin/rails dartsass:build` builds CSS once. Test DB: `bin/rails db:prepare`.
Superuser is seeded from `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars (`db/seeds.rb`,
idempotent) — never committed.

## Domain Glossary

- **Puzzle** — one Connections board. `draft` or `published` (`status` enum).
- **Group** — one of four colored categories in a puzzle. Colors: `blue, green,
  yellow, purple` (enum). Authoring/form order is blue→green→yellow→purple
  (swellgarfo muscle memory), *not* NYT difficulty order.
- **Attempt** — one anonymous play-through, keyed by a `player_token` cookie.
- **share_token** — a puzzle's unguessable public slug; the public play URL is
  `/p/:share_token` (`play#show`).

## Models / key modules

- **Puzzle** (`title`, `author_name`, `status` enum, `share_token` unique,
  `user_id`). `has_secure_token :share_token`. `has_many :groups` (ordered by
  `position`), `has_many :attempts`, `accepts_nested_attributes_for :groups`,
  `belongs_to :user`. **All validations are publish-only** — title + the 4×4
  structural rules (`GROUPS_PER_PUZZLE = 4`, four distinct colors) fire only
  `if: :published?`. `MAX_MISTAKES = 4`. See ADR 0001.
- **Group** (`color` enum, `description`, `position`, `words`). `words` is a
  **jsonb** column (defaults to `[]`) — *not* a PG array, despite the PLAN
  sketch. `WORDS_PER_GROUP = 4`. `#filled_words` strips the blanks the form
  leaves. `description`/exactly-four-words validated only when the parent is
  published.
- **Attempt** (`player_token`, `solved`, `mistakes_count`, `guesses` jsonb).
  Stats (emoji cube, common wrong guesses) derive from `guesses` — no extra
  tables. Indexed on `player_token`. The public play loop records these (the
  Stimulus `game_controller.js` POSTs to `play_attempts_path`).
- **PuzzlesController** — `before_action :authenticate_user!`; every query
  scoped to `current_user` (cross-user access 404s). `publish` is a PATCH member
  route that flips draft→published. `create`/`update` are autosave-aware (see
  ADR 0001). `resources :puzzles` defines a `show` route but there's no `show`
  action/view yet.

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
