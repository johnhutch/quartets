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
  yellow, purple` (enum integers blue:0…purple:3, unchanged). Authoring/form block
  order is **easiest→hardest** — yellow→green→blue→purple
  (`PuzzlesController::FORM_COLOR_ORDER`; the form **sorts by color at render**,
  not by stored `position`, so a color swap reorders on the next load). Authors
  can **swap two blocks' colors** from a legend menu (`colorswap_controller`).
- **Attempt** — one play-through, keyed by a `player_token` cookie; also
  attributed to `user_id` when the player is logged in (ADR-0009). Logged-in
  players get **one attempt per puzzle** (partial unique index). Carries the
  post-play **rating** (`quality`, `difficulty`).
- **handle** — a user's stable public slug (`/u/:handle`), minted from the email
  local-part at signup; `author_name` stays the free-text display name (ADR-0016).
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
  ADR-0005). **All validations are publish-only** — title, the 4×4 structural
  rules (`GROUPS_PER_PUZZLE = 4`, four distinct colors), and **no duplicate
  answers** (16 distinct words, case/whitespace-insensitive) fire only
  `if: :published?`.
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
  published. **Color uniqueness validates the in-memory sibling set**, not the
  DB — the authoring color-swap updates two groups in one nested save, and a
  DB-backed uniqueness check would 422 every swap against stale colors.
- **Attempt** (`player_token`, optional `user_id`, `solved`, `mistakes_count`,
  `guesses` jsonb, `achievement` enum). `belongs_to :user, optional:` — anonymous
  plays carry only a `player_token`; logged-in plays also attribute to the account,
  capped at one per puzzle by a partial unique index `(user_id, puzzle_id) WHERE
  user_id IS NOT NULL` (ADR-0009). Stats (emoji cube, common wrong guesses) derive
  from `guesses` — no extra tables. Each guess entry is `{words, colors}` (the true
  color of each picked tile); **correctness is derived, not stored** — see `Guess`.
  Indexed on `player_token`. **Trophies (ADR-0011):** `achievement` is an ordered,
  nullable enum (`perfect:1, purple_first:2, reverse_rainbow:3`, nil = none),
  computed in a `before_create` (`earned_achievement`) — only a flawless win (all
  solved, zero mistakes) scores. `at_least(tier)` scope = cumulative `>= n` count;
  `earned_tiers`/`quip_bucket` drive the awards view. The public play loop records
  these (the Stimulus `game_controller.js` POSTs to `play_attempts_path`).
  **Ratings:** nullable prefixed enums `quality` (`yeah:1, hell_yeah:2` —
  positive-only) and `difficulty` (`pretty_easy:0…cursed:3`, cursed renders as
  `@!#?@!`), set post-play via `PATCH /p/:token/rating` (`RatingsController` —
  resolves the viewer's attempt like the revisit view, published puzzles only,
  re-rating overwrites). The `play/_rating` block rides the finished-play JSON
  + the revisit view (`rating_controller.js`).
- **Guess** (`app/models/`) — value object owning the guess-log shape (jsonb, so
  string keys from JSON, symbol keys in tests; it's the one place that normalizes
  both). `#colors`/`#words`, and the **derived** Connections rule: `#correct?` =
  all picked tiles share one color (`colors.uniq.size == 1`), `#wrong?` = they span
  groups, `#solved_color` = that shared color. Reached via **`Attempt#guess_log` →
  `Array<Guess>`**. `EmojiCube` (colors→squares), `PuzzleStats#common_wrong_guesses`
  (`#wrong?`/`#words`), and `Attempt#earned_achievement` (`#solved_color` → solve
  order) all consume `Guess` — none poke at the raw hash. The producer
  (`game_controller.js`) records only `{words, colors}`.
- **PlayerStats** (`app/models/`) — value object for the "Your stuff" dashboard
  top block (ADR-0011): trophy counts (`at_least` per tier), played/solved/solve
  rate from an account's `attempts`, and a created count. Anonymous (`attempts:
  nil`) → `signed_in?` false, created-only. `AttemptsController#create` returns a
  server-rendered `play/_achievement` partial (trophies + quip + total/nudge) the
  game injects on game over; the `trophy(tier)` helper renders the fillable SVG.
- **PlayResult** (`app/models/`) — value object owning the finished-play payload:
  `#cube`, `#share` (composes `EmojiCube` + `ShareText`), `#achievement` (the tier),
  and `#awards_locals` (the `play/_achievement` locals — folds the top-trophy
  `#total` count for a signed-in winner, else nudge). `PlayResult.new(attempt, url:,
  viewer:)` — `url` handed in for the request host, `viewer` is `current_user`/nil.
  Consumed by **both** `AttemptsController#create` (JSON the game injects) and the
  revisit `play/_result` view, so the shaping lives once. Pure PORO — recording and
  ERB rendering stay in the controller/view.
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
  no `show` action/view — the public board is `play#show`. Autosave's first `create`
  returns 201 JSON (`patch_url`, `publish_url`, `group_ids`) so the form flips to
  PATCH and **reveals + wires its Publish button without a reload** (a new puzzle has
  no id at render, so Publish starts `hidden`/unwired); once `complete?`, Publish is
  the loud CTA and Save reads "Keep it unlisted (link only)" (ADR-0008).
- **HomeController** — the public front door (`GET /`, includes `AnonymousPlayer`).
  A **launchpad, not a play surface** (ADR-0014): `@puzzles` is a random strip of
  ≤`STRIP_SIZE` (5) **published, non-`specialized`** puzzles (themed quartets
  aren't a fair random jump-in), with `@completed_ids` for the signed-in
  `.m-check` flags. No board, no featured/unplayed logic, no embedded game. Still
  mints the `player_token` cookie via `AnonymousPlayer`. The layout suppresses the
  global topbar + footer on home only via the `home_page?` helper — home fronts
  its own nav (the hero's Create sticker + archive link, `aria-label="Primary"`;
  the old Create/Play fork is gone) and footer-as-section. All homepage copy is
  in `en.yml` under `home.*`.
- **User / UsersController / Admin (ADR-0016)** — `User` has `handle` (unique,
  minted from the email local-part in a `before_validation` on create, stable
  thereafter), `superuser` (bool, console-anointed), and Devise **`:trackable`**
  (last-login for the admin users tab). Public **`GET /u/:handle`**
  (`UsersController#show`, 404 on unknown handle): published puzzles +
  `PlayerStats` (created = published count only). `author_link(puzzle)` renders
  every byline — linked to `/u/:handle` when the puzzle has an account owner,
  plain text for cookie-owned. **`/admin`** (`Admin::BaseController`, 404 unless
  superuser): a puzzles tab rendering the shared `puzzles/_row` partial for
  *every* puzzle (the member actions pass because `PuzzlesController#set_puzzle`
  resolves via `accessible_puzzles` — `Puzzle.all` for superusers) and a users
  tab (last login, created/solved counts), both offset-paginated, tab-toggled.
- **Auth concerns** (`app/controllers/concerns/`) — `Creator` (cookie ownership +
  `owned_puzzles` + the `owns?` view helper), `ClaimsPuzzles` (site-wide
  `before_action`: on the first authenticated request, reassigns the cookie's
  puzzles to the account and clears the cookie), `AnonymousPlayer` (the
  `player_token` for stats). The play gate (ADR-0008 + 0015) lives in the
  **`Playability`** policy object (`app/models/`): `Playability.new(puzzle, owner:)`
  — `#playable?` (= exists && `complete?` && **not yours** — ADR-0015) and `#status`
  (`:playable` / `:owned` = complete-but-yours, shown revealed / `:editable` =
  incomplete-but-owned / `:missing` = unknown token or incomplete-to-a-stranger).
  `PlayController#show` maps `status` → response (`:owned` renders
  `play/_revealed` — the solved rows + a Share button, no game; `:editable`
  redirects the owner to the editor; `:missing` 404s); `AttemptsController#create`
  gates on `#playable?` **with the owner flag** (an owner POST 404s — no
  self-earned trophies/stats) and attributes the attempt to `current_user` when
  signed in, idempotently (ADR-0009). For a player who has already finished a
  puzzle, `show` renders `play/_result` — the **reconstructed game-over board**
  (groups in solve order from `attempt.solved_colors`, win/loss stamp, cube +
  trophies, the rating block) — instead of a fresh board (ADR-0012). The finished
  attempt is looked up by account when signed in, else by `player_token`
  (`PlayController#finished_attempt`). `index` marks completed puzzles with the
  `.m-check` square + dims the row, **auto-hides your own puzzles** and offers a
  signed-in filter fold-out (`hide_mine` default on / `hide_completed` default
  off — plain GET params, nothing persists; `filters_controller` auto-submits).

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
- **`Multicolor` breaks string contiguity** — a multicolored title never appears
  as one substring in the raw HTML (3–6-letter spans). Request specs asserting
  visible copy on multicolored surfaces use the **`page_text`** helper
  (`spec/support/page_text.rb`, Nokogiri text), not `response.body.include?`.
- **An explicit `display` beats the UA `[hidden]` rule** — any hidden-by-default
  element that also sets `display:` needs a `&[hidden] { display: none; }`
  restatement. This has bitten three times (publish tooltip, color-swap menu,
  clearable ×).
- **Board tiles fit long words by shrinking, not hyphenating** — `game_controller`
  sets a per-tile `--card-fit` scale (`cardFit`, keyed off the longest word) and
  `.m-card` font is `calc(clamp(...) * var(--card-fit, 1))`, so a name that has no
  hyphenation dictionary entry shrinks to fit instead of snapping an orphan letter.
  `hyphens: auto` + `overflow-wrap: anywhere` (which need `<html lang>`, set in the
  layout) remain only as the last-resort fallback.
- **Grid items that must shrink need `minmax(0, 1fr)`, not `1fr`** — plain `1fr`
  has an implicit `min-width: auto` (min-content), so a long unbreakable word
  expands its column and blows the layout out (`.m-board`).
- **Meta description is structural** — the layout always emits
  `<meta name="description">` from `content_for(:description)` (falling back to
  `ApplicationHelper::SITE_DESCRIPTION`), *outside* the `content_for(:meta)` branch.
  A page sets its own SEO description by `content_for :description, ...`; `play#show`
  uses `puzzle_meta_description(@puzzle)` (author blurb, else generated fallback)
  and reuses it for the `og`/`twitter` tags. Don't put `name="description"` back
  inside a `:meta` block.
- Never edit `app/assets/builds/` by hand; source is `application.scss`.
- **`public/` caching is split** (production): `public_file_server.headers` gives
  everything a 1-year cache (correct for digest-stamped `/assets/`, which are
  immutable), but the `ShortLivedLoosePublicFiles` middleware (`production.rb`)
  downgrades the **loose mutable files** — `robots.txt`, favicon, `share.png` — to
  1 hour. Don't re-pin those for a year: a CDN/browser will serve a stale
  `robots.txt` for a year (the bug that hid the AI-bot robots.txt at the edge).
