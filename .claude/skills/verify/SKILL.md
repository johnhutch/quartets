---
name: verify
description: How to drive the running Quartets app for end-to-end verification — server handle, seeded data, headless screenshots, cookie-jar probes.
---

# Verifying Quartets changes at runtime

## Handle

The user usually has `bin/dev` running already — check before booting your own:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/   # 200 → use it
```

Dev auto-reloads Ruby/ERB. CSS does NOT auto-build unless the `bin/dev` watcher
is running — after editing Sass, run `bin/rails dartsass:build`. If nothing is
on 3000, `bin/rails server -p 3001 -d` (check `tmp/pids/server.pid` conflicts).

Shell gotcha: `source ~/.zshrc` doesn't exist for bash here — chain with `;`,
never `&&`, or the whole command silently dies.

## Seed + clean

Seed recognizable rows via `bin/rails runner` with titles prefixed `VERIFY `
(publish needs 4 complete groups with distinct colors — build groups in the
script, set `status: :published`, `save!`). Clean up after:

```ruby
Puzzle.where("title LIKE ?", "VERIFY %").destroy_all
```

## Drive

Selenium is already a dev dependency; phone-width headless Chrome matches the
house habit of phone screenshots:

```ruby
opts = Selenium::WebDriver::Chrome::Options.new
opts.add_argument("--headless=new")
opts.add_argument("--window-size=390,900")
driver = Selenium::WebDriver.for(:chrome, options: opts)
```

The home jump-in strip is a `RANDOM()` draw — loop reloads until the row you
need appears instead of assuming one load shows it.

## Cookie-identity probes (creator_token / player_token)

They're signed cookies — you can't forge them, but you can mint one:

1. `curl -c jar /puzzles/new` → grep the `csrf-token` meta.
2. `curl -b jar -c jar -X POST /puzzles -H "X-CSRF-Token: $T" --data-urlencode "puzzle[title]=CURL SCRATCH"` → the jar now holds a real creator_token.
3. Read the token back: `bin/rails runner 'puts Puzzle.find_by!(title: "CURL SCRATCH").creator_token'` and attach it to whatever fixture puzzle the probe needs (`update_columns`).
4. Probe with `curl -b jar`, contrast against no-jar requests.
