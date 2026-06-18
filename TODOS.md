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
  board even if the player already finished that featured puzzle — now inconsistent
  with `play#show`, which gates non-owners (signed-in *and* anonymous, ADR-0012).
  Reuse the pieces that already exist: `PlayController#finished_attempt` (the lookup)
  + the `play/_result` finished-board partial; render the result when an attempt
  exists.
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
- **Surface `description` on-page.** The meta/`og`/`twitter:description` slice
  shipped (per-puzzle: author blurb, else generated fallback — `puzzle_meta_description`).
  Still TODO: show the description **under the byline** on `play#show` and as a
  **browse teaser** on `/play`.
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
  **Unblocks:** the **dashboard streak stat** (deferred from ADR-0011) — there's no
  "today"/consecutive-days notion to count until a daily puzzle exists. When this
  lands, add a Streak cell next to Played · Solved · Solve rate · Created in the
  "Your stuff" trophy/stats block (`_dashboard_stats`, `PlayerStats`).
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

- **Pin the live game-over stamp's arrow too.** `game_controller.js`
  `renderEndStamp` still writes a raw `"Solved it ↗"` — iOS renders the emoji
  block the `ne_arrow` helper (U+FE0E) fixed everywhere else. Append `︎` in
  the JS string.
- **Drop dead CSS from the revisit rework.** `.m-result__status` /
  `.m-result__heading` are unused since `play/_result` became the reconstructed
  board (it uses the `.m-game__*` + `.m-stamp` classes now). `/simplify` fodder.
- **Richer share payload** — cube + title + direct link in the share sheet
  (verify what commit `b3acb2b` already covers first).
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
concern. **Sequencing:** B and C are queued **after the superuser role + admin/
user dashboard** ship (a couple items out); A tool-pick still open.

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

---

## Suggested order

1. **Quick wins, no decisions** — richer share payload → auto-save debounce tune.
2. **"My puzzles" aggregate stats table** — needs no new decision; builds on the
   existing owner-scoped dashboard + `PuzzleStats`.
3. **Per-creator public homepage `/u/:handle`** — settle the deferred D3 (handle
   model) via `grill-me` and record it in DECISIONS.md *first*, then build the
   public index.
