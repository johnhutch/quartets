# Decisions

ADR-style log of major design + architectural decisions. One entry per decision. **Append at the bottom; don't rewrite history** — supersede an old entry by compressing it to a "superseded by NNNN" stub.

---

## 0001 — Auto-save: publish-only validation + a quiet POST→PATCH endpoint

**Date:** 2026-06-06
**Status:** accepted

**Context.** Auto-save is a hard requirement (born from losing work to the iOS
back button). The authoring form is answers-first with the title at the bottom,
so a half-typed draft routinely has groups but no title yet. `Puzzle#title` was
the one validation still firing on drafts, which blocked saving that state. We
also needed background saves that don't redirect or flash, and a brand-new
puzzle has no id to PATCH against yet.

**Decision.** Make **everything publish-only** — `title` joins the structural
rules in being validated `if: :published?`, so drafts stay lenient. Auto-save
requests carry an `autosave` param; the controller answers them quietly:
`create` returns **201 + the editor URL in `Location`**, `update` returns
**204 No Content**. The Stimulus controller POSTs the first save, reads
`Location`, then rewrites the form to PATCH that record (and `replaceState`s the
URL) so later edits update in place instead of creating duplicates.

**Consequence.** Drafts can be blank/partial and still persist — don't lean on
title presence anywhere but publish. The autosave response contract (201+Location
/ 204, no redirect) is load-bearing for `autosave_controller.js`; changing it
breaks the new→edit handoff. Publish is the only gate that enforces the full 4×4
+ title rules.

---

## 0002 — Deploy: self-host on Synology, native dev + Docker prod

**Date:** 2026-06-08
**Status:** accepted

**Context.** CLAUDE.md originally said Render ("Not Heroku"), but on review the
owner doesn't want a host with no spending cap for a toy app and already has a
**Synology DS918+** (RAM upgraded) to run it on — zero marginal cost, no billing
surprise possible. Accepted tradeoff: if the app ever blows up, migrate then.
Three forks: build/runtime, how many databases, and how to run jobs. The owner
isn't anti-Docker, just anti-Docker-as-thoughtless-default; the historical gripe
(developing *inside* a container) doesn't apply here because **dev stays native**.

**Decision.** **Dev native** on macOS (chruby + Postgres, `bin/rspec` in the real
shell — unchanged). **Production containerized** via DSM **Container Manager**:
a `docker-compose.yml` runs the app (the repo's stock Rails 8 Dockerfile, Ruby
4.0.4 pinned) + a `postgres:17-alpine` service. **CI builds the image** on GitHub
runners and pushes to **GHCR**; the NAS only ever pulls (the Celeron shouldn't
compile). A **GitHub Action** ships on push to `main` (build → push → SSH →
`docker compose pull && up -d`). One **Postgres** backs app + Solid trifecta via
a shared `DATABASE_URL` (each connection keeps its `migrations_paths`). **Jobs run
in Puma** (`SOLID_QUEUE_IN_PUMA=true`). **Thruster stays** (HTTP-only) since TLS
terminates at DSM's reverse proxy + Let's Encrypt; `db:prepare` runs via the
container entrypoint (creates + seeds on first boot, migrates after). Secrets live
in a `.env` on the NAS (gitignored) + GitHub repo secrets for the deploy SSH.

**Consequence.** No hosting bill and full control of the Ruby version; in exchange
the owner runs the box (DSM updates, backups — `pg_dump` via Task Scheduler).
`docker-compose.yml` and `.env` don't ride the image, so changing them means
updating the NAS copy by hand. Jobs share the web container — split out a worker
when volume justifies it. Full runbook in `docs/DEPLOY.md`. Not yet deployed —
first deploy waits on the one-time NAS setup + GitHub secrets.

---

## 0003 — Game engine: build our own Stimulus controller

**Date:** 2026-06-09
**Status:** accepted

**Context.** CLAUDE.md called for *embedding* an existing open-source vanilla-JS /
Stimulus Connections engine ("do not build the game loop from scratch") under two
hard constraints: **no React** and **no Node build** (we're on importmap). A
survey of the field came up empty: the maintained clones
(`and-computers/react-connections-game`, `fetch-rewards/fetch-connections-game`,
`srefsland/nyt-connections-clone`) are React/Next.js; the ones that look vanilla
(`wheeler/connections-game`, `dbousamra/connections`) are TypeScript + Vite (a
Node build) with no real license. No maintained, permissively-licensed,
importmap-droppable vanilla engine exists.

**Decision.** Build our own compact **Stimulus controller** (`game_controller.js`).
The Connections loop is small and well-understood — render 16 shuffled cards →
select up to 4 → submit → match-a-group or count-a-mistake (cap at
`Puzzle::MAX_MISTAKES`) → lock solved rows → win/lose → shuffle/deselect. ~200
lines, zero dependencies, fits importmap natively, and it's the natural place to
emit the guess data Phase 4 needs (stats + emoji cube). TDD'd via a system spec.

**Consequence.** This **reverses** the "embed an existing engine / don't build
from scratch" line in CLAUDE.md — that line assumed a droppable engine existed,
and it doesn't; every alternative violates a *harder* constraint (React or a
build step). The other locked decisions (no React, importmap, no build) stand. We
own the game loop now — more code to maintain, but full control over the JSON we
feed it and the guess data we get back.

---

## 0004 — Deploy mechanism: build-and-ship over SSH, no CI/CD

**Date:** 2026-06-09
**Status:** superseded by 0006

**Context.** 0002 wired a GitHub Action to build the image on GitHub runners,
push to GHCR, and SSH to the NAS. On reflection the owner doesn't want to depend
on GitHub (or any third party) for deploys — GitHub is just the archive remote.
The constraints still hold: build off the NAS's weak Celeron, Docker is fine.

**Decision.** A plain `bin/deploy` script: `docker build` on the dev machine
(pinned `--platform linux/amd64` — the DS918+ is Intel, the Mac is ARM), then
`docker save | ssh nas docker load`, then `ssh nas "docker compose up -d"`. **No
registry, no GitHub, no build on the NAS.** Compose references a local
`quartets:latest` with `pull_policy: never`. The GitHub Action and GHCR
are gone. Everything else from 0002 stands (Docker prod, one Postgres, jobs in
Puma, DSM reverse proxy for TLS). Runbook: `docs/DEPLOY.md`.

**Consequence.** Deploys are a manual `NAS_SSH=… bin/deploy` from the laptop —
fine for a toy app, and fully self-reliant. The image moves as a tarball over
SSH (no registry to run or trust). If deploys ever want to be hands-off, revisit
Kamal + a self-hosted registry. Not yet run end-to-end — first deploy waits on
the one-time NAS setup.

---

## 0005 — Anonymous creation + cookie ownership + claim-on-signup (settles D1–D4)

**Date:** 2026-06-10
**Status:** accepted (supersedes the "superuser-only creation" decision in 0000-era
CLAUDE.md)

**Context.** The original spec — lost along the way — was that *anyone* can author
a puzzle without an account; the superuser-only gate crept in during Phase 2 and
contradicts it. Reopening that meant settling the four gating questions D1–D4
(TODOS.md). The owner pre-decided the direction: public creation, a cookie that
remembers what you made, and a "claim these to own them" prompt that bridges
anonymous work to a real account. The remaining forks were taken via
`AskUserQuestion` (all the recommended option).

**Decision.**

- **D2 · Auth gate reversed.** `authenticate_user!` comes off `PuzzlesController`
  entirely. Creating, editing, publishing, listing, stats, export are all public.
  There is no admin-only surface anymore — "superuser" is just an account that
  happens to own puzzles. This **rewrites** the "Superuser-only for puzzle
  creation" line in CLAUDE.md/DECISIONS.md.
- **D1 · Ownership = user_id OR a cookie creator_token.** A puzzle `belongs_to`
  a user *optionally*; when no one's logged in, ownership rides a signed,
  permanent `creator_token` cookie (mirrors `AnonymousPlayer`'s `player_token`).
  A new `puzzles.creator_token` column (indexed) carries it. The owner of a
  request is `current_user` if signed in, else the cookie token. Index/edit/
  publish/stats are scoped to whichever applies, so anonymous creators get the
  same edit-and-revisit story on their own device. **Claim-on-auth:** the moment
  a request is authenticated and the creator cookie still owns puzzles, those
  rows are reassigned to the user and the cookie is cleared. Covers signup,
  login, and remembered sessions.
- **D3 · Public per-creator homepage (`/u/:handle`) deferred.** Not needed for
  this epic — claim + the "my puzzles" dashboard don't require a stable handle.
  `author_name` stays free-text. Revisit handles when the public homepage lands.
- **D4 · Devise modules:** add `:registerable` (public signup) and `:recoverable`
  (forgot-password). **No `:confirmable`** — signup is frictionless, no
  email-confirmation step. `:rememberable` + `:validatable` stay. Mail is
  **env-configurable**: dev previews reset emails via `letter_opener`; production
  reads SMTP from ENV (filled into the NAS `.env` at first deploy). Nothing about
  this blocks on the deploy.

**Consequence.** Creation is fully public — drafts and stats are no longer
login-protected, so don't assume `current_user` anywhere in the puzzle flow;
reach for the owner helper instead. The `creator_token` cookie is load-bearing
for anonymous ownership; clearing it (or switching devices) orphans unclaimed
puzzles, which is the intended nudge toward signing up. Existing specs that
assumed login-gated creation get rewritten. Forgot-password works end-to-end in
dev now; production needs real SMTP creds in `.env` before reset mail actually
sends.

---

## 0006 — Deploy: GitHub Actions to GHCR + Synology Container Manager + Watchtower

**Date:** 2026-06-13
**Status:** accepted (supersedes 0004)

**Context.** The previous deployment strategy (ADR-0004) used a custom `bin/deploy` script that piped image tarballs over SSH to avoid using a container registry. This proved fragile and "harder than it should be" to maintain. Synology's native Container Manager ("Projects") pairs perfectly with standard docker registries.

**Decision.** Eliminate the custom `bin/deploy` script. We now use a **GitHub Actions workflow** (`.github/workflows/deploy.yml`) to automatically build `linux/amd64` images and push them to GitHub Container Registry (GHCR) on every push to `main`. On the Synology NAS, `docker-compose.yml` runs the app alongside **Watchtower**, which periodically polls GHCR and automatically pulls/restarts the `web` container when a new image is found. The existing Cloudflare Tunnel is maintained.

**Consequence.** Deploys rely entirely on standard, automated paths (GHCR and Watchtower). SSH keys and local laptop builds are no longer required. Deployment is now a zero-click experience triggered purely by a git push.

---

## 0007 — Caddy front proxy to mask the deploy restart (no 502s)

**Date:** 2026-06-15
**Status:** accepted (extends 0006)

**Context.** With 0006, every push recreates the `web` container (stop → start →
Rails boot). On the slow DS918+ that's a ~10-15s window, and because `cloudflared`
pointed straight at `web:3000`, the site returned 502s the whole time. For a
hobby app, true blue-green (two app instances + health-checked swap + a custom
deploy script) is more orchestration than it's worth, and it would mean giving up
Watchtower's hands-off auto-pull.

**Decision.** Insert a lightweight **Caddy** reverse proxy between the tunnel and
the app: `tunnel → caddy → web`. Caddy uses `lb_try_duration 25s` so a request
that lands mid-restart is held and retried until the new `web` is accepting,
rather than erroring. The tunnel's public hostname now targets `caddy:80`.
Watchtower is scoped via label (`WATCHTOWER_LABEL_ENABLE` + the
`com.centurylinklabs.watchtower.enable=true` label on `web` only) so it cycles
just the app — Caddy, Postgres, and the tunnel stay up across a deploy. Config:
`Caddyfile` (mounted into the container) + the `caddy` service in
`docker-compose.yml`.

**Consequence.** Deploys stay fully automated (push → GHCR → Watchtower) but
visitors now see, at worst, a single slow load during the swap instead of an
outage. This is a *buffer*, not real zero-downtime: in-flight requests on the old
container at the instant it's killed can still drop, and a non-idempotent `POST`
landing in that ~1s kill window won't be retried (Caddy only retries safe GETs).
If that ever matters, revisit blue-green. One more long-lived container to keep
pinned (`caddy:2`) so it isn't itself caught in an update.

---

## 0008 — Drafts retired: completeness (derived) × visibility (unlisted/published)

**Date:** 2026-06-15
**Status:** accepted (not yet built — build plan in TODOS.md; reframes the
draft/published model from ADR-0001)

**Context.** "Draft" was overloaded: it meant both *unfinished* (fields missing)
and *finished-but-not-on-the-site*. The owner wants those split, a lively public
homepage (so publishing should be encouraged, not buried), and complete-but-hidden
puzzles to be **playable by anyone with the link** (today a non-owner 404s on any
unpublished puzzle). A separate change landing this week makes the play URL a
name slug + random suffix (`/p/my-super-cool-puzzle-230492351nfs`, still under
`/p/`), which interacts with how hidden puzzles stay unadvertised.

**Decision.**

- **Two axes, not a three-state enum.** Completeness stays **derived** —
  `Puzzle#complete?` (title + 4 groups, each with 4 words + a description), never
  stored. `status` becomes a pure **visibility** toggle. The three things the
  author sees fall out of the combination:
  - *incomplete* = `unlisted` & `!complete?`
  - *unlisted* = `unlisted` & `complete?`
  - *published* = `published` (only reachable once `complete?`)
- **Enum rename, zero data migration.** `{ draft: 0, published: 1 }` →
  `{ unlisted: 0, published: 1 }`, default `:unlisted`. Existing rows don't move:
  old complete drafts become `unlisted + complete?`, old incomplete drafts become
  `unlisted + !complete?`. The word "draft" retires.
- **Terminology: "Unlisted."** The owner first wanted "Private," then switched —
  the deciding factor was that a `private` enum value collides with Ruby's
  `Module#private` (it'd break the generated `Puzzle.private` scope; the
  controllers lean on `Puzzle.published`). "Unlisted" is also simply the honest
  term: it is **obscurity, not access control** — every unlisted link is playable
  by anyone who has it. Symbol and UI label now agree (`unlisted?` ↔ "Unlisted").
  Microcopy still states it plainly: *"Anyone with the link can play. Won't appear
  on the site or in search."* Visibility is explicitly low-stakes ("not secret
  data; just not advertised — if someone guesses it, shrug"), which is why the
  slug's random suffix is sufficient and no owner-only/true-private state exists.
- **Playability gates on `complete?`, not `published`.** `play#show`:
  published → anyone; unlisted + complete → anyone with the link (the new
  behavior); unlisted + **incomplete** → 404 for strangers, owner redirected to
  the editor (you can't play a half-built board). One rule: *the play page
  requires `complete?`; published merely adds "listed."*
- **No auto-publish, no default-public.** Completeness is reached mid-autosave,
  so auto-publishing-on-complete would shove a puzzle live the instant the last
  word is typed — before review. Rejected. Status is **always unlisted until an
  explicit publish.** The lever against puzzles dying unlisted-by-neglect is
  **prominence, not automation:** the moment a puzzle is `complete?`, the editor's
  primary CTA becomes a loud **"Publish to the site"** (`m-btn--go`), with a quiet
  secondary **"Keep it unlisted (link only)"** carrying the honest one-liner. A
  conscious one-time choice, Publish visually winning — not a buried checkbox.
- **`noindex` ⟂ link previews.** Unlisted puzzles emit
  `<meta name="robots" content="noindex, nofollow">` (search engines stay out);
  published puzzles omit it (indexable). **Both keep full OG/Twitter tags** so a
  shared link still unfurls a preview card in iMessage/Slack/etc. — that's the
  whole point of an unlisted link, and OG scrapers fire on-demand, not by crawling.
- **Unpublish → unlisted.** `published → unlisted` keeps all data and the working
  link; there's no separate draft state to fall back to. The dashboard's
  "Unpublish?" becomes "Make unlisted." `featured` still implies published (an
  unlisted puzzle can't be featured).

**Consequence.** `status`'s meaning shifts from lifecycle to visibility — read
any old `draft?`/`published?` call site with that lens (the publish-only
validations in `Puzzle`/`Group` still key off `published?` and are unaffected).
The notable behavior change is `play#show`: it must gate on `complete?` and stop
404-ing complete unlisted puzzles for non-owners. Unlisted is deliberately weak by
design; don't add access-control machinery for it later without revisiting this.
The slug migration is orthogonal but should ship compatibly — the random suffix
is what keeps unlisted puzzles unadvertised.

---

## 0009 — One play per logged-in user: account-attributed attempts + result view

**Date:** 2026-06-15
**Status:** accepted (extends 0005's player model)

**Context.** Plays were purely anonymous — an `Attempt` carried only a signed
`player_token` cookie (ADR-0005: "no player accounts"). The owner wants a
logged-in user limited to **one play per puzzle**, shown **their result** (the
emoji cube + the solution) when they revisit, and wants **browse lists to mark
which puzzles they've already completed**. That requires attributing plays to the
account — a soft extension of 0005, not a separate player-account system.

**Decision.**

- **Attempts gain an optional `user_id`** (`belongs_to :user, optional: true`).
  A logged-in play is attributed to the account *and* still carries a
  `player_token`; anonymous plays are unchanged. `User has_many :attempts,
  dependent: :nullify` — deleting an account keeps the play in the puzzle's
  aggregate stats, just anonymized.
- **One play per logged-in user per puzzle**, enforced by a **partial unique
  index** `(user_id, puzzle_id) WHERE user_id IS NOT NULL`. `attempts#create` is
  idempotent for a signed-in repeat (returns the existing result, no duplicate
  row). Anonymous plays (NULL `user_id`) stay unconstrained/replayable — you
  can't reliably gate a cookie, and that's fine.
- **"Used up" = any finished attempt — win OR loss.** Attempts are only recorded
  at game-over, so a loss locks the puzzle just like a win.
- **`play#show` shows a result, not a board,** when a signed-in **non-owner** has
  an attempt for a complete puzzle: their cube, solved/lost status, a Share, and
  the **revealed answer groups** (they can't replay, so the solution is the
  payoff). Owners are **never** gated on their own puzzle. Anonymous visitors are
  unchanged.
- **`/play` badges completed puzzles** for signed-in users (a "✓ Played" chip),
  via `current_user.attempts.pluck(:puzzle_id)`.
- **Scope:** logged-in only. **No retroactive claim** of prior anonymous
  (cookie) attempts onto the account at login — deferred (see TODOS).

**Consequence.** Accounts now carry play history when logged in — attribution,
not a parallel player-account system; the anonymous `player_token` path is
untouched. The DB constraint makes "one play" a real invariant, not just a UI
gate. The home page's featured board is **not** yet result-gated (a logged-in
user who already played the featured puzzle still sees a fresh board there, though
a replay won't duplicate the attempt) — deferred. Read `Attempt` with the new
dual identity (`player_token` always; `user_id` when logged in).

---

## 0010 — Quartet specificity & discovery: `specialized` flag + tags + description (no subject categories)

**Date:** 2026-06-15
**Status:** accepted (authoring half built; surfacing half-built via 0018 — THEMED
chip + tag fold-outs + description spoiler shipped, and 0018 amends this ADR's
jump-in-strip exclusion; tag links, classic toggle, search still deferred — see TODOS)

**Context.** Goal: let authors make highly specific, non-general quartets (a Star
Wars grid, a kids-knowledge grid) and let solvers find or avoid them. A `grill-me`
pass worked the design. The early instinct — hard-coded subject categories + user
tags — kept tangling, because the meaningful axis isn't *topic*, it's *knowledge
fairness*: is this fair for a general NYT-style solver, or does it demand a
specific domain/fandom? A subject taxonomy can't express that (a "Mythology"
puzzle might be classic-fair Greek gods or deep-cut deities).

**Decision.**

- **`specialized` boolean** (default `false`). False = **"Classic"**: the
  encouraged, general, NYT-grade quartet. True = needs a specific body of
  knowledge — a fandom *or* a single domain (an all-sports grid). This is the
  trusted, filterable axis; it **replaces the subject-category dropdown entirely**.
- **Tags** — only when specialized. Freeform, **autocomplete against existing**,
  **hard-normalized to hyphen-slugs** (`Tag.normalize`: downcase + strip →
  `star-wars`). Stored as **polymorphic `tags` + `taggings` rows** (a `Taggable`
  concern), *not* a jsonb array, so an admin can merge/rename to fix cold-start
  divergence (admin tag-merge is in TODOS). Tags are optional even when specialized
  (showing them helps build the corpus).
- **`description`** — optional, ≤200 chars (`Puzzle::DESCRIPTION_LIMIT`, fits a
  Bluesky post + the URL). Will feed `og`/`twitter:description` + future search;
  never a publish gate.
- **Difficulty is NOT authored** — derive it later from completion stats
  (success/failure rates, maybe reputation-weighted). Out of scope here.
- **Deferred — the "discovery surfacing" half:** `/play` "Classic-style only"
  toggle (`?classic=1`), specialized puzzles' clickable tag chips → `/play?tag=…`,
  `description` → `og`, full-text search (post-corpus), pretty `/t/:tag` hubs.

**Consequence.** Authoring carries the metadata now (the form: a big "YES" toggle
reveals a creatable tag combobox + the description field), but nothing is
surfaced/filterable yet — the data sits unused until the deferred half lands. The
`Taggable` concern means any future model gets tags via `include Taggable`. No
subject taxonomy to curate. UI gotcha worth remembering: the toggle's reveal is
driven by an **`is-on` class** (controller-managed), not `:has(:checked)` — `:has`
doesn't reliably re-evaluate after a *programmatic* `.checked` change.

---

## 0011 — Trophies: flawless-win tiers, cumulative, on the attempt

**Date:** 2026-06-15
**Status:** accepted

**Context.** Players wanted recognition for *how* they win, not just that they
did. A full grill settled the shape: only a **flawless** win counts (solved with
**zero mistakes** — any mistake or a loss earns nothing), and the reward scales
with how hard you made it on yourself by the solve order (purple is hardest).

**Decision.**

- **Three nested tiers**, all requiring a flawless win:
  **perfect** (any order) → **purple_first** (first group solved is purple) →
  **reverse_rainbow** (purple→blue→green→yellow, hardest-first). The hierarchy is
  strictly nested, so counting is **cumulative**: a reverse rainbow also counts as
  a purple-first *and* a perfect ("you get all three trophies").
- **Storage:** one ordered, nullable `achievement` enum on **Attempt**
  (`{ perfect: 1, purple_first: 2, reverse_rainbow: 3 }`, nil = none — nil, not a
  zero value, to avoid colliding with the `Attempt.none` AR scope). Computed in a
  `before_create` from the guess log + zero-mistakes gate. Cumulative counts are a
  cheap `achievement >= n` (the `at_least(tier)` scope) — no denormalized counters.
  The solve order = the colors of the correct guesses; correctness is **derived**
  from the recorded colors (a guess is correct when its four tiles share one
  color), owned by the `Guess` value object — no stored flag.
- **Quips** live in `config/locales/en.yml` under `quartets.quips.{bucket}` (5
  buckets: `loss`, `mistakes`, `perfect`, `purple_first`, `reverse_rainbow`), each
  an array sampled at random per finished game. Each bucket needles you toward the
  next rung; only `reverse_rainbow` is pure praise (nothing above it).
- **Trophy visuals:** one fillable SVG silhouette (the stroke-only `icon` helper
  can't fill), recolored per tier — perfect = ink, purple-first = solid purple,
  reverse-rainbow = a striped purple→blue→green→yellow gradient (hardest at top).
  The `trophy(tier)` helper renders it.
- **Scope:** trophies + totals are **account-scoped**. Logged-in players get a
  running total of their top trophy; anonymous players see the trophies + quip for
  *that* game but **no total** — a sign-up nudge instead — because anonymous
  attempts aren't capped at one-per-puzzle (ADR-0009), so a cookie total would be
  farmable.
- **Display:** `attempts#create` computes the tier + total and returns a
  server-rendered awards partial (`play/_achievement`) the game injects on game
  over; the logged-in revisit view (`play/_result`) renders the same partial. The
  "Your stuff" dashboard (renamed from "My/Your quartets") leads with a trophy case
  (3 tiers + cumulative counts) over a stat row (Played · Solved · Solve rate ·
  Created); anonymous authors see only Created + a nudge.

**Consequence.** Trophies are derived, not stored as counters — adding a tier or
re-tuning the rules is a migration of the enum + a recompute, not a data backfill.
The guess log is load-bearing for trophies (solve order is read from each entry's
colors via `Guess`), on top of the cube/stats. **Deferred:** a **streak** stat on
the dashboard waits on the daily-puzzle frontpage (no "today" without it).

---

## 0012 — Finished-state on revisit: reconstruct the game-over board + gate anonymous replays

**Date:** 2026-06-16
**Status:** accepted (narrows 0009's anonymous-replay stance)

**Context.** Plays now record a full guess log (the `Guess` value object, ADR-0011
follow-up). The revisit view (ADR-0009) showed only a static "The answers" key in
authoring order — it didn't reflect how the player actually played. And ADR-0009
deliberately left **anonymous** plays replayable ("you can't reliably gate a
cookie, and that's fine"). The owner wants revisiting an already-played puzzle to
show it **in its finished state** — the board as it ended, the guesses made, the
emoji cube — and to **not be redoable**, for anonymous players too.

**Decision.**

- **Reconstruct the game-over board** from the recorded attempt, server-side and
  static (no controls): the four group rows revealed **in solve order**
  (`Attempt#solved_colors`, derived from the guess log's correct guesses), then any
  unsolved groups, the win/loss **stamp** ("Solved it" / "Out of guesses"), the
  **cube** + Copy, and the trophies/quip block (ADR-0011). Same markup as the live
  game's game-over screen. Replaces the old answer-key `_result`.
- **Gate non-owners by finished attempt.** `play#show` shows the finished board
  (not a fresh one) when a **non-owner** has an attempt: logged-in → their one
  attempt (unchanged from 0009); **anonymous → the most recent finished attempt for
  their `player_token`** (NEW). "Finished" = any recorded attempt (win or loss),
  since attempts are only recorded at game-over.
- **Owners are never gated** — they keep a replayable board on their own puzzle
  (test-play during authoring). Unchanged from 0009.
- **Anonymous gating is obscurity, not a lock.** Clearing the cookie or using
  another device replays — accepted, same philosophy as unlisted obscurity
  (ADR-0008). No retroactive claim of pre-login anonymous attempts (0009 unchanged),
  so a play recorded while logged out won't gate the same person once signed in.

**Consequence.** ADR-0009's "anonymous stays replayable" is **narrowed**: anonymous
players now see the finished state on revisit within the same cookie. The revisit
view is driven by the guess log (solve order), so it depends on `Guess`/`guess_log`.
The home featured board is still **not** result-gated (deferred, per 0009). The
emoji cube remains the canonical record of "the guesses I made"; the board
reconstruction shows the terminal revealed state.

---

## 0013 — Accessibility: WCAG 2.1 AA as a standing bar

**Date:** 2026-06-16
**Status:** accepted

**Context.** A full Lighthouse audit (mobile, dev server) put the site at a
uniform **95** accessibility — a strong baseline. The game was already
keyboard-operable (real `<button>` tiles, `aria-pressed`, `aria-live` status),
and solved groups render the category as **text**, so colour was never the only
signal (1.4.1 holds). But axe only automates a third of WCAG, and "95" left real
gaps: contrast misses on the near-black theme, no skip link or `<main>`, thin
focus styling, unlabelled answer inputs, role-less flash, and unguarded motion.

**Decision.**
- **Commit to WCAG 2.1 AA (or better) as a standing bar**, not a one-off cleanup.
  Tracked in [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md) (criterion → status
  → file), re-checked with Lighthouse after a11y-affecting changes.
- **Fixed this pass:** muted text moved off the light-theme `$color-muted` onto
  `$brutal-muted` and dropped the footer-disclaimer opacity (1.4.3); skip link +
  `<main id="main">` (2.4.1); global `:focus-visible` ring (2.4.7); `aria-label`
  on the sixteen answer inputs (3.3.2/4.1.2); `role`+`aria-live` on flash by
  severity (4.1.3); `prefers-reduced-motion` flattens tilt/lift (2.3.3); named
  the two `<nav>` landmarks (1.3.1). All eight audited surfaces now score **100**.
- **TDD split:** semantic/markup criteria are pinned in
  `spec/system/accessibility_spec.rb`; **contrast and reduced-motion are not
  RSpec'd** — asserting colour math against compiled CSS is brittle and
  low-value, so they're verified via Lighthouse instead.
- **Conscious exemptions:** `/styleguide` swatches (demo colour samples, holding
  them to AA defeats the purpose; unlinked internal tool) and the emoji **cube**
  (decorative share string). `meta-description` is missing but it's **SEO, not
  ADA** — deferred to a separate pass, noted only to explain the Lighthouse delta.

**Consequence.** Accessibility is now a durable promise with a paper trail, not
a vibe. New surfaces inherit the bar: any change that moves a criterion updates
`ACCESSIBILITY.md` and keeps `accessibility_spec.rb` green. `prefers-reduced-motion`
means the signature brutalist motion only flattens for users who opt out at the
OS level — the default experience is untouched.

---

## 0014 — Homepage is a launchpad, not a play surface

**Date:** 2026-06-19
**Status:** accepted (retires the home featured-board model referenced in 0009/0012)

**Context.** The homepage dropped visitors straight into a playable board — a
random *featured* puzzle, else a random *unplayed* published one (NYT "today's
puzzle" style). That only pays off with a deep, curated library; with a thin
archive it surfaced the same handful and buried the two things that actually
matter — that you can **play *and* author, free, no signup**. ADR-0009 and 0012
both left "gate the home featured board" as an unfinished follow-up.

**Decision.**
- **Home is a launchpad.** `home#show` renders no board and embeds no game. It
  serves a random strip of ≤5 published puzzles (`HomeController::STRIP_SIZE`,
  `RANDOM()`) inside full-bleed bands that front **Create/Play**, a "why play here"
  pitch, and a manifesto footer.
- **The global topbar + global footer are suppressed on home only** (new
  `home_page?` helper gates both in the layout). Home fronts its own nav — the
  Create/Play **fork** carries the `Primary` nav landmark the topbar usually would —
  and its own footer-as-section. Every other page keeps the global chrome.
- **The featured/unplayed-puzzle home logic is retired** (the `featured`-on-home
  path + the "you've done them all" empty state). `featured` as a column/concept is
  otherwise untouched, reserved for a future daily-puzzle slot (see TODOS).
- **All homepage copy lives in `en.yml`** (`home.*`).

**Consequence.** The "gate the home featured board" follow-up from 0009/0012 is
**moot** — there's no board on home to gate. `home_spec.rb` is rewritten to the
launchpad contract (no embedded game, no login wall, published-only strip, caps at
STRIP_SIZE, still mints `player_token`); `navigation_spec` + `pages_spec` move their
topbar/footer assertions to `/play`, since those are no longer site-wide. A future
daily-featured puzzle needs a *new* home slot decided, not a drop-in replacement.
The toggleable theme-skins idea (`8bit`/`broadsheet`) is scoped in
`docs/THEMES.md` on the `docs/theme-skins-plan` branch (not yet merged to
main/develop) but deliberately **not** an ADR until built.

---

## 0015 — Owners don't play their own puzzles

**Date:** 2026-07-06
**Status:** accepted (reverses 0009's "owners are never gated")

**Context.** ADR-0009/0012 left owners ungated on their own puzzles ("they replay
to test"). But an owner playing their own puzzle knows the answers: every "win"
pads their trophies and pollutes the puzzle's solve-rate stats, and with public
user pages coming, self-farmed stats would be visible fiction.

**Decision.**

- **`Playability` owns the rule** (one place, as before): `#playable?` is false for
  the owner; `#status` gains **`:owned`** (complete + yours).
- `play#show` renders an owner's complete puzzle **revealed** (`play/_revealed` —
  the four group rows in their solved state + a Share button), not playable. The
  author preview job (read your work, share it) survives; the play loop doesn't.
- `attempts#create` passes `owner:` into the same gate (via the `Creator` concern),
  so an owner POST records nothing — trophies and stats can't be self-padded.
  Applies to anonymous `creator_token` owners too.

**Consequence.** The archive auto-hides your own puzzles (they're dead rows to
you); the dashboard "Play" affordance now lands on the revealed view. Existing
self-attempts remain in the DB but can't grow. ADR-0009's owner exemption is gone;
its one-play cap and 0012's revisit reconstruction are unchanged for non-owners.

---

## 0016 — Handles, public user pages, and the superuser admin (settles D3)

**Date:** 2026-07-07
**Status:** accepted (completes the ADR-0005 accounts thread)

**Context.** D3 (per-creator public homepage) was deferred pending a handle model
and an `author_name` reconciliation rule. Separately, the admin dashboard that
gates the analytics build (TODOS) needed a role mechanism that didn't exist.

**Decision.**

- **Handle model:** `users.handle` — unique, minted at signup from the email's
  local part (parameterized, deduped with a numeric suffix), **backfilled** for
  existing accounts, and **stable** (an email change never touches it, so shared
  profile links keep working). No user-facing rename UI yet.
- **`author_name` reconciliation:** it stays the free-text *display* name on
  bylines; the handle is only the URL + page title. No forced sync.
- **`/u/:handle`** (public, login-free): the user's **published** puzzles + the
  dashboard's PlayerStats block ("Created" counts published only — drafts and
  unlisted stay private). Bylines site-wide link the author name there when the
  puzzle has an account owner (`author_link`); anonymous bylines stay plain.
- **Superuser:** a `users.superuser` boolean (console-anointed), gating a
  namespaced **`/admin`** — 404 (not 403) to everyone else. Puzzles tab = every
  puzzle with the owner dashboard's action rows (shared `puzzles/_row` partial;
  `PuzzlesController#set_puzzle` resolves through `accessible_puzzles`, which is
  `Puzzle.all` for superusers — same routes, no parallel admin CRUD). Users tab =
  paginated accounts with last-login (Devise **:trackable**, newly enabled),
  created + solved counts.

**Consequence.** The accounts epic (ADR-0005) is fully built. The analytics B/C
streams are unblocked (they wanted this dashboard as their home). Tag admin and
writeable user management are follow-ups (TODOS). Trackable's history starts at
enablement — older accounts show "never" until they next sign in.

---

## 0017 — The category palette is ours — never NYT's exact hexes

**Date:** 2026-07-07
**Status:** accepted

**Context.** The original palette exactly matched NYT Connections' pastels. Colors
alone aren't copyrightable, but a pixel-identical palette on a Connections-style
game is the strongest exhibit in a **trade-dress** claim — and the NYT demonstrably
enforces in games (the 2024 Wordle-clone takedown wave). If the site ever gets
noticed, exact hexes are free risk for zero benefit.

**Decision.** The yellow→purple difficulty *convention* stays (genre vocabulary),
but the values are ours: soft pastels in the same register, deliberately distinct
(`#f2c94c` golden vs their butter, `#8ed081` mint vs olive, `#8db4f2` sky vs
periwinkle, `#cf9bdb` lilac vs orchid). All four hold ≥9:1 with black text on the
fill and ≥8:1 as text on the near-black page. `_variables.scss` is the single
source; `RAINBOW_BANDS`, the styleguide, the favicon generator, and the share.png
source (`tmp/brand/share.html`) mirror it. On-page emoji cubes render as CSS
blocks in our palette (`cube_grid`); raw 🟨🟩🟦🟪 appear only in copied share text.

**Consequence.** Don't "fix" the palette back to NYT's values, ever — being
visibly-not-identical is the point. A palette change is a five-file sweep
(variables, helper bands, styleguide, the two `tmp/brand` generators) + regenerated
favicons/share.png (+ an OG `?v=` bump). Specs assert visible text via `page_text`,
not raw HTML, on multicolored surfaces.

---

## 0018 — Themed puzzles ride the jump-in strip flagged; owned puzzles leave it

**Date:** 2026-07-08
**Status:** accepted (amends 0010's strip exclusion; extends 0015 to browse surfaces)

**Context.** ADR-0010 kept `specialized` puzzles out of the homepage strip
because a themed quartet isn't a fair blind jump-in. That was the right call
when nothing *marked* them as themed. Meanwhile the strip had no ownership
filter at all: your own puzzles could land there, but owners can't play their
own work (ADR-0015) — the row dead-ends on a revealed board. The archive's
hide-mine filter also only covered accounts, so anonymous authors
(creator_token, ADR-0005) kept seeing their own puzzles everywhere.

**Decision.** A visible **THEMED chip** (purple, tilted, house chip language)
replaces the exclusion: the strip now draws from all published puzzles, and the
flag lets people dodge or chase themed ones. On list rows the chip is a
`<details>` fold-out revealing the tags (tap anywhere, hover on pointer
devices); the show page lays the tags out inline (inert — tag-filtered browse
is still TODO). Ownership filtering went the other way: a shared
`Puzzle.not_owned_by(user:, creator_token:)` scope (mirrors `Creator#owns?`,
NULL-safe via `IS DISTINCT FROM`) unconditionally excludes your own puzzles
from the strip and powers the archive's hide-mine for accounts *and* anonymous
creator cookies. The archive filter fold-out now shows for anyone with
something to filter (signed in, or holding a creator_token); the
hide-completed checkbox stays signed-in-only since completion is
account-tracked there.

**Consequence.** `HomeController` includes `Creator` now. A themed puzzle's
reach improved (strip + archive, flagged) — the "specialized puzzles need their
own discovery surface" pressure from ADR-0010 is partly relieved, though tag
chips/filters remain unbuilt. Rating aggregates shipped alongside
(`RatingSummary`: SUM(quality) as weighted thumbs since the enum ints are the
weights, AVG(difficulty) rounded to its label; unrated puzzles render nothing).

---

## 0019 — Soft-delete played puzzles (hybrid); hard-delete unplayed

**Date:** 2026-07-09
**Status:** accepted

**Context.** `Puzzle has_many :attempts, dependent: :destroy` meant deleting a
puzzle — one click, and `User has_many :puzzles, dependent: :destroy` on account
deletion — vaporized every *other* player's attempts on it, silently dropping
their trophy counts and played/solved stats. The system already cares about this
in the other direction (`User has_many :attempts, dependent: :nullify`, "so the
play still counts in the puzzle's aggregate stats"), so the cascade was an
oversight, not a considered trade-off. Surfaced in the 2026-07 review.

**Decision.** A **hybrid**: a puzzle with recorded attempts is **tombstoned**
(a `deleted_at` timestamp) instead of destroyed, so its attempts — and the
trophies/stats derived from them — survive; a puzzle with **no** attempts (an
abandoned draft, the common case) still hard-deletes to keep the table clean.
A `default_scope { where(deleted_at: nil) }` hides tombstones from every surface
at once (play-by-`share_token` included → 404), so no per-query changes were
needed. Superusers reach them via `with_deleted`/`only_deleted`; the admin
puzzles tab lists them flagged "Deleted" with a **Restore** action.
`accessible_puzzles` hands superusers `with_deleted` and owners their kept-only
scope, so a normal owner can't even find a tombstone (404) — that's what gates
restore to the admin.

**Consequence.** Deleting a played puzzle is now reversible and non-destructive
to players. `default_scope` carries the usual footgun (it's the base for all
queries) — mitigated by keeping it a plain `deleted_at IS NULL` and reaching
around it explicitly (`with_deleted`) in the one place that needs to. No UI to
let owners see/restore their own tombstones yet (admin-only); revisit if authors
ask. Hard vs soft is decided in `PuzzlesController#destroy` off `attempts.exists?`.

---

## 0020 — Moderator role + puzzle reporting (moderation for a public launch)

**Date:** 2026-07-09
**Status:** accepted

**Context.** Authoring is public and anonymous (ADR-0005). Fine at private scale;
a liability the moment the site gets promoted (e.g. r/nytconnections) — someone
will publish spam or something offensive, and there was no way for players to
surface it and no role short of full superuser to police it. The 2026-07-09
community audit flagged this as the closest thing to a launch blocker.

**Decision.** Two pieces. **A moderator role**: a second boolean on `users`
alongside `superuser`. Moderators get the /admin *puzzles* tab and the same
puzzle-moderation bypass (unpublish, delete/restore any puzzle) but **no user
admin** — the Users tab 404s them and its nav link doesn't render.
`User#staff? = superuser? || moderator?` is the union that gates the shared
surfaces; `User.staff` scopes the report-alert recipients. Blessing is
console-only (`user.update!(moderator: true)`) — no UI to grant roles yet.
**Reporting**: a quiet fold-out on the play page files a `Report` (one per
reporter per puzzle, unique-indexed, optional reason). A new flag emails every
staff member (`AdminMailer#puzzle_reported`, `deliver_later`, best-effort like all
our mail). The admin puzzles tab surfaces flags: a count banner, a `?flagged=1`
triage view, a per-row badge, and a **Dismiss reports** action (mark handled
without touching the puzzle — for false alarms; a real takedown just
deletes/unpublishes, and the reports ride along via `dependent: :destroy`).

**Consequence.** Trusted non-owners can moderate content without account access,
and bad puzzles get surfaced by the crowd instead of festering. Notification is
email-only by choice — Discord was floated and rejected. Reporting is rate-limited
(10/hour) since "report" is itself an abuse vector. Deliberately *not* built:
role-granting UI (console is fine for a handful of mods), report categories/reasons
taxonomy (free-text is enough), and auto-hiding heavily-flagged puzzles (manual
review only — no brigading-driven takedowns).

---

## Adding new decisions

Append using the template above. Status is one of: `proposed` | `accepted` | `superseded by NNNN` | `deprecated`.
