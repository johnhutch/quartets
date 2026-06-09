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

## Adding new decisions

Append using the template above. Status is one of: `proposed` | `accepted` | `superseded by NNNN` | `deprecated`.
