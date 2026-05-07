---
name: python-schema-migrations
description: Enforce a strict PostgreSQL-first schema management workflow for Python projects (SQLAlchemy -> raw SQL migration -> Pydantic -> OpenAPI -> generated TypeScript types).
tags:
  - python
  - sql
  - postgresql
  - migrations
  - sqlalchemy
  - pydantic
  - fastapi
  - openapi
  - typescript
---

Use these rules when designing or modifying Python data schemas and database-backed schema changes.

## 1) Scope and assumptions

- Use **raw PostgreSQL SQL files only** for schema changes.
- Migration filename is **one file per branch**: `/workspace/db/migrations/{branch-name}.sql`.
- `{branch-name}` is derived from the **current git branch** automatically.
- Prefer idempotent SQL (`IF NOT EXISTS`, `IF EXISTS`, guarded blocks) so migration can be replayed safely.
- Do not use psql-only commands (`\timing`, `\echo`, `\prompt`, etc.).

## 2) Workflow and ordering (mandatory)

When schema changes are requested, apply in this exact order:

1. Update **SQLAlchemy models**.
2. Update `/workspace/db/migrations/{branch-name}.sql` (create or append).
3. Update **Pydantic schemas**.
4. Regenerate FastAPI OpenAPI output.
5. Regenerate downstream TypeScript types from OpenAPI.

Do not stop at “migration written”; continue through all subsequent layers.

## 3) Database-first inspection and branch checks

Before drafting migration SQL:

- If MCP PostgreSQL tools are available, inspect the current DB state first:
  - existing schema objects affected by the requested change,
  - existing constraints/indices/defaults/sequences,
  - whether this branch migration has already been applied.
- Verify branch migration history status for idempotence planning (including whether a prior run partially applied changes).
- If MCP tools are not available, inspect existing migration SQL and model definitions before writing new SQL and note that live inspection is unavailable.

## 4) Migration file authoring rules

- Always write to `/workspace/db/migrations/{branch-name}.sql`.
- Use raw SQL statements only.
- Prefer appending to existing file for that branch rather than creating multiple branch files.
- Keep SQL **transaction-safe** when possible and avoid long blocking patterns.
- Before each destructive change, fetch and verify exact object names.

### Naming and branching discipline

- Use stable, explicit object names.
- For production index changes, use:
  - `CREATE INDEX CONCURRENTLY IF NOT EXISTS` for new indexes.
  - matching, guarded drops where necessary (`DROP INDEX IF EXISTS`), with caution around lock behavior.
- For relation updates, drop/recreate constraints only after confirming real constraint names with catalog queries.

## 5) Mandatory verification queries

Include explicit verification SQL in the migration file comments or sections:

- **Pre-change checks**: confirm current schema/objects and invariants.
- **Post-change checks**: confirm object creation/update and integrity guarantees after migration statements.

Examples to include when relevant:

- table/column existence and types,
- index existence and uniqueness,
- FK/CK constraints and their names,
- sample row counts for guard conditions (if applicable).

## 6) Constraint safety

- Never drop constraints by guessing names.
- Before `ALTER TABLE ... DROP CONSTRAINT ...`, obtain canonical names from catalog views and use exact names.
- Prefer `IF EXISTS` only where supported and meaningful.

## 7) Rollback policy

For destructive or non-trivial migrations, include rollback SQL in comments whenever practical, such as:

- reverse DDL statements,
- compensating data transformations,
- safe ordering notes.

## 8) Schema parity checks across layers

Every change must maintain cross-layer consistency:

- SQL migration.
- SQLAlchemy model definitions.
- Pydantic schema typing.
- FastAPI OpenAPI contract.
- generated TypeScript types.

Before finalizing:

- verify field types and nullability align between DB columns, SQLAlchemy, and Pydantic,
- verify relation naming and payload shapes match across layers,
- verify OpenAPI/TS outputs are regenerated after model/schema updates.

## 9) Standard task execution behavior

- Follow this order every time:
  1. SQLAlchemy models
  2. SQL migration file
  3. Pydantic schemas
  4. OpenAPI regeneration
  5. TypeScript regeneration
- Ask user to apply migration manually at the end, but **do not pause execution waiting for confirmation**; continue to complete non-blocking downstream tasks.

## 10) Anti-patterns

- Skipping DB precheck and assuming current state.
- Creating ad-hoc `Dict`-style response structures instead of typed schema updates.
- Writing non-idempotent migrations.
- Using psql meta-commands in migration files.
- Dropping constraints/indices by guessed names.
- Reordering layers (e.g., regenerating TS before OpenAPI).
- Treating migration file creation as the final step.

## 11) Execution checklist

Before concluding schema work, confirm all are done:

1. Current branch name resolved and migration path determined as `/workspace/db/migrations/{branch-name}.sql`.
2. DB inspection completed (MCP if available, fallback documented if not).
3. Branch migration status and existing branch migration objects checked.
4. Migration SQL is raw, idempotent, and includes pre/post verification queries.
5. Index additions use `CREATE INDEX CONCURRENTLY IF NOT EXISTS` where production-safe indexes are required.
6. Rollback SQL/comments added for larger/irreversible changes.
7. Constraint drops validated against real names from catalog.
8. SQLAlchemy models updated and aligned with migration.
9. Pydantic schemas updated and aligned.
10. FastAPI OpenAPI regenerated.
11. TypeScript types regenerated from OpenAPI.
12. Migration application request communicated to user without blocking remaining task execution.
