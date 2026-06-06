#!/usr/bin/env bash
# UserPromptSubmit hook — if a long gap has elapsed since the previous prompt,
# nudge the user to /wrap (long idle often means a session is winding down).
# No native idle timer exists, so this fires on the *next* prompt after the gap.
set -euo pipefail

STAMP="${TMPDIR:-/tmp}/claude_wrap_last_prompt"
THRESHOLD=1800   # seconds (30 min); tune to taste

cat >/dev/null 2>&1 || true   # drain stdin (hook receives JSON we don't need)

now=$(date +%s)
msg=""
if [ -f "$STAMP" ]; then
  last=$(cat "$STAMP" 2>/dev/null || echo "$now")
  gap=$(( now - last ))
  if [ "$gap" -ge "$THRESHOLD" ]; then
    mins=$(( gap / 60 ))
    msg="⏳ ~${mins} min since your last message. If you're wrapping up, run /wrap to sync PROGRESS / TODOS / DECISIONS / CONTEXT before context is lost."
  fi
fi
echo "$now" > "$STAMP" 2>/dev/null || true

[ -n "$msg" ] && jq -n --arg m "$msg" '{ systemMessage: $m }'
exit 0
