# Progress

**Last updated:** 2026-07-08
**Active branch:** develop (clean; the ADR-0018 punch list + rich seeds are committed and QA'd; `main` is prod/deploy)

Current state + a rolling shipped-log. Planned/not-started work lives in `TODOS.md`; the *why* behind decisions lives in `DECISIONS.md`.

---

## Current focus

The app plays **end-to-end** — author → publish → share link → play → stats →
emoji cube — and the brutalist design now covers the whole site. Phases 0–4 are
done; Phase 5 (import + export) is mostly there.

The **auth & accounts epic is now fully shipped** (ADR-0005 + ADR-0016): creation
is public, anonymous authors own their work via a `creator_token` cookie, signing
in/up claims it, the Devise flows are on-theme, and the once-deferred D3 landed —
every account has a stable **`handle`** and a public **`/u/:handle`** page (published
puzzles + stats), with bylines linked site-wide. The **superuser role + `/admin`**
(puzzles & users tabs) also exists (ADR-0016). The once-planned dashboard
aggregate stats table was **called Good Enough as-is** (per-puzzle Stats links
cover it — closed 2026-07-08). Deploy is **live** — push to
`main` builds + ships to GHCR and Watchtower recreates `web` on the NAS, with a
Caddy front proxy so the restart no longer 502s (ADR-0006 + ADR-0007). Still
outstanding: real SMTP creds in the NAS `.env` for forgot-password mail.

The **visibility model shipped** (ADR-0008): "draft" retired into *incomplete*
(derived from `complete?`) vs *unlisted* (complete but off the site, playable by
anyone with the link) vs *published*. Still in flight separately: the **slug
migration** (name + random-suffix play URLs) — see the TODOS reminder.

The **discovery-authoring half shipped** (ADR-0010): a `specialized` flag
(Classic by default), creatable autocomplete **tags** (polymorphic), and a 200-char
**description** are now captured on the authoring form. **Surfacing is now half
built (ADR-0018):** a THEMED chip with a tag fold-out on the archive + jump-in
rows and inline tags on the show page, plus a description **spoiler fold-out**
on `play#show`. Still unbuilt: tag *links*/filtered browse, the `/play` classic
toggle, and search (see TODOS).

**Analytics is scoped, not built** — a full privacy-first plan (streams A traffic
/ B product funnels / C error tracking + bot/crawler measurement) lives in the
TODOS Analytics section; the superuser/admin dashboard that gated B and C now
**exists (ADR-0016)**, so those are unblocked. The
**AI-bot stance shipped** as a hand-owned `public/robots.txt` (allow
search/citation crawlers, block training crawlers) backed by Cloudflare's "Block
AI bots" rule. **CLS is now eliminated** and the **play window got a full polish
pass** (animations, floating toast, color mistake-boxes, per-tile font-fit — see
shipped log). The next big threads: the **analytics build** (now unblocked) and
the deferred **discovery surfacing**.

The **homepage launchpad is merged and reworked again** (PR #19 + follow-ups): a
masthead hero (no more Create/Play fork), a centered jump-in strip, and the whole
page width-constrained to the subpages' column. The **category palette is ours
now** (ADR-0017): soft pastels in the Connections register but deliberately
**never NYT's exact hexes** (trade-dress risk), with ≥8:1 contrast both ways.
**Play rules changed:** owners can't play their own puzzles (ADR-0015) — now
enforced on the browse surfaces too (strip + archive hide-mine cover accounts
*and* anonymous creator cookies, ADR-0018) — wrong guesses stay selected with a
duplicate-guess guard, and finished plays can be **rated** (quality +
difficulty; aggregates now display on browse rows, the strip, and the show page
via `RatingSummary` — the stats-page slice is still TODO). A
**toggleable theme-skins plan** (`8bit` + `broadsheet` over the `brutal` default)
is written to `docs/THEMES.md` on its own branch — scoped, not built.

## Shipped log (most recent first)

- **Site-wide review pass — nine fix batches (`code-review` branch).** A
  five-lane Fable review (domain, controllers/security, views/perf, JS, cruft)
  surfaced two critical bugs, a security/integrity cluster, and a pile of
  medium/low items; all actioned. **Critical:** stored XSS in the game's
  solved-row render (author text hit `innerHTML` — now `textContent`); homepage
  strip showed rating badges for a *different* random 5 puzzles (RANDOM()
  relation re-rolled as a subquery — `RatingSummary.for` now keys off concrete
  ids). **Security/integrity:** the public attempts endpoint trusted the client
  wholesale (forgeable trophies/stats) — new `PlayRecording` rebuilds the play
  from the puzzle, trusting only the words grouped; Rails 8 `rate_limit` on all
  public write endpoints; `turbo-cache-control` no-cache stops the back button
  resurrecting a finished board. **Medium:** hybrid **soft-delete** (ADR-0019 —
  played puzzles tombstone, unplayed hard-delete, admin restore); list-page
  N+1s (grouped `play_counts_for`); tag writes moved to `after_save` (were
  committing on failed saves + spawning junk Tag rows); dup-answer validation
  gated on `complete?` not `published?`; the signed-in creator-cookie ping-pong;
  the `RecordNotUnique` 500 on duplicate attempt POSTs. **Low/polish:** autosave
  disconnect-flush + double-create guard, toast/share/clipboard papercuts,
  `/play` pagination + `(status, created_at)` index, single-query `PlayerStats`,
  handle-race retry, NULL-`guesses` hardening. **Cruft:** deleted the Obsidian
  import chain, `hello_controller`, dead CSS, disabled-module Devise views,
  `bin/ci`; dropped jbuilder/image_processing/thruster; SHA-tagged deploy images
  + rollback runbook; enabled the password-change notification; fixed the
  CLAUDE.md "no models yet" lie. Also **SMTP via Resend** wired (docs + env) and
  the **PWA manifest** shipped (installable home-screen app). Green throughout.

- **Stats expansion — owner page, dashboard, admin (item 3 of the launch punch
  list).** `PuzzleStats` grew median/fastest solve time (`duration_ms`),
  flawless count, cumulative trophy tallies, and **common solve orders**
  (full 4-color paths, rendered as category-color chips); the owner stats page
  gained those sections plus the **`RatingSummary` block** (thumbs + difficulty
  meter — closes the TODOS "stats-page slice"). The dashboard got an **"Out in
  the world"** author bar (new `AuthorStats`: plays, crowd solve rate, thumbs,
  voted difficulty across all your puzzles — puzzle-scoped, so anonymous authors
  see it too). Superuser-only: the admin puzzles tab rows carry a funnel line
  (new `EngagementStats`: distinct starts vs attempts → abandons + rate, median
  time-to-first-group off the guess-log `t`). New `clock_ms` helper. Earlier the
  same day: **common wrong guesses render as category-colored chips**
  (word+color pairs through `common_wrong_guesses`, `.m-guess-tiles`; black text
  ≥9:1 on all four fills). 395 green; phone-width screenshots verified.

- **Seeds now replicate the prod experience (dev-only layer).** `db/seeds.rb`
  grew a development-gated community-fixture layer on top of the env-agnostic
  superuser + Demo set: a cast of owners (named account, handle-less account,
  pure player "Speedrun Sally", anonymous `seed-anon-creator` cookie), puzzles
  in every state (themed+tagged+described, unlisted-complete, incomplete drafts,
  anonymous published, a long-word tile-fit stress test), and plays built from
  **real guess logs** so the derived data is genuine — all three trophy tiers,
  weighted ratings (incl. a hell-yeah-AND-cursed puzzle), a repeated common
  wrong guess, per-guess timings, and `game_started` events with two abandons.
  Idempotent (re-run changes nothing); prints a dev-login cheat sheet. The Demo
  layer also gained two descriptions + asserts `superuser: true` on the admin.
- **Play-surface punch list (ADR-0018).** Four features in one pass, full TDD
  (377 green). **Description spoiler toggle:** `play#show` folds the author's
  blurb behind a native `<details>` ("View description (warning: may contain
  hints or spoilers!)", `.m-description`), all three page states. **Rating
  aggregates:** new `RatingSummary` value object — SUM(quality) is the weighted
  thumb count (enum ints are the weights), AVG(difficulty) rounds to its label —
  rendered by a shared `play/_rating_summary` partial on archive rows, the
  jump-in strip, and under the show-page byline; one grouped query per list;
  unrated renders nothing; `_rating.html.erb`'s inline label hash moved to
  `RatingSummary::DIFFICULTY_LABELS`. **THEMED flag:** purple tilted chip
  (`.m-themed`) on all three surfaces; list rows get a `<details>` tag fold-out
  (tap + hover), show page lays tags inline (inert — tag links still TODO); the
  strip's `where(specialized: false)` exclusion is gone, flag replaces it.
  **Owned-puzzle filtering:** shared `Puzzle.not_owned_by(user:, creator_token:)`
  scope excludes your own puzzles from the strip outright and powers the
  archive's hide-mine for accounts *and* anonymous creator cookies; the filter
  fold-out shows for anyone with something to filter (hide-completed stays
  signed-in-only). Verified live at phone width (selenium screenshots + curl
  cookie-jar probes); runtime recipe persisted to `.claude/skills/verify/`.
- **Category palette settled — ours, never NYT's (ADR-0017).** After four variants
  (emoji-signal, hot print, warning-label, threat-scale), landed on soft pastels in
  the Connections register with deliberately distinct values (`#f2c94c`/`#8ed081`/
  `#8db4f2`/`#cf9bdb` in `_variables.scss`, the single source): golden-vs-butter,
  mint-vs-olive, sky-vs-periwinkle, lilac-vs-orchid. ≥9:1 black-on-fill, ≥8:1 as
  text on the dark page. Propagates to the trophy gradient (`RAINBOW_BANDS`),
  styleguide, favicon set (`tmp/brand/build_favicon.py`), and `share.png` (new
  regenerable source `tmp/brand/share.html`, Chrome-rendered; OG meta at `?v=4`).
  On-page emoji cubes now render as **CSS blocks in our palette** (`cube_grid`
  helper + `renderShare`); raw 🟨🟩🟦🟪 live only in the copied share text.
- **User pages + superuser admin (ADR-0016, settles D3).** `users.handle` (unique,
  minted from the email local-part, stable) → public **`/u/:handle`** (published
  puzzles + PlayerStats block); bylines link there site-wide (`author_link`).
  `users.superuser` gates **`/admin`** (404 to everyone else): a puzzles tab
  (everyone's puzzles, the shared `puzzles/_row` owner-grade actions —
  `set_puzzle`'s `accessible_puzzles` waves superusers through) and a users tab
  (last login via new Devise **trackable**, created/solved counts), tab-toggled,
  paginated. Anoint via console: `user.update!(superuser: true)`.
- **Post-play ratings.** Quality ("was this a good one?" — 👍 Yeah! / 👍👍 Hell
  yeah!, positive-only) + difficulty (pretty easy → `@!#?@!`) as nullable enums on
  **Attempt** (one finished play = one vote, anonymous included; re-rating
  overwrites). `PATCH /p/:token/rating` + `rating_controller.js`; the block rides
  the finished-play JSON and the revisit view, **published puzzles only**. Display
  of aggregates is TODO.
- **Archive cleanup (logged-in).** Completed rows get a full-height flush-right
  green **check square** (`.m-check`, shared with the jump-in strip) and dim to
  55%; bylines stack under titles. **Your own puzzles are auto-hidden**, with a
  fold-out **Filter** (funnel icon → hide-mine default-on, hide-completed
  default-off; plain GET params, nothing persists). Jump-in rows restructured
  (div, not nested anchors) after byline links broke them.
- **Owners can't play their own puzzles (ADR-0015).** `Playability` gained
  `:owned`; owners see the board **revealed** (`play/_revealed` + a Share button)
  instead of playable, and `attempts#create` refuses owner posts — no self-earned
  trophies or stats. Reverses ADR-0009's "owners never gated".
- **Wrong guesses stay selected.** A miss wiggles but no longer deselects — the
  player clears tiles themselves (tap-by-tap or Deselect all). Companion guard:
  resubmitting any already-guessed-wrong set toasts "You already made that guess"
  instead of burning a mistake.
- **Authoring form UX pass.** Bigger inputs (≥16px kills iOS focus-zoom), more
  tap-space between fields, blocks reordered **easiest→hardest** (yellow→purple,
  `FORM_COLOR_ORDER` now drives render order, not stored position), a per-block
  **color-swap menu** (pencil in the legend → exchange colors with another block,
  recolors in place with a bg transition, reorders on reload; `colorswap`
  controller), an in-box **clear ×** on every text input (`clearable` helper +
  controller), and focus that **pops like a board tile** (lift + house hard
  shadow, no CLS). `Group` color uniqueness now validates the in-memory sibling
  set (a swap 422'd against stale DB colors); publish-time **duplicate-answer
  validation** (16 distinct words, case/space-insensitive) — the `:complete`
  factory now builds distinct words per group.
- **Share buttons use the native share sheet.** `share_controller.js`:
  `navigator.share({url})` when available (iOS composes a real rich link — a
  pasted URL often doesn't unfurl), clipboard fallback on desktop. Bare URL only;
  "Copy result" stays clipboard (text + link never unfurls, the Wordle pattern).
- **Board rows no longer grow as groups solve.** The CLS min-height reservation
  now tracks live rows (`--rows` var set by `render()`) instead of stretching the
  remaining tiles. Tile text bumped to `clamp(0.75rem, 3vw, 1.2rem)`.
- **Brand refresh.** Favicon rebuilt: normal-weight Space Grotesk Q over 2×2
  color quadrants, rounded corners (`tmp/brand/build_favicon.py`, fontTools-based).
  Stamp padding bumped; revisit-view stamp was invisible (overlay defaults outside
  `.m-game`) — fixed. `$brutal-muted` brightened (`#bcb8ae`, ~9:1).
- **Homepage follow-ups (post-merge).** Hero reworked to a **masthead** (fork
  retired — Jump In *is* Play; sticker CTA + quiet archive link carry the Primary
  landmark, tilted Q-quadrant cluster for color). Whole page width-constrained to
  the subpages' column (`$brutal-container`/`$brutal-column`, padding-based so
  bands stay full-bleed; winboard bleeds via `50% − 50vw`, mobile included).
  Strip band centered w/ pinstripe bg; manifesto + footer on a shared
  etched-panel mixin; jump-in filters out `specialized` puzzles and flags
  completed ones; auth chip uses the topbar's outline buttons. The old
  "today's puzzle" home (dropped you into a featured/unplayed board) is replaced by
  a launchpad of full-bleed color bands: a hero, a two-color **Create/Play fork**
  (carries the `Primary` nav landmark), a random **jump-in strip** of ≤5 published
  puzzles (`HomeController::STRIP_SIZE = 5`, `RANDOM()`), a **"Why play here"** pitch
  with a solved-board + reverse-rainbow-trophy + emoji-cube graphic, and a
  **manifesto footer-as-section**. Topbar + global footer are suppressed on home
  only (new `home_page?` helper). **All homepage copy lives in `en.yml`** under
  `home.*`. `home_spec.rb` rewritten to the new contract (no embedded game, no login
  wall, published-only strip, caps at STRIP_SIZE, mints player_token);
  `navigation_spec` + `pages_spec` retargeted to `/play` (topbar + global footer now
  live only on sub-pages); `accessibility_spec` unchanged (home keeps skip link,
  `main#main`, one named `<nav>`). 282 green.
- **Theme-skins plan (`docs/theme-skins-plan` branch, docs only).** Scoped a
  toggleable skin system in `docs/THEMES.md` for logged-in users: a CSS
  custom-property refactor of the brutalist theme **first**, then `8bit` (arcade)
  and `broadsheet` ("The No Times" NYT parody) as thin override layers on the
  `brutal` default, a `users.theme` column + settings picker, self-hosted per-theme
  fonts. ADA stance: keep the AA default, engineer both skins to AA, gate
  un-fixable CRT/scanline effects behind `prefers-reduced-motion` / `prefers-contrast`
  / `forced-colors` — a warning label is **not** a compliance substitute. Standalone
  visual comps (8-bit full app + broadsheet homepage) built during the session, kept
  out of the repo. No code.
- **Short-cache mutable `public/` files (CDN fix).** `public_file_server.headers`
  pins everything in `public/` for a year — right for digest-stamped `/assets/`,
  wrong for loose files like `robots.txt`/favicon, which got stranded **stale at
  Cloudflare for a year** (that's why the new robots.txt didn't show live). New
  `ShortLivedLoosePublicFiles` middleware (`production.rb`) downgrades just those
  paths to a 1-hour cache; hashed assets keep their immutable year. **Pending: this
  is on `develop` — needs to reach `main` (deploy) + a one-time Cloudflare purge of
  `/robots.txt` to clear the already-pinned copy.**
- **Homepage footer-button trim** — removed a couple of unnecessary homepage footer
  buttons. (Heads-up: a **full homepage rework** is imminent per the author, so
  don't over-polish the current one.)
- **Play-window polish pass.** Title→byline tightened; the wrong-guess message is
  now a floating auto-dismiss **toast** over the header (no reserved row); the
  win/lose **stamp** flows under the solved rows (game-over no longer leaves a tall
  empty board — `.m-game.is-over` collapses `.m-board` min-height + un-absolutes
  `__status`). **Mistakes remaining** is white caps + four white boxes that take a
  color-coded ✕ per wrong guess. Controls clamp to one row (`nowrap` + clamped
  font). Dropped the "Share this quartet" button. "More quartets" → a tilted blue
  **Archive** CTA (+ nav "Play More" → "Archive"). **Long tile words shrink to
  fit** via a per-tile `--card-fit` scale (game_controller `cardFit`, keyed off the
  longest word) instead of breaking mid-word.
- **Shuffle + deselect animations.** Shuffle now **FLIP-slides** tiles to their new
  cells (reuses the live elements, WAAPI `composite:"add"` so a lifted selection
  survives) instead of popping. Deselect-all **cascades** (~0.05s stagger), reusing
  the un-click settle; a wrong guess **wiggles** the picked tiles then settles them
  down. All honor `prefers-reduced-motion`.
- **Cumulative Layout Shift eliminated.** Reserved the board's 4-row height up
  front (`.m-board` min-height) so JS-injected tiles don't reflow the page, and
  **preloaded the Space Grotesk woff2** (both weights) to kill the font-swap
  reflow. Mobile CLS: game 0.33→0.01, home 0.17→0.00 (verified via Lighthouse).

- **AI-bot policy + analytics plan.** Hand-owned `public/robots.txt` (single source
  of truth — Cloudflare's managed robots.txt to be set to "Disable"): allow AI
  search/citation crawlers (`OAI-SearchBot`, `PerplexityBot`, …), block AI training
  crawlers (`GPTBot`, `CCBot`, …) + a `Content-Signal: search=yes, ai-train=no`;
  Cloudflare "Block AI bots" rule is the enforcement layer. Footer brags about it.
  The full privacy-first **analytics plan** (A/B/C + bot measurement) was grilled
  and written into TODOS — designed, not built.
- **`bin/dev` stopped spewing rdoc warnings.** Swapped the foreman check from
  `gem list foreman` (which loads RubyGems plugins → two installed rdoc versions
  double-init → warning wall) to a plain `command -v foreman` PATH lookup.
- **Per-page meta descriptions (SEO).** Every page now emits
  `<meta name="description">` — site default, or per-puzzle: the author's
  `description` blurb when present, else a generated spoiler-free fallback
  (`puzzle_meta_description` helper). One string feeds name/`og`/`twitter` so SERP
  + social cards agree (replaced `play#show`'s hardcoded "Play this puzzle by X" OG
  line). Description is **structural** — hoisted out of the `content_for(:meta)`
  branch and driven by `content_for(:description)`, so coverage never depends on
  per-page discipline. 4 request specs; Lighthouse SEO 91→100.
- **WCAG 2.1 AA pass — Lighthouse 95→100 (ADR-0013).** Full audit, then fixed the
  real gaps: muted text moved off the light-theme `$color-muted` onto
  `$brutal-muted` + dropped the footer-disclaimer opacity (contrast); skip link +
  `<main>` landmark; global `:focus-visible` ring; `aria-label` on the 16 answer
  inputs; `role`+`aria-live` on flash; `prefers-reduced-motion` flattening
  tilt/lift; named the two `<nav>`s. Standing bar tracked in
  `docs/ACCESSIBILITY.md`; semantics pinned by `spec/system/accessibility_spec.rb`
  (contrast/motion verified via Lighthouse, not RSpec). `/styleguide` swatches +
  the emoji cube are documented exemptions.
- **Home falls back to an unplayed puzzle.** With nothing featured, `home#show`
  serves a random *published* puzzle you haven't finished (by account, else
  `player_token`); cleared the whole board → a snarky empty state that sends you to
  make one. Featured path unchanged.
- **Publish from the create screen.** The authoring form now reveals + wires its
  Publish button the moment autosave mints the record (was edit-screen only —
  gated on `persisted?`); the save button reads "Keep it unlisted (link only)" once
  complete (ADR-0008). Needed `.m-tooltip[hidden] { display: none }` since the
  tooltip's `display` otherwise beat the UA `[hidden]` rule.
- **Play gate → `Playability` policy object** (architecture review candidate 3).
  ADR-0008's "playable iff `complete?`" rule + the owner-redirect/404 trichotomy,
  previously mirrored across `play#show` and `attempts#create`, now live in
  `Playability.new(puzzle, owner:)` (`#playable?`, `#status` → `:playable` /
  `:editable` / `:missing`). `show` maps status→response and dropped its
  `find_by!`/rescue; `create` gates on `#playable?` (no owner branch).
- **Finished-play result → `PlayResult`** (architecture review candidate 2). The
  cube/share/achievement/total/awards-locals shaping, duplicated across
  `attempts#create` (JSON) and `play/_result` (revisit HTML), collapsed into one
  presenter `PlayResult.new(attempt, url:, viewer:)` (composes `EmojiCube` +
  `ShareText`). Recording + ERB rendering stay in the controller/view.
- **Finished-state on revisit, not redoable (ADR-0012).** Revisiting an
  already-played puzzle reconstructs the game-over board — groups in *your* solve
  order (`Attempt#solved_colors`), win/loss stamp, cube + trophies — instead of a
  fresh board. Gating extended to **anonymous** players by `player_token` (amends
  ADR-0009's "anon stays replayable"); owners stay ungated.
- **Guess log → `Guess` value object** (architecture review candidate 1). The
  `guesses` jsonb shape + key-normalization + the "correct?" rule, previously
  re-implemented in `EmojiCube`/`PuzzleStats`/`Attempt`, now owned by one `Guess`
  (`#colors`/`#words`/`#correct?`/`#wrong?`/`#solved_color`), reached via
  `Attempt#guess_log`. Correctness is **derived** from colors, so the stored
  `correct` flag was dropped from the producer + permit.
- **Mobile hamburger nav + arrow fix.** Topbar collapses below `$bp-nav` to a
  CSS-only `<details>` hamburger (Create yellow-tilted inside, hidden on the
  authoring page; the page's redundant Create sticker hides on mobile). The `↗`
  glyph is pinned to text presentation via U+FE0E (`ne_arrow` helper) so iOS
  stops rendering it as an emoji block.
- **Reverse-rainbow authoring order + stay-logged-in default.** New-puzzle form
  blocks build purple→blue→green→yellow (`PuzzlesController::FORM_COLOR_ORDER`);
  the login "Stay logged in" checkbox defaults checked.
- **Trophies shipped (ADR-0011).** Flawless wins earn one of three nested tiers —
  perfect → purple-first → reverse-rainbow — counted cumulatively off a new ordered
  `achievement` enum on Attempt (computed in `before_create`; `at_least` scope for
  counts). Game over shows the earned trophies + a random snarky quip (5 buckets in
  `en.yml`) + a top-trophy total (logged-in) or sign-up nudge (anon, since their
  attempts are uncapped/farmable). The "My quartets" nav/dashboard became **"Your
  stuff"** with a trophy case + Played · Solved · Solve rate · Created stat row
  (`PlayerStats`). Custom fillable `trophy(tier)` SVG (ink / purple / striped
  gradient). Solve order drives the tier (later: derived from the guess colors via
  `Guess`, see below). Streak stat is deferred until the daily-puzzle frontpage.
- **Board tiles wrap cleanly — no more orphan-letter breaks.** Long answers now
  hyphenate at syllables instead of breaking anywhere: the fix was `<html lang="en">`
  (without a `lang`, `hyphens: auto` silently does nothing and falls through to
  `overflow-wrap: anywhere`). `.m-card` keeps a `clamp()` font + `hyphens: auto`;
  `.m-board` uses `repeat(4, minmax(0, 1fr))` so a long unbreakable word can't blow
  its column out. All CSS — a JS shrink-to-fit attempt was tried and reverted.
- **Quartet specificity & discovery — authoring half (ADR-0010).** `Puzzle` gained
  `specialized` (bool, default false = "Classic") + `description` (≤200). New
  polymorphic **tags/taggings** (`Taggable` concern, `Tag.normalize` → hyphen-slugs,
  race-safe `for_name`) + a `GET /tags` autocomplete endpoint. Authoring form: a
  big chunky **"YES" toggle** (lifts/colorizes like a board tile) reveals a
  **creatable tag combobox** (`tags_controller`) + a 200-char description with a
  live counter (`charcount_controller`); a `specialized_controller` guards
  un-toggling (confirm → slide chips up → collapse the box, driven by an `is-on`
  class, not `:has`). Polish: form capped at `$form-width` (~half), autosave status
  is a top bar (yellow→green, auto-hides 1.5s, black text for WCAG), autosave fires
  on `input` only (not blur), tag box stacks under YES below `$bp-stack`. 195 green.
- **UI says "quartets" + "Play More Quartets" nav button.** Swept the user-facing
  chrome — nav items, action buttons, back-links, page titles + `<h1>`s — from
  "puzzle" → "quartet" (the `Puzzle` model/table/routes are untouched; body/
  marketing copy still says "puzzle"). Added a "Play More Quartets ↗" button beside
  the wordmark (`l-topbar__brand`; header now wraps on a phone). Unlisted-complete
  puzzles also gained Share buttons on the dashboard + owner preview. 169 green.
- **One play per logged-in user + result view (ADR-0009).** `Attempt` gained an
  optional `user_id`; logged-in plays attribute to the account and are capped at
  one per puzzle (partial unique index; `attempts#create` idempotent). Win or
  loss uses it up. Revisiting a finished puzzle (signed-in non-owner) shows a
  **result view** — emoji cube + revealed answers + Share — instead of a
  replayable board; `/play` badges completed puzzles ("✓ Played"). Owners never
  gated on their own puzzles; anonymous play unchanged. TDD, 168 green.
- **Visibility model — "draft" retired for unlisted/published (ADR-0008).**
  `status` enum is now visibility (`unlisted` default / `published`, zero data
  migration); *playability* is derived from `#complete?`. `play#show` and
  `attempts#create` gate on `complete?` — a finished puzzle plays for anyone with
  the link, listed or not; incomplete ones redirect the owner to the editor and
  404 strangers. Unlisted play pages carry `noindex` but keep OG tags so links
  still unfurl. Editor finish moment: prominent **Publish to the site** vs
  **Keep it unlisted (link only)** (no auto-publish). Dashboard pills:
  Incomplete / Unlisted / Published; unpublish → unlisted. Full TDD, 162 green.
- **Deploy automated + made zero-downtime-ish (ADR-0006, ADR-0007).** Push to
  `main` now builds the image via GitHub Actions and pushes to GHCR; Watchtower on
  the NAS polls and recreates `web` (killed the old SSH `bin/deploy`). To stop the
  ~10-15s 502 while `web` restarts on the slow box, a **Caddy** proxy fronts the
  app (`Caddyfile`, `lb_try_duration 25s`) and cloudflared targets it (tunnel →
  caddy → web). Watchtower is scoped via label to cycle **only** `web`, so the
  proxy/db/tunnel stay up across deploys. Set the tunnel hostname → `caddy:80`.
- **Brand assets — favicon + social share.** Multicolor "Q" favicon (transparent,
  four puzzle-color quadrants, heavier bowl + lean tail) and a `share.png` (1200×630):
  QUARTETS on a random 4-color mosaic with a thick black outline, site-matched
  kerning. Generated from Space Grotesk Bold (`tmp/brand/build.py`); OG/Twitter
  meta wired in the layout with explicit image dimensions.
- **Selected tiles lift + tilt (animated).** Picking a tile now plucks it up off
  the grid and rotates it a little (random −3°…+3° per tile, via a `--tilt` CSS
  var) with a springy overshoot, instead of pressing down. The motion only worked
  once selection stopped rebuilding the whole board — `game_controller#toggle`
  flips `is-selected` on the **live element** (a rebuilt tile pops in
  already-selected, so a transition has no "before" state). play_spec green.
- **Game over hides the play controls.** Once the game's won/lost, the
  shuffle/deselect/submit row is gone (`game_controller` adds `is-over` →
  `.m-game.is-over .m-game__controls { display: none }`); the post-game share +
  cube stay. play_spec asserts the controls retire.
- **Grid-breaking "stamp" — extended the tilted-sticker language.** Added a bigger
  sibling to `.m-sticker`: **`.m-stamp`** (`--lose` variant) — a loud, tilted,
  hard-shadow slab for *climactic* moments only. Placed at the **game end-state**
  (`game_controller` slaps a green "Solved it ↗" / purple "Out of guesses" stamp
  on the board), the **stats hero** ("N% solve rate"), and the **empty dashboard**
  ("Make one ↗"). Documented both sticker + stamp in `/styleguide`. play_spec
  assertions made case-insensitive (stamp uppercases via CSS). 153 green.
- **Publish moved into the editor, gated.** On the edit page, **Save draft** and
  **Publish** now share one centered row — Publish is a second submit on the form
  via `formaction` → the publish action (forms can't nest). Publish stays **greyed
  + un-submittable with a tooltip** ("This puzzle is incomplete!…") until
  `Puzzle#complete?`, kept **live** by the autosave controller; a click while
  incomplete is `preventDefault`'d. Tooltip shows on hover + mobile-tap, gated by
  an `.is-blocked` class. New `spec/system/edit_publish_spec.rb`.
- **Your Puzzles redesign — hierarchy pass.** Replaced the "wall of colored
  buttons" with a title-forward, dense **divided list** (`.m-puzzle-list--dash`,
  no per-row boxes — boxes stay on the public browse list only). Each row now has
  **one filled accent button** (the encouraged next step: incomplete draft →
  *Finish*, complete draft → *Publish* (green), published → *Share*); everything
  else is a **quiet caps text-link**. Destructive actions are demoted — *Delete*
  is muted grey (red on hover) and *Unpublish?* purple, both grouped right.
  Dropped the greyed-publish-with-tooltip (incomplete drafts simply offer *Finish*
  instead of *Publish*). Status line shows *Draft* / *Published · N plays*. Green
  now only ever appears on a ready-to-publish draft, so it actually signals.
  Specs updated; 151 green. (Decisions: compact list + always-visible quiet
  actions, chosen via grill.)
- **Published rows mirror draft rows.** A published card now carries the same blue
  **Edit** button as drafts (replacing the old "Edit" text link in the meta — Stats
  stays), and **Delete** is the last child so the shared
  `&__actions > :last-child { margin-left: auto }` parks it in the bottom-right
  corner on both row types. Published actions read `Edit · Share · Unpublish? …
  Delete`. 151 green.
- **Unpublish demoted to a corner link.** On the dashboard, a published card's
  Unpublish is now a small **purple "Unpublish?" text link** (eye-slash icon kept)
  tucked into the card's bottom-right corner — a Turbo `data-turbo-method=patch`
  link with a `data-turbo-confirm` ("Are you sure you want to unpublish
  <title>?"). New `spec/system/dashboard_spec.rb` drives the confirm→unpublish
  flow. 151 green.
- **QA round 4 — completeness-gated draft rows.** A draft row now reflects
  `Puzzle#complete?`: **incomplete** → an "Edit"-style **Finish** button + a
  **greyed, un-clickable Publish** (a focusable fake button, not a real form) with
  a tooltip — *"This puzzle is incomplete! Finish it before publishing."* — shown
  on hover **and** mobile tap (`:hover` / `:focus-within`); **complete** → an
  **Edit** button + the real green **Publish**. **Unpublish** recolored **purple**
  (new `--purple` variant). Dashboard index eager-loads `:groups` to keep
  `complete?` off the N+1 path. New request specs for both draft states. 150 green.
- **QA round 3 — authoring flow tweaks.** "Save draft" now returns to the
  **dashboard** (`/puzzles`) instead of the show page (create+update redirect).
  Draft rows regained an edit affordance: a blue **Finish editing** button
  (pencil icon → editor) beside Publish. Authoring form reordered — **Title +
  Author moved to the top**, with an autosave explainer note above them. The save
  button now reads **"Save draft" until the puzzle is fully filled out, then
  "Finish"** — server-rendered via a new `Puzzle#complete?` and kept **live** by
  the autosave controller (counts the 16 words + 4 categories + title on each
  keystroke). Topbar fix: **LOG OUT / MY PUZZLES** are now identical uppercase
  outline buttons (swapped order, `display:contents` on the button_to form so it
  aligns like the anchors). New `edit` icon. Specs: `Puzzle#complete?` unit tests,
  draft-row "Finish editing" link, redirect assertions reverted to the dashboard,
  and the authoring system spec asserts the live "Finish" promotion. 149 green.
- **QA round 2 — create→show flow, show-page banners, polish.** "Save draft" now
  lands on the puzzle **show page** (create+update redirect to `play_path`);
  `PlayController#show` lets an owner **preview their own draft**. Show header is
  state-aware: draft+owner → blue "Look good? Publish it…" box + Publish; just-
  published (`?published=1`) → a **dark green-framed banner** "TITLE *(colorized)*
  is published! Share it…" + Share; ordinary published / non-owner → no box. Every
  **published** board gets a centered "Share this puzzle" button under the controls
  (everyone). Removed the old copy-link box + the bottom "view all" / "all puzzles"
  links from show/new/edit. Dashboard rows v3: **colorized + underlined** titles,
  Edit/Stats pinned right of the title (wraps when long), buttons on their own
  line, **deprioritized (xs) Delete**. "Save draft" button is now white w/ a save
  icon, centered, not full-bleed. Topbar `Quartets` colorized; **My puzzles / Log
  out are small outline buttons**. Footer **Hutch + SwiftKick Web colorized**.
  Global: hover states on buttons+links, and a WCAG-AA `$brutal-muted` grey
  replacing low-opacity dark text on the near-black page. New `clipboard`/`icon`
  helpers gained a Share/eye/eye-slash/trash/save set. Specs updated (create/
  publish redirects, draft-preview gating, celebrate banner); 144 green; verified
  by phone-width screenshots. Bulk CSV "export my puzzles" parked in `TODOS.md`.
- **Dashboard + share-flow QA pass.** Publish now lands the author on the live
  `/p/:share_token` board with an owner-only **share prompt** ("Look good? Share
  your puzzle!" + a *Copy puzzle link* button via a new `clipboard` Stimulus
  controller); the bottom link is owner-aware (*View All My Puzzles* → dashboard,
  else *← More puzzles*) with breathing room. "Your puzzles" rows rebuilt as
  **title (caps, links to play/edit) on the left, an action cluster on the right**
  with inline Heroicon SVGs (`icon` helper): published = Edit · Stats · blue
  **Unpublish** (eye-slash) · yellow **Share** (copies link) · white **Delete**
  (trash); draft = a non-clickable dashed **Draft** tag · green **Publish** (eye) ·
  **Delete**. New color button variants (`--blue`/`--share`/`--go`, `--sm`,
  `:has(.m-icon)` flex). `+ New puzzle` is a real `link_to new_puzzle_path` (was a
  broken `button_to` POST), right-aligned. New **Unpublish** action/route;
  **10-per-page** pagination (dependency-free offset). Topbar `Quartets` runs
  through `multicolor`. New request specs (unpublish, pagination) + updated
  author→publish system spec; verified by phone-width screenshots. Three
  out-of-scope features parked in `TODOS.md` (daily auto-feature, upvote/downvote,
  superuser admin index). **Note:** the dashboard no longer links JSON Export
  (per the new row spec) — the route still works; re-add if wanted.
- **Auth & accounts epic — public creation + cookie ownership + claim-on-signup**
  (ADR-0005, settles D1–D4). Reversed the superuser-only gate: `PuzzlesController`
  is open, ownership is `user_id` **or** a signed permanent `creator_token` cookie
  (new `Creator` concern, mirrors `AnonymousPlayer`); `Puzzle#user` is now
  optional. `ClaimsPuzzles` (site-wide `before_action`) sweeps a cookie's puzzles
  onto the account the instant you authenticate, then clears the cookie. Devise
  gained `:registerable` + `:recoverable` (no confirmable); every Devise screen
  (login/signup/account/forgot/reset) restyled on the brutalist theme inside a new
  `.m-auth` column, plus a site-wide `.l-topbar` auth bar (login/signup ↔ my
  puzzles/log out). A yellow `.m-claim` CTA on the dashboard nudges anon authors —
  "own the N puzzles you've made so far" — to sign up. Mail is env-configurable:
  `letter_opener` in dev, ENV-driven SMTP in prod (creds at deploy). Full suite
  green (139 examples); old "bounce to sign in" stats/export specs rewritten to the
  new owner-scoped 404.
- **Author→publish→play loop closed end-to-end** — the dashboard
  (`puzzles#index`) now surfaces a `Play` link (→ `/p/:share_token`) on every
  published puzzle, so the creator can reach/share the public board straight from
  their list. Extended the author→publish system spec to click that link and
  assert the real playable board renders (16 `.m-card` tiles). Quick win, no
  decisions.
- **Renamed the project to Quartets** — folder, GitHub repo (`johnhutch/quartets`,
  old URL redirects), Rails module (`Quartets`), the dev/test Postgres DBs (renamed
  via `ALTER DATABASE`, data intact), and every doc/config identifier. *(Landed via
  a merge with the laptop's design branch — see DBs are live; commit `dcc8f1a`.)*
- **Homepage hero + create stickers** — a grid-breaking `Create ↗` sticker
  (`.m-create-sticker`) on the play page + homepage hero, linking to
  `new_puzzle_path`. Homepage `NOTimes` nameplate (self-hosted UnifrakturMaguntia,
  OFL) layered over the `QUARTETS` wordmark; `body.theme-brutal` got
  `overflow-x: hidden` to clip the edge-bleed on phones.
- **Brutalist theme is now site-wide** — promoted `theme-brutal` from opt-in
  (homepage + styleguide) to the layout default; pages opt out via
  `content_for(:body_class)`. `_brutal.scss` extended to the puzzle lists, stats
  panels, author form + fieldsets, draft badge, flashes, and interior headings
  (which now run through `multicolor`). All specs green.
- **Multicolor re-rolls per load** — dropped the MD5 seed so colors *and* break
  positions re-randomize every call (run length 3–6), killing the "frozen purple"
  look. Server-side, zero JS; an optional `seed:` pins a banding for must-cache
  headers. Spec flipped determinism → re-roll.
- **Design system (brutalist)** — `_brutal.scss`, Space Grotesk webfonts, a
  `/styleguide` page, and `Multicolor` (the wordmark colorizer). Dropped the
  generated GitHub Actions CI at the time *(later reintroduced for GHCR image
  builds — ADR-0006)*.
- **Phase 5 — import + export.** `puzzles:import_obsidian` rake task
  (`ObsidianArchive`, forgiving + idempotent: 4×4 → published, partial → draft,
  junk skipped). JSON export per puzzle (`PuzzleExport`, spec-pinned schema; gated,
  owner-scoped `/puzzles/:id/export`). Both hard-spec'd.
- **Phase 4 — stats + sharing.** Attempts recorded best-effort via
  `POST /p/:share_token/attempts` (anonymous `player_token` cookie). Owner-scoped
  `/puzzles/:id/stats` (`PuzzleStats`: attempts, solve rate, mistakes distribution,
  common wrong guesses — all from the `guesses` jsonb). `EmojiCube` value object +
  copy-to-clipboard cube. Unit + request + system specs.
- **Phase 3 — play.** Our own Stimulus `game_controller.js` (no droppable vanilla
  engine — ADR-0003): shuffle 16, pick-4 → submit → reveal/mistake, cap at
  `Puzzle::MAX_MISTAKES`, emits `game:finished` with the guess log. Public
  `/p/:share_token` (`PlayController`; drafts/bad tokens 404, no login) +
  browsable `/play` index. Win + loss system specs.
- **Deploy pivot — Render → self-hosted Synology** (ADR-0004). DSM Container
  Manager `docker-compose.yml` (app + one Postgres for Solid cache/queue/cable),
  image built on the Mac (`linux/amd64`) and shipped over SSH via `bin/deploy` —
  no registry, no CI. *(Superseded by ADR-0006 — GHCR + Watchtower.)* Runbook in
  `docs/DEPLOY.md`.
- **Phase 2 — authoring.** Color-coded form (swellgarfo order, answers-first),
  gated `PuzzlesController`, owner-scoped dashboard, publish action, and
  **auto-save drafts** (debounced `autosave_controller.js`: POST to mint, then
  PATCH; title is publish-only so untitled drafts persist). Request + system specs.
- **Phase 0/1 — foundation.** Rails 8 + Postgres + Sass (SMACSS), RSpec/Capybara/
  factory_bot, headless-Chrome phone-viewport system-spec harness, Devise
  (superuser-only), and the `Puzzle`/`Group`/`Attempt` models + validations.

## Known not-done / watch-outs

- ~~"My puzzles" aggregate stats table~~ — called **Good Enough as-is** 2026-07-08;
  the per-puzzle `Stats` links cover it.
- **Quick wins, no decisions needed:** richer share payload (cube + title + direct
  link), and tune the 1000ms auto-save debounce on a real phone.
- **SMTP creds for prod** — forgot-password mail is wired and previews in dev
  (`letter_opener`); production reads `SMTP_*` from the NAS `.env`, to be filled at
  first deploy. Until then prod swallows delivery errors so the app boots clean.
- **Mobile pass** (real iPhone), **first Synology production deploy** + smoke test,
  and **seeding a first account** — the remaining Phase 0/5 ⬜s.
- **Tile press feel** — the lift transition (0.22s springy) is shared with the
  card's `:active` press-scale, so a held press inherits the same easing. Reads
  fine; split the timings if a press ever feels mushy.
- `docs/PLAN.md`'s schema sketch calls `Group#words` a "PG array"; it's actually a
  **jsonb** column. Treat jsonb as the truth.
