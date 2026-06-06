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
  cat PROGRESS.md 2>/dev/null || echo "(no PROGRESS.md)"
)"

# Seed the idle-reminder stamp so the first gap is measured from session start.
echo "$(date +%s)" > "${TMPDIR:-/tmp}/claude_wrap_last_prompt" 2>/dev/null || true

jq -n --arg ctx "$context" '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx },
  systemMessage: "📋 Loaded PROGRESS.md + recent commits. Before you stop, run /wrap to sync PROGRESS / TODOS / DECISIONS / CONTEXT."
}'
