# Progress

**Last updated:** 2026-06-06
**Active branch:** main

Current state + a rolling shipped-log. Planned/not-started work lives in `TODOS.md`; the *why* behind decisions lives in `DECISIONS.md`.

---

## Current focus

Phase 2 (authoring) is complete — auto-save drafts was the last piece. The open
frontier is **Phase 3 (play): pick the game engine + build the public play page.**
The **Phase 0 Render deploy** is still unwired and worth doing before Phase 3 grows.

## Shipped log (most recent first)

- **Auto-save drafts** — debounced Stimulus controller (`autosave_controller.js`):
  first edit POSTs to mint the draft, then flips the form to PATCH it. Endpoint
  answers quietly (201 + `Location`, then 204). `Puzzle#title` is now publish-only
  so untitled partial drafts persist. Covered by `puzzle_autosave_spec.rb`.
- **System-spec harness** — headless Chrome at a phone viewport
  (`spec/support/capybara.rb`), guarding against chromedriver/Chrome version
  drift; auto-save resilience + author/publish system specs. Also cleaned a
  malformed global `~/.bundle/config` that was breaking `bundle exec`.

## Known not-done / watch-outs

- This session's work is **uncommitted** as of wrap.
- The full author→publish→**share URL** system spec is parked on Phase 3 — no
  public play page exists to land on yet.
- `docs/PLAN.md`'s schema sketch calls `Group#words` a "PG array"; it's actually
  a **jsonb** column. Treat jsonb as the truth.
