# Accessibility

Quartets holds itself to **WCAG 2.1 Level AA** (ADR-0013). This file is the
running record: what we audit, what we found, what we fixed, and the handful of
things we consciously left alone. Update it whenever you touch a surface that
moves any of these criteria.

## How we audit

- **Automated:** Lighthouse (axe-core under the hood), run headless against the
  local dev server across the eight core surfaces — home, `/play`, the game
  (`/p/:share_token`), the dashboard, the authoring form, styleguide, privacy,
  and sign-in. Re-run after a11y-affecting changes.
  - One-off, no project footprint: `npx lighthouse@12 <url> --only-categories=accessibility`
    using a Node ≥20 (the repo's nodenv pins 18.12 for the app, too old for
    Lighthouse — point `PATH` at a brew Node, e.g. `/opt/homebrew/opt/node/bin`).
- **Manual:** axe automates ~30–40% of WCAG. The rest is a by-hand walkthrough
  of every template — landmarks, skip link, heading order, focus order + visible
  focus, form labels & error identification, link/button names, reduced-motion.
- **Specs:** semantic/markup criteria are pinned by
  `spec/system/accessibility_spec.rb` (skip link, named nav landmarks, status
  flash roles, named answer inputs). Contrast and reduced-motion are **not**
  RSpec'd — that means reimplementing colour math against compiled CSS, brittle
  and low-value; they're verified via Lighthouse instead.

## Baseline (audit 2026-06-16)

Lighthouse mobile, dev server. Uniform **95 accessibility** site-wide; the only
automated failures were `color-contrast` (every page) and `meta-description`
(SEO, not ADA). The game already had a strong manual baseline: real `<button>`
tiles (keyboard-operable), `aria-pressed` on selection, `aria-live` status +
mistakes, and solved groups that render the **category name as text** (so colour
isn't the only signal — 1.4.1 holds).

## Findings & status

| WCAG | Criterion | Finding | Status | Where |
|------|-----------|---------|--------|-------|
| 1.4.3 | Contrast (Minimum), AA | `.m-hero__nowplaying`, `.m-hero__pitch`, `.m-game__mistakes` used the light-theme `$color-muted` (#5a5a5a → 2.83:1) on the near-black page | **Fixed** — moved to `$brutal-muted` (~7:1) | `_brutal.scss` muted block |
| 1.4.3 | Contrast (Minimum), AA | `.l-footer__disclaimer` had `opacity: 0.7`, dragging `$brutal-muted` to 4.31:1 | **Fixed** — dropped the opacity | `_base.scss` |
| 2.4.1 | Bypass Blocks, A | No skip link; page body had no `<main>` landmark | **Fixed** — skip link + `<main id="main">` | `layouts/application.html.erb`, `_base.scss` |
| 2.4.7 | Focus Visible, AA | Only one `:focus` rule site-wide; custom buttons/links/tiles relied on UA default | **Fixed** — global `:focus-visible` ring | `_base.scss` |
| 3.3.2 / 4.1.2 | Labels / Name, AA | The 16 answer inputs had a placeholder only, no accessible name | **Fixed** — `aria-label="<Colour> answer N"` | `puzzles/_form.html.erb` |
| 4.1.3 | Status Messages, AA | Flash messages were bare `<div>`s with no role | **Fixed** — `role=alert/status` + `aria-live` by severity | `layouts/application.html.erb` |
| 2.3.3 / 2.2.2 | Animation / Motion | Tile tilt + lift had no `prefers-reduced-motion` guard | **Fixed** — reduced-motion flattens transitions/animation | `_base.scss` |
| 1.3.1 / 4.1.2 | Info & Relationships / Name | Two `<nav>` landmarks (desktop + mobile) shared no distinct names | **Fixed** — `aria-label="Primary"` / `"Menu"` | `layouts/application.html.erb` |

## Conscious exemptions

- **`/styleguide` swatches.** The contrast "violations" there are the demo
  swatches themselves — colour samples with labels painted on them to show the
  palette. Holding them to AA would defeat the purpose. The styleguide is an
  unlinked internal tool, not a public surface, so it's exempt.
- **Emoji cube (🟨🟩🟦🟪).** A share/brag string, not functional UI; a screen
  reader reads it as colour names, which is acceptable for decorative output.

## Not ADA, tracked separately

- **`meta-description`** — was missing site-wide (SEO, not accessibility).
  **Resolved:** a site-default description plus a per-puzzle one (the author's
  blurb, or a generated spoiler-free fallback) now feed `<meta name="description">`
  and the OG/Twitter tags. See `app/helpers/application_helper.rb`
  (`puzzle_meta_description`) and `spec/requests/meta_tags_spec.rb`.
