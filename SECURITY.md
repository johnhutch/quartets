# Security Policy

## Reporting a vulnerability

Please **don't open a public issue** for security problems. Report them
privately instead:

- Use GitHub's [private vulnerability reporting](https://github.com/johnhutch/quartets/security/advisories/new), or
- Email **johnhutch@swiftkickweb.com** with the details and, ideally, a way to
  reproduce.

Quartets is a small, self-hosted hobby project, so please be patient on response
time — but real issues are taken seriously and I'll work a fix.

## Scope

The app is deliberately minimal about data: no player accounts, anonymous
cookie-based identity for stats, and no third-party trackers (see the
[privacy policy](/privacy)). The most sensitive surface is the **superuser auth**
(Devise) used for puzzle authoring. Especially worth reporting:

- authentication bypass or privilege escalation,
- access to another user's puzzles or drafts,
- anything that could expose `RAILS_MASTER_KEY`, the database, or other secrets.

## Supported versions

This is a rolling single-deployment project — `main` is the supported version.
There are no release branches to back-port fixes to.
