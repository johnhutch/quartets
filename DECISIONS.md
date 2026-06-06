# Decisions

ADR-style log of major design + architectural decisions. One entry per decision. **Append at the bottom; don't rewrite history** — supersede an old entry by compressing it to a "superseded by NNNN" stub.

---

## 0001 — Auto-save: publish-only validation + a quiet POST→PATCH endpoint

**Date:** 2026-06-06
**Status:** accepted

**Context.** Auto-save is a hard requirement (born from losing work to the iOS
back button). The authoring form is answers-first with the title at the bottom,
so a half-typed draft routinely has groups but no title yet. `Puzzle#title` was
the one validation still firing on drafts, which blocked saving that state. We
also needed background saves that don't redirect or flash, and a brand-new
puzzle has no id to PATCH against yet.

**Decision.** Make **everything publish-only** — `title` joins the structural
rules in being validated `if: :published?`, so drafts stay lenient. Auto-save
requests carry an `autosave` param; the controller answers them quietly:
`create` returns **201 + the editor URL in `Location`**, `update` returns
**204 No Content**. The Stimulus controller POSTs the first save, reads
`Location`, then rewrites the form to PATCH that record (and `replaceState`s the
URL) so later edits update in place instead of creating duplicates.

**Consequence.** Drafts can be blank/partial and still persist — don't lean on
title presence anywhere but publish. The autosave response contract (201+Location
/ 204, no redirect) is load-bearing for `autosave_controller.js`; changing it
breaks the new→edit handoff. Publish is the only gate that enforces the full 4×4
+ title rules.

---

## Adding new decisions

Append using the template above. Status is one of: `proposed` | `accepted` | `superseded by NNNN` | `deprecated`.
