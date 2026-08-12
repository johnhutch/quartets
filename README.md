# Quartets

**Sixteen words. Four groups. One increasingly smug purple category.**

A free, open-source puzzle site in the style of NYT Connections. Make your own
puzzles, share a link, watch your friends fumble the purple group. Play at
**[playquartets.com](https://playquartets.com)**.

No account required to make one. No account required to play one. No ads, no
tracking, no email harvesting, no "unlock premium quartets for $4.99/mo."

---

## Why this exists

I'm very good at Connections. Not to brag, but my long streak of perfects was 67
days and the puzzle that broke it was a misclick.

Problem is, the format isn't theirs. Sixteen items, sort them into four connected
groups of four — that's the Connecting Wall from the BBC's *Only Connect*, on
British television since 2008. The NYT shipped it in 2023 with no credit, watched
it print money, and then in 2024 fired DMCA takedowns at hundreds of Wordle
clones — including an open-source one and, by extension, the ~1,900 projects that
had forked it. Hobbyists. Students. People making a Wordle for their kid's
spelling words. On legal ground that IP lawyers politely called "a little bit
shaky," because you generally can't copyright the rules of a game or a grid of
colored squares.

Take a format from a British game show, ship it uncredited, then aim your legal
department at hobbyists doing the same thing smaller and for free. That's
artisanal, small-batch hypocrisy.

So I made this instead, and I put it here so you can have it too. Clone it, run
your own, change whatever you want. Steal This Book style.

## What it does

- **Author** — a color-coded form (yellow → green → blue → purple, easiest to
  hardest). Four answers and a category per group. It **auto-saves as you type**,
  because I lost a finished puzzle to the iOS back button exactly once and
  decided that would never happen again.
- **Play** — the real loop. Tap four, submit, reveal or eat a mistake, four
  strikes and you're done. Wrong guesses stay selected so you can adjust instead
  of starting over. No login.
- **Brag** — the emoji cube 🟨🟩🟦🟪 for the group chat, plus trophies for a
  flawless win: perfect, purple-first, and the full reverse rainbow.
- **Share** — every puzzle gets an unguessable link. Publish it to the archive or
  keep it unlisted and just send the link around.
- **Rate** — after you finish, say whether it was any good and how hard it was.
  Aggregates show up on the browse pages.
- **Stats** — per puzzle: attempts, solve rate, mistakes, median solve time,
  common wrong guesses, and the paths people took through the four groups.
- **Resume** — leave mid-game, come back, the board's how you left it. Signed in,
  that follows you across devices.
- **Export** — JSON download for any puzzle you own. It's your work.

## Quick start

Ruby is pinned in `.ruby-version` (4.0.4). You need PostgreSQL. You do **not**
need Node — there's no JS build step, and that's on purpose.

```bash
bundle install
bin/rails db:prepare      # create, migrate, seed
bin/dev                   # Rails + the Sass watcher (see Procfile.dev)
```

Then hit `http://localhost:3000`.

The seeds build a full dev environment — a cast of authors, puzzles in every
state, and plays built from real guess logs so the derived stats are genuine.
It prints a login cheat sheet when it's done. Re-running changes nothing.

```bash
bundle exec rspec                 # the whole suite
bin/rails dartsass:build          # build CSS once instead of watching
```

System specs run headless Chrome at a phone viewport, because this is a phone
app that happens to work on a desktop.

## How it's built

| Piece | Choice |
|---|---|
| Framework | Rails 8, Turbo + Stimulus on importmap |
| Database | PostgreSQL (one, doing double duty for Solid Queue/Cache/Cable) |
| CSS | Sass, SMACSS layers. No Tailwind. |
| Game | ~500 lines of vanilla JS in one Stimulus controller |
| Auth | Devise, optional — only for owning your work |
| Tests | RSpec + Capybara, TDD |
| Hosting | Self-hosted on a Synology NAS behind a Cloudflare tunnel |

A few of those deserve an explanation, because they're the ones you'd otherwise
"fix" in your first week.

**No Node build.** Importmap, full stop. Adding a bundler to a Rails app this
size buys you a `node_modules` directory, a lockfile, a build step, and a
supply-chain surface, in exchange for approximately nothing.

**We wrote the game engine.** The original plan was to embed an existing
open-source Connections engine. I went looking. Every maintained one is
React/Next. The vanilla-looking ones are TypeScript + Vite (so, a Node build)
and mostly unlicensed. The loop is small and well understood — shuffle sixteen,
select four, submit, match or mistake, lock the solved row, win or lose. So we
own it, and the guess log it emits is exactly the shape the stats need.

**No Tailwind.** Four Sass partials and a manifest. Naming is `l-` layout,
`m-` module, `is-` state. Colors, spacing and type live in `_variables.scss` and
nowhere else — if you're writing a hex code in a module, stop.

**Everything is publish-only validated.** A draft can be blank, half-typed,
missing a title, whatever. Auto-save has to be able to land *anything*, or it
fails under you mid-edit, which is the exact problem it exists to solve. The 4×4
structural rules only bite when you publish.

**Anonymous-first.** A logged-out author owns their puzzles through a signed
permanent cookie. Sign up later and it claims them onto your account. Players
are anonymous too — stats ride a `player_token` cookie, and there are no player
accounts to make.

**Owners don't play their own puzzles.** You know the answers. Your own board
renders revealed, and the server refuses attempts on it, so nobody farms
trophies off their own work.

## The domain, briefly

- **Puzzle** — one board. `status` is *visibility* (`unlisted` or `published`),
  and that's all it is. Whether a puzzle can be **played** is derived from
  `#complete?` — a finished puzzle plays for anyone with the link whether or not
  it's listed. The three author-facing states are incomplete, unlisted, and
  published.
- **Group** — one of the four colored categories. `words` is a **jsonb** column,
  not a PG array. Authors can swap two groups' colors from the legend, so the
  form sorts by color at render, not by stored position.
- **Attempt** — one play-through. Anonymous plays carry a `player_token`;
  signed-in plays also attribute to the account and are capped at one per puzzle.
  Every stat in the app — cube, trophies, wrong-guess frequency, solve paths —
  derives from the `guesses` jsonb. There are no rollup tables to keep in sync.
- **PlayState** — the save-game for a play in progress. Deleted the moment the
  attempt records.

Naming quirk worth knowing: the UI calls a puzzle a **quartet**. The model,
table, and routes all say `Puzzle`. That's deliberate — don't "fix" one to match
the other.

## Layout

```
app/
  models/            Puzzle, Group, Attempt, PlayState + a pile of value objects
                     (Guess, EmojiCube, PlayResult, PuzzleStats, RatingSummary,
                     Playability, PlayRecording…)
  controllers/       thin; concerns own the cookie identities
  javascript/        Stimulus controllers, no build step
  assets/stylesheets/
    application.scss   @use the layers in order
    _variables.scss    the four category colors, spacing, type
    _base.scss         element defaults, layout primitives
    _modules.scss      m-board, m-card, m-game, m-form…
    _state.scss        is-selected, is-wrong, is-dupe
    _brutal.scss       the theme
```

The value objects are where the interesting logic lives. `Guess` owns the
guess-log shape and the "is this group correct" rule, so `EmojiCube`,
`PuzzleStats` and the trophy calculation all read the same thing instead of each
re-implementing it. `Playability` owns the four-way play gate. `PlayRecording`
rebuilds a play from the puzzle server-side, so the public attempts endpoint
trusts the client for the *words grouped* and nothing else.

Never edit `app/assets/builds/` — it's generated.

## Things that will bite you

Genuinely load-bearing, learned the hard way:

- **Auto-save's endpoint contract** is 201 + `Location` on create, 204 on
  update, no redirects. `autosave_controller.js` depends on it. Don't normalize
  it back to redirects.
- **Auto-save fires on `input`, not `change`.** `change` fires on blur and
  double-saves. Any JS that sets a field's value must dispatch an `input` event
  or the save won't happen.
- **`:has(:checked)` doesn't re-evaluate when JS sets `.checked` programmatically.**
  Use a controller-managed class instead. Cost me an afternoon.
- **An explicit `display` beats the UA `[hidden]` rule.** Anything hidden by
  default that also sets `display` needs its own `&[hidden] { display: none; }`.
  This has bitten three separate times.
- **Grid items that need to shrink want `minmax(0, 1fr)`,** not `1fr` — plain
  `1fr` has an implicit min-width of min-content, so one long unbreakable word
  blows the column out.
- **Capybara's `text:` sees CSS `text-transform`.** The theme uppercases a lot.
  Assert with a case-insensitive regex.
- **Loose files in `public/` cache for an hour, not a year.** Digest-stamped
  assets are immutable and get the year; `robots.txt` and the favicons don't. A
  year-long edge cache on `robots.txt` is how a robots change goes invisible for
  a very long time.

## Privacy, and the AI thing

The privacy page says no analytics, no pixels, no third parties. That's meant
literally, so the measurement is **100% first-party and server-side** — no client
script, no cookies, no third party, no exceptions. Page views are logged with
path, referrer and user agent. Not IPs. Not a device fingerprint. Nothing that
identifies you.

Yes, that means the dashboards are less pretty. The promise was worth more than
the dashboards.

On crawlers: `public/robots.txt` allows AI **search and citation** crawlers and
blocks AI **training** crawlers, with a `Content-Signal` header saying the same
thing, backed by a Cloudflare rule that actually enforces it. Search engines and
answer engines are welcome to send people here. Nobody's welcome to eat it for
training.

## Accessibility

WCAG 2.1 **AA** is the standing bar, not an aspiration. Lighthouse accessibility
sits at 100 across the core surfaces.

The game is keyboard-operable — the tiles are real `<button>`s with
`aria-pressed`, status and mistakes are `aria-live`, and solved groups render the
category name as text so color is never the only signal. Everything honors
`prefers-reduced-motion`. Semantics are pinned by
`spec/system/accessibility_spec.rb`; contrast and motion are verified with
Lighthouse, because asserting color math against compiled CSS in RSpec is
brittle and proves nothing.

If you find something that doesn't work with your setup, that's a bug and I want
to hear about it.

## Deploying your own

It runs anywhere Rails runs — it's a stock Dockerfile, Puma binds `$PORT`, and
config comes from the environment. Mine runs on a Synology DS918+ in my house.

The setup, if you're curious: push to `main` → GitHub Actions builds a
`linux/amd64` image → GHCR → Watchtower on the NAS notices and recreates the web
container. A Caddy proxy sits in front so the ~15 seconds of restart doesn't
throw 502s, and a Cloudflare tunnel exposes it without opening a port on my
router.

```bash
docker-compose up -d          # db, web, caddy, cloudflared, watchtower
```

Config lives in a `.env` beside `docker-compose.yml` — copy `.env.example`. The
container entrypoint runs migrations on boot, and **backs the database up first
whenever a deploy is about to change the schema** (`bin/backup-before-migrate`).
Dumps land in `./backups`, newest ten kept. That directory has to be writable by
uid 1000 or the app won't boot — that's deliberate, since the alternative is
migrating production data with no safety net.

To restore one:

```bash
docker-compose stop web
gunzip -c backups/quartets-<timestamp>-pre-<sha>.sql.gz \
  | docker-compose exec -T db psql -U quartets -d quartets_production
docker-compose start web
```

`pg_dump` is pinned to 17 in the Dockerfile to match the Postgres image, because
it refuses to dump a server newer than itself. Bump them together.

## What's next

Nothing here is a promise. It's what I'd build next if left alone with it.

**Blessed quartets.** Every published puzzle currently counts the same, which
means your mate's in-joke about his dog can dent a stranger's solve rate. The
plan is to *bless* a curated set — the ones a person could reasonably solve cold,
with no context — and treat that as the real catalog. Anyone can still publish
anything; blessing just decides what's held up as representative.

**A daily quartet, off the blessed pool.** One puzzle a day, same one for
everyone, picked automatically from the blessed set. That's the ritual the whole
format runs on, and it's the thing that makes a shared result cube worth posting.
It needs a critical mass of genuinely good puzzles first, which is the actual
blocker — not the code.

**Separate stats for the blessed track.** Solve rate, streaks and a leaderboard
scoped to blessed puzzles only, so the number means something. Your all-time
figures stay as they are; the blessed track is the one that counts.

**Smaller stuff.** Clickable tags (they render, they just don't filter yet),
search across titles and descriptions, and a bulk CSV export of everything
you've made.

## Contributing

Yes please. A few house rules so we don't fight about it later:

1. **Tests first.** New behavior gets a failing spec before it gets code. The
   suite is fast and green; keep it that way.
2. **CSS goes in the right layer,** and theme values go in `_variables.scss`. No
   magic numbers in modules.
3. **No new build steps.** If a change needs npm, it needs a very good argument.
4. **Match the surrounding code.** Comment density, naming, the lot.

Bug reports are welcome and so are puzzles. If you build a genuinely fiendish
one — the kind with a purple group so infuriating it should be classified as a
war crime — publish it and send it my way. I will solve it first try, screenshot
the result, and be completely insufferable about it.

## License

Dual-licensed, because it's both software and creative work:

- **Code** — MIT ([`LICENSE`](LICENSE)). Take it.
- **Content** — *our* puzzles, copy and docs — CC BY 4.0
  ([`LICENSE-CONTENT`](LICENSE-CONTENT)). Take it, with credit.
- **User puzzles** — not ours to license. Quartets made by users on the hosted
  site belong to their creators, full copyright retained; the site takes only a
  narrow hosting license ([playquartets.com/terms](https://playquartets.com/terms)).

Bundled fonts (Space Grotesk, UnifrakturMaguntia) ship under the SIL Open Font
License 1.1; the license texts sit beside the fonts in
[`app/assets/fonts/`](app/assets/fonts/), as the OFL requires.

© 2026 John Hutchinson · [johnhutch.com](https://johnhutch.com) ·
[swiftkickweb.com](https://swiftkickweb.com)

### Not affiliated with The New York Times

Quartets is an independent project. It is **not affiliated with, endorsed by, or
connected to The New York Times** or any of its subsidiaries. "Connections" and
"The New York Times" are trademarks of The New York Times Company. The whole
point is that you can't copyright a grid of colored squares — but let's be clear
about it anyway.
