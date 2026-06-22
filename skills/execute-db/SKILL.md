---
name: execute-db
description: Walks the tasks in an approved plan document, implements each, and updates work_items fields + commits code. HARD-gated on the plan document status being 'approved' — refuses to run otherwise.
---

# Execute (DB-backed)

Adapts superwisdom `execute`. Walks the tasks in a plan, implements each, and updates `work_items` fields + commits code.

## Precondition (HARD GATE)

The plan document MUST be at status `approved`. On invocation, run:

```bash
STATUS=$(psql "$(neon cs)" -tA -c "SELECT status FROM documents WHERE id=<plan_doc_id>")
if [ "$STATUS" != "approved" ]; then
  echo "Cannot execute — plan document #<plan_doc_id> is at status '$STATUS'. Approve it in spec-ui first."
  exit 1
fi
```

If the gate fails, STOP and report the message above to the user. Do not proceed.

## Flow

1. Load the plan document body. Identify the epic (plan.work_item_id).
2. Fetch all descendant work_items: `SELECT * FROM work_items WHERE parent_id = <epic_id>` recursively.
3. For each unfinished task (status != 'complete'):
   a. Set `status='in_progress'` via doc.sh update or direct SQL.
   b. Read task details, implement the code change per the plan body.
   c. Run tests as the plan specifies.
   d. If task has TDD intent, update `test_status='passing'` and `test_location='<path>'`.
   e. Commit (`git commit -m "feat(...): <task title>"`).
   f. Set `status='complete'`.
4. **Epic-close — Definition-of-Done gate (HARD GATE).** Before flipping the
   epic to `complete`, run the wave DoD gate (Wave 24 / wi:1262). It enforces
   the loose-ends discipline: no descendant left `in_progress`, and every
   non-`complete` descendant is `deferred` with a non-empty why-note.

   ```bash
   scripts/check-wave-dod.sh <epic_id>   # exits non-zero if not closeable
   if [ $? -ne 0 ]; then
     echo "Cannot close epic #<epic_id> — file the loose ends first (docs/runbooks/loose-ends-ledger.md)."
     exit 1
   fi
   ```

   The script lives in the target repo (`subaya-platform`); run it from there.
   If the repo has no such script, fall back to the equivalent SQL check:
   no `in_progress` descendants AND every non-`complete` descendant is
   `deferred` with non-empty `notes`.

   Only when the gate passes, mark the epic `status='complete'`. Anything cut
   becomes a `deferred` work_item linked to this epic (or a future-wave epic)
   with a why-note — never silently dropped.

## Rules

- Never proceed past the approval gate if the plan isn't approved.
- Never close an epic that fails the Definition-of-Done gate.
- Every code change pairs with a commit.
- Work items move strictly forward through status (planned → in_progress → complete). Use `deferred` (with a why-note) for anything cut, or `blocked` if truly stuck.
