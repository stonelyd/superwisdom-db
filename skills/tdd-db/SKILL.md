---
name: tdd-db
description: Red-green-refactor cycle for a work_item (usually a task). Updates test_location and test_status per phase. Enforces red-first; never skip.
---

# TDD (DB-backed)

Adapts superwisdom `tdd`. Red-green-refactor cycle with work_item fields updated per cycle phase.

## Flow

For a work_item (typically type=task):

1. **Red:** Write a test file. Commit.
   ```bash
   psql "$(neon cs)" -c "UPDATE work_items SET test_location='<path>', test_status='failing', status='in_progress', updated_at=now() WHERE id=<id>;"
   ```
   Run test; expect FAIL.

2. **Green:** Implement minimum code to pass. Commit.
   ```bash
   psql "$(neon cs)" -c "UPDATE work_items SET test_status='passing', updated_at=now() WHERE id=<id>;"
   ```
   Run test; expect PASS.

3. **Refactor:** Clean up code. Run test; expect STILL PASS. Commit.

4. Mark task complete:
   ```bash
   psql "$(neon cs)" -c "UPDATE work_items SET status='complete', updated_at=now() WHERE id=<id>;"
   ```

## Rules

- Never skip red. If a test doesn't fail first, it isn't a real test.
- One small green step at a time. Don't over-implement.
- Refactor only once green.
