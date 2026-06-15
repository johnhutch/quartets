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

## Adding new decisions

Append using the template above. Status is one of: `proposed` | `accepted` | `superseded by NNNN` | `deprecated`.
