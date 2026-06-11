# Progress

**Last updated:** 2026-06-10
**Active branch:** main

Current state + a rolling shipped-log. Planned/not-started work lives in `TODOS.md`; the *why* behind decisions lives in `DECISIONS.md`.

---

## Current focus

The app plays **end-to-end** — author → publish → share link → play → stats →
emoji cube — and the brutalist design now covers the whole site. Phases 0–4 are
done; Phase 5 (import + export) is mostly there.

The **auth & accounts epic shipped** (ADR-0005): creation is now fully public,
anonymous authors own their work via a `creator_token` cookie, signing in/up
claims it, and the styled Devise flows (signup/login/logout/forgot-password) are
on-theme. What's left of that thread: the per-creator **public homepage
(`/u/:handle`)** — deferred (D3) — and turning the dashboard's per-puzzle Stats
links into an **at-a-glance aggregate table**. The remaining quick-wins (richer
share payload, debounce tune) need no decisions. Deploy is decided (Synology,
ADR-0004) but **not yet run end-to-end** — waits on one-time NAS setup, where the
SMTP creds for forgot-password mail also get filled into the NAS `.env`.

## Shipped log (most recent first)

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

- **Per-creator public homepage `/u/:handle`** — deferred (D3, ADR-0005). Needs a
  stable per-account handle/slug and how free-text `author_name` reconciles with a
  claimed account. The last unbuilt piece of the accounts thread.
- **"My puzzles" aggregate stats table** — the dashboard lists puzzles with a
  per-puzzle `Stats` link; the planned at-a-glance table (completions, *successful*
  completions, avg mistakes inline per row) is still TODO.
- **Quick wins, no decisions needed:** richer share payload (cube + title + direct
  link), and tune the 1000ms auto-save debounce on a real phone.
- **SMTP creds for prod** — forgot-password mail is wired and previews in dev
  (`letter_opener`); production reads `SMTP_*` from the NAS `.env`, to be filled at
  first deploy. Until then prod swallows delivery errors so the app boots clean.
- **Mobile pass** (real iPhone), **first Synology production deploy** + smoke test,
  and **seeding a first account** — the remaining Phase 0/5 ⬜s.
- `docs/PLAN.md`'s schema sketch calls `Group#words` a "PG array"; it's actually a
  **jsonb** column. Treat jsonb as the truth.
