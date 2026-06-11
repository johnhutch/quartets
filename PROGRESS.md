# Progress

**Last updated:** 2026-06-10
**Active branch:** main

Current state + a rolling shipped-log. Planned/not-started work lives in `TODOS.md`; the *why* behind decisions lives in `DECISIONS.md`.

---

## Current focus

The app plays **end-to-end** — author → publish → share link → play → stats →
emoji cube — and the brutalist design now covers the whole site. Phases 0–4 are
done; Phase 5 (import + export) is mostly there.

The open frontier is the **auth & accounts epic**: reverse the superuser-only
gate so **anyone can create a puzzle without logging in** (restores an original
spec that got lost), then claim-on-signup, a logged-in "my puzzles" stats
dashboard, and per-creator public homepages (`/u/:handle`). It's gated by open
decisions **D1–D4** in `TODOS.md` — **work those through `grill-me` first and
write the outcomes into `DECISIONS.md`** before building (D2 explicitly rewrites
the "superuser-only creation" decision in `CLAUDE.md`/`DECISIONS.md`). The
quick-wins (richer share payload, debounce tune) need no
decisions and can go anytime. Deploy is decided (Synology, ADR-0004) but **not
yet run end-to-end** — waits on one-time NAS setup.

## Shipped log (most recent first)

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
  headers. Spec flipped determinism → re-roll. (Same branch added `VOICE_heckle.md`
  — a for-fun "Hutch heckles Jake" persona, not wired into anything.)
- **Design system (brutalist)** — `_brutal.scss`, Space Grotesk webfonts, a
  `/styleguide` page, and `Multicolor` (the wordmark colorizer). Dropped the
  generated GitHub Actions CI (archive-only repo, no CI/CD).
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
  no registry, no CI. Runbook in `docs/DEPLOY.md`.
- **Phase 2 — authoring.** Color-coded form (swellgarfo order, answers-first),
  gated `PuzzlesController`, owner-scoped dashboard, publish action, and
  **auto-save drafts** (debounced `autosave_controller.js`: POST to mint, then
  PATCH; title is publish-only so untitled drafts persist). Request + system specs.
- **Phase 0/1 — foundation.** Rails 8 + Postgres + Sass (SMACSS), RSpec/Capybara/
  factory_bot, headless-Chrome phone-viewport system-spec harness, Devise
  (superuser-only), and the `Puzzle`/`Group`/`Attempt` models + validations.

## Known not-done / watch-outs

- **Settle D1–D4 (`TODOS.md`) via `grill-me` before the auth epic** — anonymous-
  draft ownership, the auth-gate reversal (rewrites the superuser-only decision),
  creator handles for `/u/:handle`, and which Devise modules. Record outcomes in
  `DECISIONS.md` first.
- **Quick wins, no decisions needed:** richer share payload (cube + title + direct
  link), extend the author→publish system spec through to the `/p/:share_token`
  page, and tune the 1000ms auto-save debounce on a real phone.
- **Auth polish on today's model:** style the Devise login/signup screens
  on-theme, wire `recoverable`, and the logged-in "view my puzzles" stats table.
- **Mobile pass** (real iPhone), **first Synology production deploy** + smoke test,
  and **seeding the superuser** — the remaining Phase 0/5 ⬜s.
- `docs/PLAN.md`'s schema sketch calls `Group#words` a "PG array"; it's actually a
  **jsonb** column. Treat jsonb as the truth.
