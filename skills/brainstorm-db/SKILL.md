---
name: brainstorm-db
description: Interview-driven brainstorm for Subaya initiatives. Persists the resulting design document in the documents table (type=design) and upserts an initiative row. Use instead of superwisdom brainstorm when working in subaya-platform so artifacts live in Neon, not docs/plans/*.md.
---

# Brainstorm (DB-backed)

Adapts the superwisdom `brainstorm` skill. Persists the design document into the Subaya `documents` table and upserts an `initiatives` row, instead of writing `docs/plans/*.md`.

## When to use

Any time the user asks to brainstorm/design an initiative, feature, or major capability of the Subaya platform (this repo or a linked repo like ryusim).

## Flow

1. Explore context: read the current state of `initiatives` and any existing `documents` of type=design for the target initiative.
2. Interview the user via `AskUserQuestion` until the design is fully understood. One question at a time; multiple choice preferred.
3. Propose a robust approach via `AskUserQuestion`.
4. Write the full design body to a tmp file: use `lib-common/session.sh session_init brainstorm-db` → SESSION_DIR; write `draft.md` into it.
5. Persist:
   - `./lib-common/doc.sh upsert-initiative --slug=<slug> [...fields]` — returns initiative ID
   - `./lib-common/doc.sh create --type=design --initiative=<slug> --title="..." --body=@<SESSION_DIR>/draft.md` — returns document ID
   - `./lib-common/review.sh request <document_id>` — returns review ID; doc now `in_review`
6. Tell the user the review URL: `http://localhost:3100/documents/<document_id>`.
7. Exit.

## Revision mode

If the user re-invokes this skill and cites an existing document ID:
1. `./lib-common/review.sh fetch-comments <doc_id>` — pull open comments
2. Surface them. Interview user on revisions.
3. Write revised body. `./lib-common/doc.sh update <doc_id> --body=@...`.
4. `./lib-common/review.sh revise <doc_id>` — increments round.

## Rules

- Skill prompts remain superwisdom-faithful. Workflow is the same; only artifact targets change.
- Never write to `docs/plans/*.md`. The DB is the source of truth.
- Always hand the user a URL to the review UI so they can approve or comment.
