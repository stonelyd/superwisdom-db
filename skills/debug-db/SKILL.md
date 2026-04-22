---
name: debug-db
description: Investigates a failing work_item (test_status='failing'), finds root cause, fixes code, and updates the work_item's notes + test_status. Appends root-cause notes; never overwrites.
---

# Debug (DB-backed)

Adapts superwisdom `debug`. Investigates a failing work_item (test_status='failing'), finds root cause, fixes code, and updates the work_item.

## Flow

1. Target: user supplies `<work_item_id>` or the skill queries `work_items WHERE test_status='failing' ORDER BY updated_at DESC LIMIT 1`.
2. Load context:
   - `SELECT id, title, description, notes, test_location, test_status FROM work_items WHERE id=<id>`
   - Read the test file at `test_location`.
   - Read linked spec entities via `work_item_specs` join.
3. Run the test, observe failure.
4. Investigate (four-phase per superwisdom debug: investigate → trace → fix → harden).
5. Implement fix. Re-run test.
6. On green:
   ```bash
   psql "$(neon cs)" -c "UPDATE work_items SET test_status='passing', \
     notes = COALESCE(notes,'') || E'\n\nDebug: <root cause summary>', \
     updated_at=now() WHERE id=<id>;"
   ```
7. Commit.

## Rules

- Always append root-cause notes; do not overwrite existing notes.
- If fix uncovers a design flaw, create or reopen a design review on the parent epic's design doc.
