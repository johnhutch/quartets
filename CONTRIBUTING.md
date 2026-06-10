# Contributing to Quartets

Thanks for the interest. Quartets is a small, opinionated Rails app for building
and playing Connections-style puzzles — but issues and PRs are welcome.

## Ground rules

- **TDD.** New behavior gets a failing spec first, then the code to pass it, then
  a refactor. Red → green → refactor. Bug fixes start with a spec that reproduces
  the bug.
- **Match the house style.** Read [`VOICE.md`](VOICE.md) before writing comments,
  docs, or commit messages — confident, terse, no fluff. Commit messages match
  the casual existing log.
- **Decisions are documented.** The big ones live in [`DECISIONS.md`](DECISIONS.md)
  and `docs/`. If your change reverses one, update it in the same PR.

## Getting set up

```bash
# Ruby is pinned in .ruby-version (4.0.4) — use chruby/rbenv to match it.
bundle install
bin/rails db:create db:migrate db:seed
bin/dev          # boots Rails + the dartsass watcher (see Procfile.dev)
```

Then visit http://localhost:3000. In development, the seeds create a superuser
you can sign in as to author puzzles — `admin@example.com` / `password123`
(dev-only fallback; production uses real env-set creds). See `db/seeds.rb`.

## Running the tests

```bash
bundle exec rspec                                  # the whole suite
bundle exec rspec spec/models/emoji_cube_spec.rb   # a single file
```

System specs drive headless Chrome at a phone viewport — iPhone is the primary
device, so "works" means "works on a phone." Keep the suite green before opening
a PR.

## CSS conventions

Sass, organized **SMACSS** — no Tailwind, no utility-class soup. Edit the source
partials (`application.scss` + `_variables` / `_base` / `_modules` / `_state` /
`_brutal`), **never** `app/assets/builds/`. Naming is `l-` layout, `m-` module,
`is-` state. Theme values (colors, spacing, type) live in `_variables.scss` — no
magic numbers in modules. Rebuild with `bin/rails dartsass:build`, or let
`bin/dev` watch.

## Submitting a change

1. Branch off `main`.
2. Write the spec, make it pass, keep the whole suite green.
3. Open a PR that explains the *why*, not just the *what*.

## Licensing of contributions

Quartets is dual-licensed (see the [README](README.md#license)). By contributing
you agree your code is offered under the **MIT License**, and any content you add
(puzzles, copy, docs) under **CC BY 4.0** — matching the rest of the project.
