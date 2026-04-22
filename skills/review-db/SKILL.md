---
name: review-db
description: Agent acts as reviewer on a design or plan document, leaving comments in review_comments with author_type='agent'. Does not change the document's overall review status — only humans approve/reject.
---

# Review (DB-backed)

Adapts superwisdom `review`. Agent acts as a reviewer on a target document (design or plan) and leaves comments in `review_comments` with `author_type='agent'`.

## Flow

1. Load the target: `psql -c "SELECT id, type, title, body_md, status FROM documents WHERE id=<doc_id>"`.
2. Fetch the corresponding `design_reviews` row (via `document_id`) and its `current_round`.
3. Read the body critically. For each section (`##`), form an opinion: approve / comment / reject.
4. Write comments via SQL:

```bash
psql "$(neon cs)" -c "INSERT INTO review_comments (review_id, author_type, section, body, round, status) \
  VALUES (<review_id>, 'agent', '<section>', '<comment text, escaped>', <round>, 'open');"
```

5. Optionally mark sections approved in `review_sections`.
6. Never change `design_reviews.status` — only humans approve or reject overall.

## Rules

- Agent comments are advisory. Visual distinction in the spec-ui UI separates agent vs human feedback.
- Keep comments focused: what's wrong, what to change, or "approved with no changes".
