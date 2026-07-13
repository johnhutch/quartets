# Launch plan — Quartets

The plan for taking Quartets public (a possible r/nytconnections push). Written
2026-07-13. SEO/AEO groundwork + first-party analytics are **built**; the rest is
setup + content + promotion, mostly on the human side.

## Guiding principle: keep the privacy promise

The privacy page says "no analytics, no pixels, no third parties" and the footer
brags we'll "never creep on you." We keep that **literally true** — measurement is
100% first-party and server-side, zero client script, no cookies, no third party.
That's a differentiator, not a constraint. (See ADR-0021.)

## What's built (2026-07-13)

- **Sitemap** — dynamic `/sitemap.xml` (published puzzles + static pages +
  profiles), referenced from `robots.txt`.
- **Structured data** — JSON-LD: WebSite sitewide, Game per puzzle, FAQPage on
  how-to-play, HowTo on the making-a-quartet guide. Canonical tags sitewide.
- **Analytics** — first-party traffic (`Visit` + `TrafficStats`, with an AI-referral
  segment) and product funnels (`Event` + `FunnelStats`), in the superuser `/admin`
  analytics tab. Errors via Sentry (item 5).
- **Onboarding content** — how-to-play + "making a good quartet" (item 6), both
  strong SEO/AEO targets ("how to play connections", "how to make a connections
  puzzle").
- **AI-crawler `robots.txt`** — allows search/citation crawlers, blocks training.

## Pre-launch punch list (manual — your accounts)

- [ ] **Google Search Console** — verify `playquartets.com` (Cloudflare DNS TXT),
      submit `/sitemap.xml`.
- [ ] **Bing Webmaster Tools** — verify + submit sitemap. *(ChatGPT web search runs
      on Bing's index — Bing coverage ≈ ChatGPT citability.)*
- [ ] **Resend** — finish domain verification (forgot-password + report emails).
- [ ] **Cloudflare Email Routing** — `contact@playquartets.com` forward.
- [ ] **Sentry** — confirm live after deploy; set one alert rule.
- [ ] **Cloudflare edge analytics** — enable (free, zero-footprint supplement to
      the first-party numbers).
- [ ] **OG validation** — run home + a puzzle through the FB/LinkedIn/X debuggers +
      iMessage; confirm `share.png` unfurls.
- [ ] **PWA** — confirm install on a real iPhone.
- [ ] **Seed quality puzzles** — the catalog needs a critical mass of *good* ones
      before promotion (also the gating dep for Puzzle of the Day). Recruit a few
      good creators / make a batch.

## AEO/GEO (getting cited by AI answer engines)

- Front-load answers (the content pages already lead with a direct answer).
- FAQ/HowTo schema is in place — the formats AI engines cite most.
- Submit the sitemap to **Bing** (above).
- Freshness + authorship (bylines/handles + dates) give the E-E-A-T signals.
- **Measure monthly:** run "connections puzzle maker", "create your own connections
  game", "how to play connections" through ChatGPT / Perplexity / Google AI; note
  if Quartets appears. First Perplexity citations typically land 4–12 weeks out.

## Marketing / promotion

**Don't promote until the catalog has a critical mass of good puzzles.** A
redditor who hits three mediocre ones bounces. The moderation tools + the
making-a-good-quartet guide protect quality, but they need content to work on.

**Reddit (the main channel) — the 2026 norms:**
- **Participate first** — 2–4 weeks genuinely active in r/nytconnections (+
  r/SideProject, r/webgames) before promoting. A cold link-drop from a new account
  gets removed or shadowbanned.
- **Be transparent** — "I built this" earns respect; hidden affiliation is punished.
- **Lead with value** — the best promotion answers someone's actual need ("is there
  a way to make my own Connections?") with the tool as one honest option.
- **Read the subreddit's own promo rules** in the sidebar before posting.
- **The hook:** not "another Connections clone" — pitch what swellgarfo lacks: a
  place to *discover and play* community puzzles, with ratings + creator profiles.

**The friendly-swellgarfo angle:** they're a creator tool; we're a creator tool
**plus** community + discovery + quality curation. Frame as complementary, never an
attack — the Connections crowd sides with the gracious one.

**Other channels:** the emoji-cube share is the organic viral loop (make every
shared cube funnel back to a strong landing — eventually Puzzle of the Day). A Show
HN / r/SideProject post for the indie-dev crowd. Bluesky for the puzzle-nerd niche.

## The big deferred lever

**Puzzle of the Day** (TODOS "Daily auto-featured puzzle") is the single biggest
retention + first-impression play — it recreates the NYT daily ritual, gives a
canonical entry point + shared cube, and unlocks streaks. It's **gated on catalog
size** (algorithmic selection needs enough good puzzles). Build it once the seed +
early creators have produced a critical mass.
