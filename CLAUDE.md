# CLAUDE.md

Project context and working agreements for Claude Code on **Quartets**.

## What this is

A Rails app for creating and playing NYT Connections–style puzzles. It replaces
a clunky manual workflow: the user used to author puzzles in Obsidian and
hand-type them into swellgarfo's form fields — brutal on an iPhone, which is the
primary device. This app *is* the creator + player now. Obsidian is no longer in
the loop (the existing `.md` archive gets imported once via a rake task, then
retired).

## Decisions already made (from the design interview)

Don't relitigate these without a reason — they came out of a full grill-me pass.

- **Stack:** Rails 8, Turbo/Stimulus, importmap (no Node build step), PostgreSQL.
- **CSS:** Sass, organized SMACSS. **No Tailwind, no utility-class soup.** Four
  partials + manifest (see `app/assets/stylesheets/`). Naming: `l-`/`m-`/`is-`.
- **Auth:** Devise (`registerable` + `recoverable`, no `confirmable`). Creation,
  playing, and stats are all **public** — no login required to author or play
  (ADR-0005 reversed the old superuser-only gate). Accounts are optional: they
  let you *own* and revisit your puzzles across devices.
- **Anonymous ownership:** a logged-out author's puzzles ride a signed,
  permanent `creator_token` cookie (mirrors the player_token). Signing in/up
  **claims** the cookie's puzzles onto the account, then clears the cookie. See
  ADR-0005 (settles D1–D4).
- **Players:** anonymous, cookie/session-based identity for stats. No player
  accounts (can layer on later).
- **Creation UX:** color-coded form (Blue/Green/Yellow/Purple), Answers +
  Description per group. **Auto-save as drafts** via debounced Turbo — this is a
  hard requirement, born from losing work to the iOS back button. Drafts live on
  the author's dashboard (`/puzzles`) — scoped by account or `creator_token`.
- **Play UX:** full interactive game via our own compact **Stimulus**
  `game_controller.js` — no React (hard no), no Node build (importmap). We
  originally meant to embed an existing engine, but none exists that's vanilla,
  permissively licensed, and importmap-droppable; see ADR-0003.
- **Stats per puzzle:** total attempts, solve rate, mistakes per attempt, common
  wrong guesses, shareable emoji-cube (🟨🟩🟦🟪).
- **Export:** JSON download per puzzle.
- **Hosting:** self-hosted on a Synology DS918+ via DSM Container Manager. Dev is
  native (no Docker locally). Deploys are **push-to-`main`**: a GitHub Actions
  workflow (`.github/workflows/deploy.yml`) builds the `linux/amd64` image and
  pushes it to **GHCR**; **Watchtower** on the NAS polls GHCR and recreates the
  `web` container. A **Caddy** front proxy (tunnel → caddy → web) absorbs the
  ~10-15s restart so deploys don't 502. Public access is a Cloudflare Tunnel (no
  open ports). Not Render, not Heroku. The old SSH `bin/deploy` is gone — see
  ADR-0006 + ADR-0007 in `DECISIONS.md` + `docs/DEPLOY.md`.
- **Testing:** RSpec + Capybara, TDD. Write the failing test first.

## Voice

All comments, docs, commit messages, and public-facing copy stay confident,
pragmatic, grounded, a little swagger, no agency fluff. Calibrate by medium —
README/UI copy can have personality; code
comments stay useful and terse; commit messages match the casual existing log
style. Don't shoehorn client-email openers ("Hey there [Name]") into docs that
have no recipient.

## Conventions

- **TDD:** red → green → refactor. New behavior gets a spec first.
- **CSS:** put rules in the right SMACSS layer. Theme values (colors, spacing,
  type) go in `_variables.scss` — no magic numbers in modules.
- **Sass build:** `bin/rails dartsass:build` (or `bin/dev` runs the watcher).
  Source is `application.scss`; never edit `app/assets/builds/`.
- **Ruby:** pinned to 4.0.4 in `.ruby-version`. The non-interactive shell may
  default to system Ruby — activate the right one before running `bundle`.

## Session Workflow

**Start.** A `SessionStart` hook (`.claude/hooks/session_start.sh`) auto-injects PROGRESS.md + the last 5 commits into context every session — current state is normally already loaded; no need to open PROGRESS.md by hand. Read CONTEXT.md, DECISIONS.md, and TODOS.md **on demand** when the task touches domain/models, prior decisions, or planned work. Confirm current state and next action before proceeding.

**End.** Run `/wrap` before stopping — it reconciles PROGRESS / TODOS / DECISIONS / CONTEXT with the session's work (`.claude/commands/wrap.md`). The durable habit: update PROGRESS's shipped-log in the *same commit* as the code it describes; `/wrap` is the backstop. A long idle gap (>30 min) triggers a `/wrap` reminder via `.claude/hooks/idle_reminder.sh`.

## Current state

Rails scaffold generated, Postgres + Sass wired, SMACSS structure built and
compiling. No models, controllers, or game UI yet. Next steps and full sequence:
[`docs/PLAN.md`](docs/PLAN.md).
