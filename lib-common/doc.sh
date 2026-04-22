#!/usr/bin/env bash
# lib-common/doc.sh — CRUD for documents/initiatives/work_items
# Usage:
#   doc.sh create --type=design --initiative=<slug> --title="..." --body=@/path/to/body.md
#   doc.sh update <id> --body=@/path/to/body.md
#   doc.sh upsert-initiative --slug=<slug> --name="..." --description="..." [--priority=high]
#   doc.sh upsert-work-item --type=epic --initiative=<slug> --title="..." [--parent=<id>]
#   doc.sh link-spec --work-item=<id> --spec-type=requirement --spec-id=<id>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/db.sh"

_require_jq() { command -v jq >/dev/null || { echo "doc.sh: jq is required" >&2; exit 1; }; }
_require_jq

_arg_val() {
  # parse --key=value from remaining args; returns value for key $1
  local key="$1"; shift
  for a in "$@"; do
    case "$a" in
      --$key=*) echo "${a#--$key=}"; return 0 ;;
    esac
  done
}

_read_body() {
  # accepts @path or literal
  local v="$1"
  if [[ "$v" == @* ]]; then
    cat "${v#@}"
  else
    printf '%s' "$v"
  fi
}

_sql_literal() {
  # escape single quotes for a SQL string literal
  printf '%s' "$1" | sed "s/'/''/g"
}

cmd_create() {
  local type title initiative_slug wi_id body
  type=$(_arg_val type "$@")
  title=$(_arg_val title "$@")
  initiative_slug=$(_arg_val initiative "$@" || true)
  wi_id=$(_arg_val work-item "$@" || true)
  body=$(_read_body "$(_arg_val body "$@")")

  [ -z "$type" ] && { echo "doc.sh create: --type required" >&2; exit 1; }
  [ -z "$title" ] && { echo "doc.sh create: --title required" >&2; exit 1; }

  local init_sql="NULL" wi_sql="NULL"
  if [ -n "$initiative_slug" ]; then
    local iid
    iid=$(db_one "SELECT id FROM initiatives WHERE slug = '$(_sql_literal "$initiative_slug")'")
    [ -z "$iid" ] && { echo "doc.sh: initiative slug '$initiative_slug' not found" >&2; exit 1; }
    init_sql="$iid"
  fi
  if [ -n "$wi_id" ]; then
    wi_sql="$wi_id"
  fi

  local title_e body_e
  title_e=$(_sql_literal "$title")
  body_e=$(_sql_literal "$body")

  db_one "INSERT INTO documents (type, title, body_md, initiative_id, work_item_id, author_type) \
          VALUES ('$type', '$title_e', '$body_e', $init_sql, $wi_sql, 'agent') \
          RETURNING id"
}

cmd_update() {
  local id="$1"; shift
  [ -z "$id" ] && { echo "doc.sh update: id required as first arg" >&2; exit 1; }

  local sets=()
  local body title status
  body=$(_arg_val body "$@" || true)
  title=$(_arg_val title "$@" || true)
  status=$(_arg_val status "$@" || true)

  if [ -n "${body:-}" ]; then
    local b_e; b_e=$(_sql_literal "$(_read_body "$body")")
    sets+=("body_md = '$b_e'")
  fi
  if [ -n "${title:-}" ]; then
    sets+=("title = '$(_sql_literal "$title")'")
  fi
  if [ -n "${status:-}" ]; then
    sets+=("status = '$status'")
  fi

  [ ${#sets[@]} -eq 0 ] && { echo "doc.sh update: no fields supplied" >&2; exit 1; }

  local joined; joined=$(IFS=, ; echo "${sets[*]}")
  db_exec "UPDATE documents SET $joined, updated_at = now() WHERE id = $id"
  echo "$id"
}

cmd_upsert_initiative() {
  local slug name description priority notes status
  slug=$(_arg_val slug "$@")
  name=$(_arg_val name "$@" || true)
  description=$(_arg_val description "$@" || true)
  priority=$(_arg_val priority "$@" || true)
  notes=$(_arg_val notes "$@" || true)
  status=$(_arg_val status "$@" || true)

  [ -z "$slug" ] && { echo "upsert-initiative: --slug required" >&2; exit 1; }

  local slug_e; slug_e=$(_sql_literal "$slug")
  local sets=()
  [ -n "$name" ]        && sets+=("name = EXCLUDED.name")
  [ -n "$description" ] && sets+=("description = EXCLUDED.description")
  [ -n "$priority" ]    && sets+=("priority = EXCLUDED.priority")
  [ -n "$notes" ]       && sets+=("notes = EXCLUDED.notes")
  [ -n "$status" ]      && sets+=("status = EXCLUDED.status")
  sets+=("updated_at = now()")

  local joined; joined=$(IFS=, ; echo "${sets[*]}")

  local name_e desc_e prio notes_e stat
  name_e=$(_sql_literal "${name:-$slug}")
  desc_e=$(_sql_literal "${description:-}")
  prio="${priority:-medium}"
  notes_e=$(_sql_literal "${notes:-}")
  stat="${status:-planned}"

  db_one "INSERT INTO initiatives (slug, name, description, priority, notes, status, display_order) \
          VALUES ('$slug_e', '$name_e', NULLIF('$desc_e',''), '$prio', NULLIF('$notes_e',''), '$stat', \
                  COALESCE((SELECT MAX(display_order)+1 FROM initiatives), 1)) \
          ON CONFLICT (slug) DO UPDATE SET $joined \
          RETURNING id"
}

cmd_upsert_work_item() {
  local type title initiative_slug parent_id description notes status priority
  type=$(_arg_val type "$@")
  title=$(_arg_val title "$@")
  initiative_slug=$(_arg_val initiative "$@" || true)
  parent_id=$(_arg_val parent "$@" || true)
  description=$(_arg_val description "$@" || true)
  notes=$(_arg_val notes "$@" || true)
  status=$(_arg_val status "$@" || true)
  priority=$(_arg_val priority "$@" || true)

  [ -z "$type" ] && { echo "upsert-work-item: --type required (epic|story|task)" >&2; exit 1; }
  [ -z "$title" ] && { echo "upsert-work-item: --title required" >&2; exit 1; }

  local init_sql="NULL" parent_sql="NULL"
  if [ "$type" = "epic" ]; then
    [ -z "$initiative_slug" ] && { echo "upsert-work-item: epic requires --initiative=<slug>" >&2; exit 1; }
    local iid; iid=$(db_one "SELECT id FROM initiatives WHERE slug = '$(_sql_literal "$initiative_slug")'")
    [ -z "$iid" ] && { echo "initiative slug '$initiative_slug' not found" >&2; exit 1; }
    init_sql="$iid"
  else
    [ -z "$parent_id" ] && { echo "upsert-work-item: $type requires --parent=<work_item_id>" >&2; exit 1; }
    parent_sql="$parent_id"
  fi

  local title_e desc_e notes_e stat prio
  title_e=$(_sql_literal "$title")
  desc_e=$(_sql_literal "${description:-}")
  notes_e=$(_sql_literal "${notes:-}")
  stat="${status:-planned}"
  prio="${priority:-medium}"

  # Match on (type, initiative_id OR parent_id, title) for upsert semantics
  local existing
  if [ "$type" = "epic" ]; then
    existing=$(db_one "SELECT id FROM work_items WHERE type='epic' AND initiative_id=$init_sql AND title='$title_e'")
  else
    existing=$(db_one "SELECT id FROM work_items WHERE type='$type' AND parent_id=$parent_sql AND title='$title_e'")
  fi

  if [ -n "$existing" ]; then
    db_exec "UPDATE work_items SET description=NULLIF('$desc_e',''), notes=NULLIF('$notes_e',''), \
             status='$stat', priority='$prio', updated_at=now() WHERE id=$existing"
    echo "$existing"
  else
    db_one "INSERT INTO work_items (type, initiative_id, parent_id, title, description, notes, status, priority) \
            VALUES ('$type', $init_sql, $parent_sql, '$title_e', NULLIF('$desc_e',''), NULLIF('$notes_e',''), '$stat', '$prio') \
            RETURNING id"
  fi
}

cmd_link_spec() {
  local wi_id spec_type spec_id
  wi_id=$(_arg_val work-item "$@")
  spec_type=$(_arg_val spec-type "$@")
  spec_id=$(_arg_val spec-id "$@")
  if [ -z "$wi_id" ] || [ -z "$spec_type" ] || [ -z "$spec_id" ]; then
    echo "link-spec requires --work-item, --spec-type, --spec-id" >&2; exit 1
  fi

  db_exec "INSERT INTO work_item_specs (work_item_id, spec_type, spec_id) \
           VALUES ($wi_id, '$spec_type', $spec_id) \
           ON CONFLICT (work_item_id, spec_type, spec_id) DO NOTHING"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    create)             cmd_create "$@" ;;
    update)             cmd_update "$@" ;;
    upsert-initiative)  cmd_upsert_initiative "$@" ;;
    upsert-work-item)   cmd_upsert_work_item "$@" ;;
    link-spec)          cmd_link_spec "$@" ;;
    *) echo "doc.sh: unknown subcommand '$sub'" >&2; exit 1 ;;
  esac
}
main "$@"
