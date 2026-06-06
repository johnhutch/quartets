# Project Todos

Planned work that has been scoped but not yet started. Read this at session start and surface relevant items when related work comes up.

---

- **Extend the author→publish system spec** to assert landing on the public
  share URL, once the Phase 3 play page (`/p/:share_token`) exists. Today it
  stops at the dashboard. (`spec/system/puzzle_authoring_spec.rb`)
- **Tune the auto-save debounce** — currently 1000ms
  (`data-autosave-debounce-value` on the form). Feel it on a real phone and
  adjust.
