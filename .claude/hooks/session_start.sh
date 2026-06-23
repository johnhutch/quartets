#!/usr/bin/env bash
# SessionStart hook — inject current project state into context and nudge /wrap.
# Output is JSON: additionalContext is fed to the model; systemMessage shows the user.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || true

context="$(
  echo "=== Recent commits ==="
  git log --oneline -5 2>/dev/null || echo "(not a git repo)"
  echo ""
  echo "=== PROGRESS.md (current state) ==="
  # Inject Current focus + Known not-done, but skip the ever-growing Shipped log
  # block — cat-ing the whole file blew past the hook's inline cap, so only a
  # preview reached the model. Read the shipped log on demand instead.
  awk '/^## Shipped log/{s=1} /^## Known not-done/{s=0} !s' PROGRESS.md 2>/dev/null || echo "(no PROGRESS.md)"
)"

# Seed the idle-reminder stamp so the first gap is measured from session start.
echo "$(date +%s)" > "${TMPDIR:-/tmp}/claude_wrap_last_prompt" 2>/dev/null || true

jq -n --arg ctx "$context" '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx },
  systemMessage: "📋 Loaded PROGRESS.md + recent commits. Before you stop, run /wrap to sync PROGRESS / TODOS / DECISIONS / CONTEXT."
}'
