#!/usr/bin/env bash
# lib-common/review.sh — design_reviews state machine helpers
# Usage:
#   review.sh request <document_id>       # creates design_reviews row + round 1
#   review.sh revise <document_id>        # increments round, stores new body snapshot
#   review.sh fetch-comments <document_id>  # JSON array of open comments
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/db.sh"

_sql_literal() { printf '%s' "$1" | sed "s/'/''/g"; }

cmd_request() {
  local doc_id="${1:-}"
  [ -z "$doc_id" ] && { echo "review.sh request <document_id>" >&2; exit 1; }

  local title body
  title=$(db_one "SELECT title FROM documents WHERE id = $doc_id")
  [ -z "$title" ] && { echo "document $doc_id not found" >&2; exit 1; }
  body=$(psql "$SUPERWISDOM_DB_CONN" -v ON_ERROR_STOP=1 -tA -c "SELECT body_md FROM documents WHERE id = $doc_id")

  local body_e title_e
  title_e=$(_sql_literal "$title")
  body_e=$(_sql_literal "$body")

  # Subaya design_reviews has project_id NOT NULL (FK-like but not enforced); use 1 as platform-self placeholder
  local rid
  rid=$(db_one "INSERT INTO design_reviews (project_id, title, author_type, status, current_round, document_id) \
                VALUES (1, '$title_e', 'agent', 'in_review', 1, $doc_id) RETURNING id")

  db_exec "INSERT INTO review_rounds (review_id, round, document) VALUES ($rid, 1, '$body_e')"
  db_exec "UPDATE documents SET status='in_review', updated_at=now() WHERE id = $doc_id"
  echo "$rid"
}

cmd_revise() {
  local doc_id="${1:-}"
  [ -z "$doc_id" ] && { echo "review.sh revise <document_id>" >&2; exit 1; }

  local rid current body body_e
  rid=$(db_one "SELECT id FROM design_reviews WHERE document_id = $doc_id ORDER BY id DESC LIMIT 1")
  [ -z "$rid" ] && { echo "no review found for document $doc_id" >&2; exit 1; }
  current=$(db_one "SELECT current_round FROM design_reviews WHERE id = $rid")
  body=$(psql "$SUPERWISDOM_DB_CONN" -v ON_ERROR_STOP=1 -tA -c "SELECT body_md FROM documents WHERE id = $doc_id")
  body_e=$(_sql_literal "$body")

  local next=$((current + 1))
  db_exec "INSERT INTO review_rounds (review_id, round, document) VALUES ($rid, $next, '$body_e')"
  db_exec "UPDATE design_reviews SET current_round = $next, status='in_review', updated_at=now() WHERE id = $rid"
  db_exec "UPDATE documents SET status='in_review', updated_at=now() WHERE id = $doc_id"
  echo "$next"
}

cmd_fetch_comments() {
  local doc_id="${1:-}"
  local round="${2:-}"
  [ -z "$doc_id" ] && { echo "review.sh fetch-comments <document_id> [round]" >&2; exit 1; }

  local filter_round=""
  [ -n "$round" ] && filter_round="AND rc.round = $round"

  db_json "SELECT rc.id, rc.section, rc.line_start, rc.line_end, rc.body, rc.status, rc.round, rc.author_type \
           FROM review_comments rc \
           JOIN design_reviews dr ON dr.id = rc.review_id \
           WHERE dr.document_id = $doc_id AND rc.status = 'open' $filter_round \
           ORDER BY rc.round DESC, rc.id ASC"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    request)        cmd_request "$@" ;;
    revise)         cmd_revise "$@" ;;
    fetch-comments) cmd_fetch_comments "$@" ;;
    *) echo "review.sh: unknown subcommand '$sub'" >&2; exit 1 ;;
  esac
}
main "$@"
