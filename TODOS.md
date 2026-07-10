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

### Accounts — the last unbuilt piece

- ~~Per-creator public homepage `/u/:handle`~~ **Shipped 2026-07-07 (ADR-0016)** —
  `users.handle` + public page + linked bylines.
- ~~"My puzzles" aggregate stats table~~ **Called Good Enough as-is 2026-07-08** —
  the dashboard's per-puzzle `Stats` link + play counts cover it; no inline
  aggregate table needed.

### Follow-ups from the one-play-per-user work (ADR-0009)

- ~~Gate the home page's featured board too.~~ **Moot** — the homepage rework
  (2026-06-19) made `home#show` a launchpad with no board at all, so there's
  nothing to gate.
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
  default off/all). ~~Tag visibility~~ **shipped 2026-07-08 (ADR-0018)** — themed
  rows carry the THEMED chip with a tag fold-out, show page renders tags inline.
  Still TODO: make the chips **clickable** → a tag-filtered list at
  **`/play?tag=star-wars`** (`Tag#puzzles`) — deliberately left inert for scope.
- **Surface `description` on-page.** The meta/`og`/`twitter:description` slice
  shipped, and the show-page half landed 2026-07-08 as a **spoiler fold-out**
  under the byline (`.m-description`, ADR-0018 session). Still TODO: a
  **browse teaser** on `/play` rows, if ever — the archive rows now carry
  ratings + the themed flag, so a teaser may be too much.
- **Full-text search** over title + description (+ tags) — defer until there's a
  corpus worth searching; then Postgres `tsvector`. Pretty `/t/:tag` hubs later.
- **Difficulty from stats** (ADR-0010) — a future job deriving difficulty from
  completion success/failure rates (maybe reputation-weighted); not authored.

### Community (from the 2026-07-09 audit)

- **Follow a creator + notifications** — the community loop the audit called for:
  follow creators, and get notified ("someone played your puzzle," "a creator you
  follow posted"). Foundation exists (handles, `/u/:handle`, linked bylines). The
  author loves it but **blocked on a better email/notification solution first** —
  don't build the notify half on the current best-effort SMTP. Discord webhook was
  floated and **rejected** (author dislikes Discord); email is the channel when the
  email story is solid.
- **Authoring validation nudges** — warn an author when a puzzle looks unfair
  before publish. **Two tiers:** (1) a *heuristic* pass with no LLM — flag when the
  same word (case/space-normalized) appears in two groups' answer sets, or when a
  word is a trivial substring/dupe; cheap, ships anytime. (2) the *smart* version —
  "these two categories overlap semantically, a solver could reasonably put X in
  either" — genuinely needs an LLM call at publish time. Author was unsure how to
  do it without an LLM; tier 1 is the answer for a first cut.

**Shipped 2026-07-09 (community audit follow-through):** moderator role (puzzle
powers, no user admin), puzzle **reporting** (flag → email staff → admin triage
queue), **how-to-play** page + top-left link, and the **"making a good quartet"**
guide. See PROGRESS + ADR-0020.

### Bigger features (scoped, not started)

- **Daily auto-featured puzzle ("Puzzle of the Day")** — a from-the-start goal,
  reaffirmed in the 2026-07-09 community audit as the single biggest retention +
  first-impression lever (recreates the NYT daily ritual + a shared cube + unlocks
  streaks). **Gated on corpus size, not effort:** the author explicitly won't
  hand-make one a day, so selection must be *algorithmic* and there must be enough
  good published puzzles to draw from — hold until there's a critical mass. Pick
  ONE puzzle to feature front-page for the whole day, cycling automatically. Add a
  `last_featured` (date) column (the existing `featured` boolean stays for manual
  curation). Selection picks the first match in this order:
  1. the never-featured puzzle with the most completions;
  2. the never-featured puzzle with the most views;
  3. a never-featured puzzle with a **positive upvote score**;
  4. the puzzle with the **oldest `last_featured` date**.
  (Depends on the upvote/downvote feature for step 3, and a views counter for step
  2.) **Note:** post-homepage-rework (2026-06-19) there's no single featured board
  on home anymore — it's a launchpad with a `RANDOM()` strip of ≤5 published puzzles
  (`HomeController::STRIP_SIZE`). A daily-featured puzzle now needs a *new* home slot
  decided (e.g. a pinned "Today's quartet" band above the strip), not a drop-in
  replacement.
  **Unblocks:** the **dashboard streak stat** (deferred from ADR-0011) — there's no
  "today"/consecutive-days notion to count until a daily puzzle exists. When this
  lands, add a Streak cell next to Played · Solved · Solve rate · Created in the
  "Your stuff" trophy/stats block (`_dashboard_stats`, `PlayerStats`).
- **Upvote / downvote per puzzle** — thumbs-up / thumbs-down icons shown below
  each puzzle (play surfaces). Upvotes start at **1**, downvotes at **0** — so a
  fresh puzzle's total score is **1**. The total score shows on the puzzle's
  stats page. Anonymous-safe (one vote per player_token, like attempts).
- **Admin: tag + user management** — the `/admin` shell shipped (ADR-0016:
  superuser role, all-puzzles tab with owner-grade actions, users list). Still
  unbuilt: a **tag admin** (edit/merge/delete tags to clean spelling divergence —
  key for the tags cold-start) and user *management* beyond the read-only list
  (e.g. delete/superuser toggles from the UI).
- **Bulk "Export my puzzles" (CSV)** — export is now a *separate* function: an
  "Export my puzzles" link at the **bottom of Your Puzzles** downloads **all** of
  the owner's puzzles as one CSV. Per-puzzle export is gone from the UI (the
  `/puzzles/:id/export` JSON route still works underneath — no need to rip it
  out). Decide the CSV shape (one row per puzzle with the 4 groups flattened, or
  one row per group).

### Stats — completion analytics

The recorded **guess log** (`attempts.guesses`) already reconstructs almost every
completion stat retroactively (see the deep dive in the 2026-06-18 session). The
few signals that are *irreversibly lost* if not captured at play time are now being
recorded (below); the rest is read-side display work, buildable whenever.

**Capture — shipped 2026-06-18 (recording only, nothing displayed yet):**
- **Per-guess timing + total duration.** Each guess in the `guesses` jsonb carries
  `t` (ms since the clock started, which starts on the first tile tap); the attempt
  carries `duration_ms`. `Guess#elapsed_ms` reads it back; both are nil-safe for
  pre-timing plays. Game controller measures it; `attempts#create` permits it.
- **`game_started` / abandons.** New `Event` model (`event_type` enum, `game_started`
  only for now) + `events#create` beacon, fired on the first tile tap (`/p/:token/
  events`). Same gate + anonymous `player_token` as attempts. *Abandoned* plays are
  **derived** later — a `game_started` with no finishing `Attempt`, joined on
  player_token + puzzle, time-windowed — so there's nothing extra to record.

**Capture — shipped 2026-07-07:**
- **Post-play ratings.** `attempts.quality` (yeah/hell_yeah) + `attempts.difficulty`
  (pretty_easy…cursed), voted from the game-over/revisit rating block (published
  puzzles only). **Display shipped 2026-07-08** on browse rows, the jump-in strip,
  the show page, and (2026-07-08, second pass) the owner stats page
  (`RatingSummary`: weighted thumbs + averaged difficulty label). The *voted*
  difficulty also feeds the ADR-0010 "difficulty from stats" idea, which no
  longer needs to be inferred-only.

**Display — TODO (future, no frontend yet):**
- **Surface the timing + funnel stats.** Player-facing: solve duration, time-to-
  first-group, personal-best/speed percentile vs other solvers of the same puzzle.
  Creator/admin-facing: a `started → finished` funnel and **abandon rate** per
  puzzle (join `Event.game_started` to `Attempt`, ~30-min window). New value objects
  alongside `PuzzleStats`/`PlayerStats`; the funnel piece overlaps the Analytics-B
  `FunnelStats` + superuser dashboard, so build it there when that lands. Likely
  also fold a duration row into `/puzzles/:id/stats` and the dashboard block.

**Capture — still not built (additive, build if/when the stat is wanted):**
- **Shuffle / deselect counts** *(cheap, low value)*. The game controller tracks
  both and discards them — recording counts enables "solved without shuffling"
  flavor trophies. Fold into the attempt next time the payload is touched.
- **`published_at` on puzzles** *(medium-low)*. `status` changes aren't timestamped
  (only `created_at`/`updated_at`), so we can't reconstruct *when* a puzzle went
  public → author-timeline stats (publishing streaks, time-to-first-play) are
  lossy. Add a timestamp if author-timeline stats reach the roadmap.

### Quick wins (no decisions needed)

- **Tag fold-out bubble overlaps the next list row when open.** Legible (purple
  border, ink bg, z-indexed) and closes on tap, but it sits on top of the row
  below — right-anchor it or flip it above the chip if it grates
  (`.m-themed__bubble` in `_modules.scss`).
- **Pin the live game-over stamp's arrow too.** `game_controller.js`
  `renderEndStamp` still writes a raw `"Solved it ↗"` — iOS renders the emoji
  block the `ne_arrow` helper (U+FE0E) fixed everywhere else. Append `︎` in
  the JS string.
- **Drop dead CSS from the revisit rework.** `.m-result__status` /
  `.m-result__heading` are unused since `play/_result` became the reconstructed
  board (it uses the `.m-game__*` + `.m-stamp` classes now). `/simplify` fodder.
- **Move UI copy into `en.yml` site-wide** (own-branch job — user's call). Specs
  that assert hard-coded copy are brittle: the footer spec broke this session when
  a link was removed. The pattern: copy → `en.yml`, view + spec both reference the
  i18n key, so a wording/link change is a locale edit, not a test edit. The
  **homepage is now fully i18n'd** (`home.*`, incl. the manifesto columns + win-board
  filler as structured arrays) — use it as the template for the rest.
- ~~Richer share payload~~ **Done** — `ShareText` is title + cube + link, and the
  Share buttons now go through the native share sheet (`share_controller.js`,
  2026-07-06).
- **Tune the auto-save debounce** — currently 1000ms
  (`data-autosave-debounce-value` on the form). Feel it on a real phone and adjust.
- **Finish the "quartet" rename in body copy** — chrome (nav/buttons/titles/
  headings) now says "quartet"; *prose* still says "puzzle" (dashboard/play empty
  states, claim CTA, privacy page, `og:description`). Sweep if full consistency is
  wanted — left alone on purpose since the ask was scoped to buttons/nav.

### Architecture review — remaining candidate

- **Candidate 4 — fold the anonymous-identity tokens** (`Speculative`). `Creator`
  (`creator_token`) and `AnonymousPlayer` (`player_token`) repeat the same
  signed-permanent-cookie `ensure_*`/`current_*` plumbing. A `SignedCookieIdentity`
  parameterized by cookie name could own it (two tokens = two adapters). Flagged
  speculative: tiny payoff, real over-abstraction risk on two ~6-line mixins with
  different lifecycles (claim-on-auth lives only in `Creator`). Candidates 1–3 from
  that review shipped this session.

### Analytics (privacy-first — see the analytics grill)

Three streams: **A traffic** (referrers/sessions/uniques, incl. AI-referral
segmentation for GEO), **B product funnels** (create→publish, play→complete,
anon→signup), **C error tracking**. Bot/crawler measurement is a cross-cutting
concern. **Sequencing:** the superuser role + `/admin` shell that gated B and C
**shipped (ADR-0016)** — both are now unblocked; A tool-pick still open.

- **B — product funnels (designed, build as one chunk post-superuser).** Tight
  **`Event`** model, enum-constrained to `puzzle_opened` / `game_started` /
  `authoring_opened`, keyed by `player_token` (+ optional `user_id`, `puzzle_id`,
  `occurred_at`); **not** a generic firehose, and **`Attempt` stays untouched**.
  *Capture:* server-side one-liners for `puzzle_opened` (`play#show`) and
  `authoring_opened` (`puzzles#new`); one `game_started` **beacon** from
  `game_controller` (only way to catch mid-game abandons — nothing else hits the
  server between open and game-over). **Best-effort inline** writes, gated by a
  **shared human/bot UA classifier** (humans → `Event`, bots → bot log).
  *Funnels:* `opened → started → finished` joined on `player_token`,
  **time-windowed ~30 min at read time** (no session id); completion from
  `Attempt`, author steps from `Puzzle` timestamps/status, signup = a source tag.
  *View:* a **`FunnelStats`** value object (mirrors `PuzzleStats`/`PlayerStats`)
  folded into the **superuser dashboard**, gated by the superuser role; site-wide
  first, per-puzzle strip into `/puzzles/:id/stats` later. *Retention:* store raw,
  compute on read, add a prune job (Solid Queue, >90d) later.
- **C — error tracking (decided): `exception_notification` gem, full stop.**
  Fully first-party, zero added infra, no SaaS (rejected GlitchTip self-host =
  too much for the box; rejected Sentry/AppSignal/Honeybadger SaaS = third party).
  Email to `ADMIN_EMAIL` (SMTP already being wired); enable **`error_grouping`** so
  repeats don't flood the inbox; rely on `config.filter_parameters` for PII. If
  the gem ever bitrots, fall back to Rails 8's native `Rails.error` reporter +
  subscriber — **not** a SaaS.
- **Bot/crawler measurement (decided):** lean on **Cloudflare's free bot/AI-crawler
  analytics now** (zero infra, already fronts us) + a **first-party Rails
  middleware logging bot UA + path to Postgres** as the durable record (same
  pattern as `Attempt`; the UA classifier is shared with stream B's capture).
  Backburnered: **enable Caddy JSON access logs** at the origin (Caddyfile has no
  `log` directive today) and parse them (GoAccess or ship to DB) — note real client
  IP arrives via `CF-Connecting-IP`, UA is preserved.
- **`llms.txt`** — serve it (cheap), but the file itself may get ~zero hits early;
  the realer signal is AI-crawler UAs (`GPTBot`/`ClaudeBot`/`PerplexityBot`/`CCBot`/
  live `*-User` fetchers) hitting actual pages. Measure via the bot logging above.
- **A — traffic analytics (tool-pick open).** Cookieless/no-banner, small-box
  friendly: Cloudflare's free Web Analytics (zero infra) vs self-hosted Umami
  (needs Postgres, which we have) vs GoatCounter (featherweight). GEO requirement:
  must expose referrers cleanly with an AI/LLM segment. Grill not yet done.
- **GEO/AEO** — folds into A (AI-referral segmentation) + an optional later DIY
  prompt-monitor (hit LLM APIs with a small prompt set, grep for our domain, log to
  Postgres). Game-site ROI is modest; don't build a heavyweight GEO platform.

### Ops

- **Fill prod SMTP creds** — forgot-password mail is wired and previews in dev via
  `letter_opener`; production reads `SMTP_ADDRESS`/`SMTP_PORT`/`SMTP_USERNAME`/
  `SMTP_PASSWORD`/`MAILER_SENDER`/`APP_HOST` from the NAS `.env`. Fill at first
  deploy (ADR-0005).
- **Verify the one-time Cloudflare purge landed.** `ShortLivedLoosePublicFiles` is
  on `main` (deployed); after the new-palette deploy, a single **Purge Everything**
  clears the year-pinned robots.txt/favicons. Verify:
  `curl -sI https://playquartets.com/favicon.ico | grep -i cache-control` should
  say `max-age=3600`. (Browsers that cached the old favicon keep it until their
  copy expires — expected, not fixable server-side.)

### Hosting (exploratory — NO decision to move has been made)

The self-hosted NAS (Synology DS918+, Celeron, behind a Cloudflare tunnel) is the
**slow origin** that drives the PageSpeed swings: a Cloudflare cache **miss** falls
through to a slow always-awake box → spiky TTFB. Notes from the hosting grill, kept
for reference *only*:

- **Heroku: skip.** As of Feb 2026 Salesforce moved it to "sustaining engineering"
  (no new features, enterprise sales ended) — managed decline, ~4–5yr wind-down, no
  EOL date. Not worth building on.
- **Best fit if we ever move: Render (paid Starter, ~$7 web + ~$6 Postgres).**
  Closest Heroku-like DX, managed Postgres, deploys our Dockerfile. **Avoid the free
  tier** — it sleeps after ~15 min idle → ~30–60s cold start on wake, which for a
  low-traffic site is *worse* than the always-awake NAS. Alternatives: **Fly.io**
  (cheaper, but self-managed Postgres), **Railway** (best DX, containerized DB).
  Any always-on tier kills the slow-origin problem; keep Cloudflare in front.
- **Migration is mostly deletion + config — no app-logic changes.** Already
  portable: Dockerfile, Puma binds `ENV["PORT"]`, `DATABASE_URL`,
  `SOLID_QUEUE_IN_PUMA=true` (single web service, one Postgres for app+Solid),
  `assume_ssl`. *Adjust:* run plain `./bin/rails server` (Thruster binds 80, not
  Render's `$PORT`) or align Thruster's port; add the `*.onrender.com` host to
  `config.hosts`; `RAILS_SERVE_STATIC_FILES=true`; Cloudflare SSL mode → **Full
  (strict)** to avoid a redirect loop; move `.env` → Render secrets. *Remove:*
  `Caddyfile`, `docker-compose.yml`, `.github/workflows/deploy.yml` (Watchtower/GHCR
  — Render builds on push). *Add:* a `render.yaml`; new ADR superseding ADR-0006/0007.

---

## Suggested order

1. **Analytics B + C** — now unblocked by the `/admin` shell (ADR-0016); build the
   funnels into a third admin tab. (A first slice exists: `EngagementStats`
   starts/abandons/first-group on the admin puzzles tab, 2026-07-08.)
