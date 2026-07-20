# Quartets

A Rails app for building and playing NYT Connections–style puzzles. Make a
puzzle, share a link, watch your friends fumble the purple group. Built because
hand-filling a third-party form on an iPhone — eight fields a puzzle, tab tab
tab — is its own little hell.

**TL;DR:** you author puzzles in a color-coded form that auto-saves as you go,
publish them, and anyone can play the full interactive game. Stats and a
shareable emoji-cube result come along for the ride.

## What it does

- **Author** — a Blue / Green / Yellow / Purple form, four answers + a category
  description per group. Auto-saves drafts so an accidental back button on
  mobile doesn't nuke your work.
- **Play** — the real deal: 4×4 grid, tap four, submit, reveal groups, count
  mistakes. Public — no login to play, puzzles are browsable.
- **Brag** — the standard 🟨🟩🟦🟪 result cube, shareable over text.
- **Stats** — per puzzle: attempts, solve rate, mistakes per attempt, the
  common wrong guesses.
- **Export** — JSON download for any puzzle.

## Stack

| Piece | Choice |
|---|---|
| Framework | Rails 8 (Turbo + Stimulus, importmap — no Node build) |
| DB | PostgreSQL |
| CSS | Sass, organized **SMACSS**. No Tailwind. |
| Auth | Devise — superuser-only for creation; play is public |
| Game UI | Our own compact vanilla-JS engine on Stimulus — no React, no Node build |
| Tests | RSpec + Capybara, TDD |
| Hosting | Self-hosted via Docker |

## Getting it running

```bash
# Ruby is pinned in .ruby-version (4.0.4)
bundle install
bin/rails db:create db:migrate
bin/dev                 # boots Rails + the dartsass watcher (see Procfile.dev)
```

Then visit `http://localhost:3000`.

**Seeding your archive:** there's a rake task to import existing puzzles from
the original Obsidian `.md` file —

```bash
bin/rails puzzles:import_obsidian
```

## CSS / SMACSS layout

Sass compiles `app/assets/stylesheets/application.scss` →
`app/assets/builds/application.css` via dartsass-rails. The partials follow
SMACSS categories, four files plus the manifest:

```
stylesheets/
  application.scss   # @use the layers in order
  _variables.scss    # theme: the 4 category colors, spacing, type scale
  _base.scss         # element defaults + layout primitives
  _modules.scss      # m-board, m-card, m-group, m-cube, m-stats, m-form
  _state.scss        # .is-selected, .is-revealed, .is-wrong, .is-draft
```

Naming convention: `l-` layout, `m-` module, `is-` state. Theme tokens live in
`_variables.scss`.

## Where we're at

Plays end-to-end — author → publish → share → play → stats → emoji cube — with
the brutalist design across the whole site. The phased build plan lives in
[`docs/PLAN.md`](docs/PLAN.md); the rolling state + shipped log in
[`PROGRESS.md`](PROGRESS.md).

## License

Quartets is **dual-licensed**, because it's both software and creative work:

- **Code** — the Rails application and all source — under the **MIT License**
  ([`LICENSE`](LICENSE)). Reuse it freely.
- **Content** — the puzzles, written copy, and docs — under **Creative Commons
  Attribution 4.0** ([`LICENSE-CONTENT`](LICENSE-CONTENT)). Reuse with credit.

© 2026 John Hutchinson ([johnhutch.com](https://johnhutch.com)).

**Bundled fonts** ship under the SIL Open Font License 1.1 (Space Grotesk and
UnifrakturMaguntia); their full license texts sit beside the font files in
[`app/assets/fonts/`](app/assets/fonts/), as the OFL requires.

### Not affiliated with The New York Times

Quartets is an independent project. It is **not affiliated with, endorsed by, or
connected to The New York Times** or any of its subsidiaries. "Connections" and
"The New York Times" are trademarks of The New York Times Company.
