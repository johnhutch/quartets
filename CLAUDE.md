# CLAUDE.md

Project context and working agreements for Claude Code on **Link the Things**.

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
- **Auth:** Devise. Superuser-only for puzzle *creation*. Playing is **public** —
  puzzles are browsable, no login to play.
- **Players:** anonymous, cookie/session-based identity for stats. No player
  accounts (can layer on later).
- **Creation UX:** color-coded form (Blue/Green/Yellow/Purple), Answers +
  Description per group. **Auto-save as drafts** via debounced Turbo — this is a
  hard requirement, born from losing work to the iOS back button. Drafts live on
  the superuser dashboard.
- **Play UX:** full interactive game. **Embed an existing open-source
  vanilla-JS / Stimulus Connections engine** — do not build the game loop from
  scratch, and **no React** (hard no).
- **Stats per puzzle:** total attempts, solve rate, mistakes per attempt, common
  wrong guesses, shareable emoji-cube (🟨🟩🟦🟪).
- **Export:** JSON download per puzzle.
- **Hosting:** Render, auto-deploy from GitHub on push to `main`. Not Heroku.
- **Testing:** RSpec + Capybara, TDD. Write the failing test first.

## Voice

All comments, docs, commit messages, and public-facing copy follow
[`VOICE.md`](VOICE.md): confident, pragmatic, grounded, a little swagger, no
agency fluff. Calibrate by medium — README/UI copy can have personality; code
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
