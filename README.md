# superwisdom-db

DB-backed adaptations of [seiraiyu-superwisdom](https://github.com/stonelyd/seiraiyu-superwisdom) skills. Instead of writing to `docs/plans/*.md`, the skills persist artifacts in a Postgres database.

## Status

v0.1 targets the Subaya platform schema specifically (`initiatives`, `work_items`, `documents`, `design_reviews`). Generalization to arbitrary schemas is deferred.

## Skills

| Skill | Purpose |
|-------|---------|
| `brainstorm-db` | Interview → design document + initiative upsert |
| `plan-db`       | Plan document + work_items population (requires approved design) |
| `execute-db`    | Walk plan tasks, modify code, update work_items (requires approved plan) |
| `review-db`     | Agent-side review; writes review_comments with author_type=agent |
| `debug-db`      | Investigate failing work_item, fix code, update test_status + notes |
| `tdd-db`        | Red-green-refactor cycle; updates test_location + test_status |

## Install (Subaya dev)

Symlink this repo into the subaya-platform plugins directory:

```bash
ln -s ~/superwisdom-db ~/subaya-platform/.claude/plugins/superwisdom-db
```

Then invoke skills by their name prefixed with `/` in Claude Code.

## Dependencies

- `psql` client
- `neon` CLI authenticated (`neon cs` returns a valid connection string)
- `jq` (used by lib-common scripts for JSON handling)
