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
**Status:** accepted (authoring half built; the discovery *surfacing* half is deferred — see TODOS)

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
  This required the JS to start logging each guess's `correct` flag (the solve
  order = the colors of the correct guesses).
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
The guess log is now load-bearing for trophies (each entry needs `correct`), on
top of the cube/stats. **Deferred:** a **streak** stat on the dashboard waits on
the daily-puzzle frontpage (no "today" without it).

---

## Adding new decisions

Append using the template above. Status is one of: `proposed` | `accepted` | `superseded by NNNN` | `deprecated`.
