#!/usr/bin/env bash
# lib-common/session.sh — tmp state directory helpers
# Usage:
#   source lib-common/session.sh
#   SESSION_DIR=$(session_init brainstorm-db)
#   session_write "$SESSION_DIR" draft.md "$DRAFT_CONTENT"
#   session_read "$SESSION_DIR" draft.md
set -euo pipefail

session_init() {
  local skill="$1"
  local uuid
  uuid=$(date +%s)-$$
  local dir="${SUPERWISDOM_SESSION_ROOT:-/tmp}/$skill-$uuid"
  mkdir -p "$dir"
  echo "$dir"
}

session_write() {
  local dir="$1"; local name="$2"; local content="$3"
  printf '%s' "$content" > "$dir/$name"
}

session_read() {
  local dir="$1"; local name="$2"
  cat "$dir/$name"
}

session_list_active() {
  local skill="$1"
  find "${SUPERWISDOM_SESSION_ROOT:-/tmp}" -maxdepth 1 -name "$skill-*" -type d 2>/dev/null | sort
}
