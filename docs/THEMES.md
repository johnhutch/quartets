# Plan: theming — toggleable skins

**Status:** Proposed, not started. **Do this on its own branch, after the
`homepage-rework` branch is merged to `main`.** It touches `_brutal.scss` and the
layout; don't start it on top of uncommitted homepage work.

The app ships one look today (brutalist). This plan adds a **skin system** and two
opt-in alternate themes a logged-in user can toggle:

- **`brutal`** — the current brutalist theme. Stays the default for everyone.
- **`8bit`** — arcade / pixel. Press Start 2P + VT323, CRT scanlines, hearts-as-
  lives, "PRESS START" everything.
- **`broadsheet`** — a parody newspaper, **"The No Times"** (the homepage's
  `NoTimes` nameplate gag, fully committed). Serif/blackletter, ruled columns,
  drop caps, classifieds, an editorial column. Leans into needling the NYT — see
  the parody note below.

Standalone visual comps that motivated this live outside the repo (built during
the homepage session): a full 8-bit set (homepage + play / result / create /
archive / login, desktop + mobile) and a broadsheet **homepage**. The broadsheet
app screens aren't designed yet — see the inventory.

---

## Why it's feasible (the groundwork already exists)

- **The theme hook is built.** The layout sets `body class="theme-brutal"` with a
  `content_for(:body_class)` override, and every rule in `_brutal.scss` is scoped
  `.theme-brutal .m-…`. That namespacing *is* the skin system. Each extra theme is
  `.theme-8bit` / `.theme-broadsheet` over the same markup.
- **Markup is reused, not forked.** Views emit semantic BEM classes (`.m-board`,
  `.m-card`, `.m-group`, `.m-cube`, trophy SVGs). A skin restyles *those* — no
  `.erb` changes. (The throwaway comps used ad-hoc names like `.tile`/`.solved`;
  the real themes must target the existing classes so one DOM serves all three.)
- **Persistence is cheap for logged-in users.** Devise users already exist; add a
  `theme` column and read it in the layout. Server-rendered into `<body>`, so
  **no flash-of-unstyled-content**.

## The architecture decision that controls long-term cost (do this first)

Every extra theme means styling each component again — a permanent tax. How the
CSS is authored decides how big it is, and with **two** add-on themes the payoff
is double.

- **Today:** `_brutal.scss` bakes Sass vars (`$color-yellow`, `$brutal-border`,
  `$brutal-shadow`) in at build time. Writing 8bit + broadsheet the same way =
  two parallel duplicated blocks per component — ~3× the CSS, forever.
- **Recommended:** refactor the skinnable properties to **CSS custom properties**
  on the body theme class — `--ink`, `--paper`, `--surface`, `--accent`,
  `--font-display`, `--font-body`, `--border-w`, `--shadow`, `--radius`, `--rule`.
  Components are authored once against the variables; each theme is mostly a block
  of overrides plus its genuinely-extra bits (pixel fonts + scanlines for 8bit;
  column rules + drop caps + blackletter for broadsheet).

**So: tokenize the brutalist theme first, then add each skin as a thin override
layer.** This is what makes a *second* add-on theme (broadsheet) cheap rather than
another full reskin, and any future theme nearly free.

## Component inventory to reskin

Each theme must cover the whole surface or it looks half-finished on the first
unstyled screen:

- Game: board, tiles (+ selected/correct/wrong), solved bars, controls, `aria-live`
  status + mistakes, win **and loss** end states, emoji cube, trophy awards.
- Authoring form: four colour group panels, answer inputs, validation/error states,
  autosave indicator, preview, publish.
- Archive (`/play`): cards, search, filter tags, pagination, empty state.
- Dashboard ("Your stuff"): puzzle list, per-puzzle stats, trophy case, the planned
  aggregate stats table.
- Auth (Devise): sign-in, sign-up, edit account, forgot/reset password.
- Chrome: topbar + mobile hamburger, footer, flash messages, skip link, focus
  rings, error pages.

**Design gap:** 8-bit has comps for all of these; broadsheet only has a homepage.
Before broadsheet ships it needs the same screen pass — the newspaper metaphors
are there for the taking (the game as a "puzzle of the day" feature with a Fig.,
the archive as a classifieds index, create as "Submit a Puzzle to the Editor",
login as "Subscriber Services").

## Per-theme notes

### 8bit
- Fonts: **Press Start 2P** (display only) + **VT323** (body — legibility).
- Extras: CRT scanline overlay, vignette, stepped/hard shadows, blink, hearts.
- Highest a11y lift (see below).

### broadsheet — "The No Times"
- Fonts: **Playfair Display** (headlines), **PT Serif** (body), **Oswald**
  (kickers/labels), a blackletter for the masthead. **Don't** clone the NYT's
  actual masthead typeface/logo — use a generic blackletter (e.g.
  UnifrakturMaguntia). Parody protects the *concept*, not a trademark lift.
- Extras: hairline + double rules, multi-column body, drop caps, pull quotes,
  classified-ad boxes, an editorial column for the ethics manifesto.
- Lowest a11y lift: black ink on cream is high-contrast, no motion, no CRT.

**Parody note (keep it clean):** the NYT-needling is the point, but stay on the
safe side of parody — it must read as obvious satire, never imply affiliation or
endorsement, and keep the **"Not affiliated with The New York Times"** disclaimer
prominent (it doubles as a punchline). Riffs that land without crossing a line:
the **"No Times"** masthead, the motto **"All the Puzzles That's Fit to Solve"**
(vs. "All the News That's Fit to Print"), **"Price: Free Forever"** (vs. the
paywall), bylines **"Reporting from the Open Web,"** a **"Vol. I, No. 1 / Late
Edition"** folio, a deadpan **corrections** box. Avoid lifting NYT's real
wordmark, section logos, or actual article text.

## Persistence + toggle

- Migration: `add_column :users, :theme, :string, default: "brutal", null: false`.
  Validate inclusion in `%w[brutal 8bit broadsheet]` (an enum is fine too).
- Layout: body class from `current_user&.theme || "brutal"`. Logged-out users
  always get the default — **logged-in-only** scope keeps it simple (no
  anonymous-cookie juggling, no claim-on-signup interaction).
- A theme picker in account settings (three options, live preview if cheap).
- Optional later: anonymous via a `theme` cookie, mirroring `player_token`. Out of
  scope for v1.

## Fonts

Self-host every face as `woff2`, same pattern as Space Grotesk (preload in
`<head>`), bound through the theme `--font-*` props so they only load-bind when a
skin is active: 8bit (Press Start 2P, VT323), broadsheet (Playfair Display, PT
Serif, Oswald, a blackletter). Watch total weight — lazy/conditional loading per
active theme if it gets heavy.

## Accessibility & ADA

We hold the whole app to **WCAG 2.1 AA (ADR-0013, `docs/ACCESSIBILITY.md`)**. A
skin doesn't get a pass. *(Not legal advice — defensible engineering posture.)*

**A warning label does not launder an inaccessible state.** Accessibility isn't
opt-in: a theme a user can select that fails AA is a real failure whenever active,
and a "low accessibility" checkbox doesn't transfer responsibility — *labelling*
it that way is a written admission you knowingly shipped a failing state, arguably
worse. The engineering is the safety mechanism, not the warning.

The path that carries weight:

1. **The default (`brutal`) stays AA.** Everyone who never opens settings, and
   every logged-out visitor, gets it. Already holds.
2. **Engineer each skin to AA too.**
   - **broadsheet** is the easy one: black-on-cream is high-contrast, no motion.
     Watch only minor things — justified columns (readability; 1.4.8 is AAA but
     don't overdo it), responsive `column-count`, the decorative blackletter
     masthead needs an accessible name, small-caps kickers stay ≥ AA contrast.
   - **8bit** is the lift: contrast-check the neon palette (4.5:1 text / 3:1
     large + non-text), keep Press Start display-only / VT323 body, blink ≤ 1Hz
     (the **>3×/sec flashing rule is a hard fail and a seizure-safety issue**),
     focus ring visible on dark.
3. **Un-fixable cosmetic effects become defeatable, not mandatory.** 8-bit's
   scanlines/CRT auto-disable under `prefers-reduced-motion`, `prefers-contrast:
   more`, and `forced-colors: active`; content underneath stays compliant.
4. **Honest copy + one-click revert.** Frame toggles around the *aesthetic*
   ("Retro mode — heavy visual effects; respects your reduced-motion setting"),
   not "low accessibility." Respecting OS accessibility prefs beats any warning.

Any effect that genuinely can't reach AA and we still want → a logged conscious
exemption in `docs/ACCESSIBILITY.md` with reasoning (like the styleguide swatches
and emoji cube already are), **not** a blanket disclaimer.

## Testing

- `spec/system/accessibility_spec.rb` is mostly theme-agnostic (text/role/class);
  run the suite under the default, plus a focused pass per theme (load a user with
  `theme: "8bit"` / `"broadsheet"`, re-check landmarks/labels/focus).
- Lighthouse the eight core surfaces in **all three** themes (audit list in
  `docs/ACCESSIBILITY.md`). Contrast verified here, not in RSpec.
- Screenshot baselines ~3×. The comps + `fullshot.rb` harness from the homepage
  session are a starting point.

## Rough sequence & effort

1. **Custom-property refactor of the brutalist theme (M).** No visual change; pure
   groundwork. Ship + verify nothing moved first.
2. **`users.theme` + settings picker + layout wiring (S).**
3. **Self-host fonts (S).**
4. **8-bit override layer, component by component (L).** Comps exist for every
   screen — execution, not design.
5. **broadsheet override layer (M–L).** The token system + a simpler effect set
   (type + rules, no CRT) make it lighter than 8-bit — *but* it needs the app
   screens designed first (only the homepage comp exists).
6. **A11y pass across all three: contrast/motion/forced-colors (M).**
7. **Specs + tri-theme screenshots + update `docs/ACCESSIBILITY.md` (S–M).**

Effort is dominated by breadth (4–5) and a11y QA (6), not difficulty. Low
architectural risk — the theming seam already exists.

## Open questions

- Three skins is a real maintenance surface. Is the token system enough to keep it
  sane, or do we cap at these three?
- Settings-only picker, or a header switcher?
- broadsheet app screens: design now, or ship broadsheet homepage-only first and
  fall back to `brutal` for app surfaces until designed?
- Extend to anonymous users (cookie) in v1, or logged-in-only first?
