#!/usr/bin/env bash
# lib-common/db.sh — thin psql wrapper
# Usage:
#   source lib-common/db.sh
#   db_exec "SELECT 1;"                       # raw exec, prints rows
#   db_one "SELECT id FROM initiatives LIMIT 1;"   # first column of first row
#   db_json "SELECT * FROM initiatives;"      # returns a JSON array
set -euo pipefail

: "${SUPERWISDOM_DB_CONN:=$(neon cs 2>/dev/null || true)}"
if [ -z "${SUPERWISDOM_DB_CONN:-}" ]; then
  echo "db.sh: cannot find a connection string. Set SUPERWISDOM_DB_CONN or run 'neon auth'." >&2
  exit 1
fi

db_exec() {
  psql "$SUPERWISDOM_DB_CONN" -v ON_ERROR_STOP=1 -q -c "$1"
}

db_one() {
  psql "$SUPERWISDOM_DB_CONN" -v ON_ERROR_STOP=1 -tA -c "$1" | head -n1
}

db_json() {
  psql "$SUPERWISDOM_DB_CONN" -v ON_ERROR_STOP=1 -tA -c \
    "SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM ($1) t;"
}
