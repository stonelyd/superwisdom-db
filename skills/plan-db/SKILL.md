---
name: plan-db
description: Produce a plan document anchored on a work_item/epic, populating work_items (epics/stories/tasks) and work_item_specs links, based on an approved design document. Requires the design document to be at status=approved before proceeding.
---

# Plan (DB-backed)

Adapts superwisdom `plan`. Produces a plan document in `documents` and populates `work_items` (epics/stories/tasks) + `work_item_specs` links, based on an approved design document.

## Precondition (HARD)

The design document for the target initiative MUST be at status `approved`. If not, STOP and instruct the user to approve it first:

```
./lib-common/doc.sh update <design_doc_id> --status=approved  # only if user asks to bypass review
```

Otherwise, typical flow is: the user approves via spec-ui.

To check:
```bash
psql "$(neon cs)" -c "SELECT id, title, status FROM documents WHERE id=<design_doc_id>;"
```

## Flow

1. Load the approved design: `SELECT * FROM documents WHERE id=<design_doc_id>`.
2. Interview the user on phase breakdown, epics, stories, tasks.
3. Propose the plan via `AskUserQuestion`.
4. Persist:
   - For each epic: `./lib-common/doc.sh upsert-work-item --type=epic --initiative=<slug> --title="..."` → epic ID
   - For each story: `--type=story --parent=<epic_id> --title="..."` → story ID
   - For each task: `--type=task --parent=<story_id> --title="..."` → task ID
   - For each spec link: `./lib-common/doc.sh link-spec --work-item=<id> --spec-type=<t> --spec-id=<id>`
5. Write the full plan body (with the task/phase table) to a SESSION_DIR file.
6. `./lib-common/doc.sh create --type=plan --work-item=<epic_id> --title="..." --body=@...` → plan doc ID
7. `./lib-common/review.sh request <plan_doc_id>`.
8. Tell user the review URL; exit.

## Rules

- Plan docs anchor on the **epic** (work_item), not the initiative.
- Every task should map to at least one spec entity via `work_item_specs` if possible.
- Stories and tasks must have a parent; CHECK constraints in `work_items` enforce this.
