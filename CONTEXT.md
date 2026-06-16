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
  **Discovery (ADR-0010):** `specialized` bool (false = "Classic", the general
  default), optional `description` (≤200), and `tags` (only meaningful when
  specialized). Surfacing/filtering is not built yet.
- **Group** — one of four colored categories in a puzzle. Colors: `blue, green,
  yellow, purple` (enum). Authoring/form order is blue→green→yellow→purple
  (swellgarfo muscle memory), *not* NYT difficulty order.
- **Attempt** — one play-through, keyed by a `player_token` cookie; also
  attributed to `user_id` when the player is logged in (ADR-0009). Logged-in
  players get **one attempt per puzzle** (partial unique index).
- **Tag** — a normalized hyphen-slug (`star-wars`) attached to taggables through a
  **polymorphic `taggings` join** (the `Taggable` concern). Canonical rows (not a
  jsonb array) so an admin can merge/rename; authors add them via a creatable
  autocomplete combobox. ADR-0010.
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
  Discovery metadata (ADR-0010): `specialized` (bool, default false), `description`
  (validated ≤ `DESCRIPTION_LIMIT = 200`, optional), and `include Taggable` →
  `has_many :tags, through: :taggings` with a `tag_names=`/`tag_names` accessor.
  See ADR 0001 + 0005 + 0008 + 0010.
- **Group** (`color` enum, `description`, `position`, `words`). `words` is a
  **jsonb** column (defaults to `[]`) — *not* a PG array, despite the PLAN
  sketch. `WORDS_PER_GROUP = 4`. `#filled_words` strips the blanks the form
  leaves. `description`/exactly-four-words validated only when the parent is
  published.
- **Attempt** (`player_token`, optional `user_id`, `solved`, `mistakes_count`,
  `guesses` jsonb, `achievement` enum). `belongs_to :user, optional:` — anonymous
  plays carry only a `player_token`; logged-in plays also attribute to the account,
  capped at one per puzzle by a partial unique index `(user_id, puzzle_id) WHERE
  user_id IS NOT NULL` (ADR-0009). Stats (emoji cube, common wrong guesses) derive
  from `guesses` — no extra tables. Each guess entry now carries a **`correct`**
  bool (was just `words`+`colors`) because trophies read the solve order off it.
  Indexed on `player_token`. **Trophies (ADR-0011):** `achievement` is an ordered,
  nullable enum (`perfect:1, purple_first:2, reverse_rainbow:3`, nil = none),
  computed in a `before_create` (`earned_achievement`) — only a flawless win (all
  solved, zero mistakes) scores. `at_least(tier)` scope = cumulative `>= n` count;
  `earned_tiers`/`quip_bucket` drive the awards view. The public play loop records
  these (the Stimulus `game_controller.js` POSTs to `play_attempts_path`).
- **PlayerStats** (`app/models/`) — value object for the "Your stuff" dashboard
  top block (ADR-0011): trophy counts (`at_least` per tier), played/solved/solve
  rate from an account's `attempts`, and a created count. Anonymous (`attempts:
  nil`) → `signed_in?` false, created-only. `AttemptsController#create` returns a
  server-rendered `play/_achievement` partial (trophies + quip + total/nudge) the
  game injects on game over; the `trophy(tier)` helper renders the fillable SVG.
- **Tag / Tagging / `Taggable`** (ADR-0010) — `Tag` (`name` unique). `Tag.normalize`
  → hyphen-slug; `Tag.for_name` find-or-creates (rescues `RecordNotUnique` → re-find
  for the concurrent-insert race). `Tagging` `belongs_to :taggable, polymorphic`
  (`taggable_type`/`taggable_id`, composite unique index with `tag_id`). The
  `Taggable` concern (`app/models/concerns/`) adds `has_many :taggings, as:`,
  `tags` through, and the `tag_names=`/`tag_names` accessor (normalizes + replaces
  the set). `Tag#puzzles` is scoped `source_type: "Puzzle"` for the future browse.
- **TagsController** — `GET /tags?q=` (public) returns JSON tag names matching the
  normalized query (`name LIKE %q%`, normalize strips LIKE metachars). Feeds the
  authoring autocomplete.
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
  Autosave fires on **`input` only** (not `change`, which fired on blur and
  double-saved); JS-driven field changes (the tag combobox) must **dispatch an
  `input` event** to be picked up.
- **`:has(:checked)` doesn't re-evaluate after a *programmatic* `.checked` change**
  — that's why the specialized toggle's reveal runs off a controller-managed
  `is-on` class instead (ADR-0010). Reach for the class pattern, not `:has`, when
  JS flips a checkbox.
- **Capybara `text:` sees CSS `text-transform`** — the brutal theme uppercases
  buttons/chips/status, so assert with a case-insensitive regex (`/saved/i`), not
  a literal `"Saved"`.
- **`hyphens: auto` needs `<html lang>`** — without it the browser has no
  hyphenation dictionary and silently falls through to `overflow-wrap: anywhere`
  (the orphan-letter board-tile wraps). The layout sets `lang="en"`.
- **Grid items that must shrink need `minmax(0, 1fr)`, not `1fr`** — plain `1fr`
  has an implicit `min-width: auto` (min-content), so a long unbreakable word
  expands its column and blows the layout out (`.m-board`).
- Never edit `app/assets/builds/` by hand; source is `application.scss`.
