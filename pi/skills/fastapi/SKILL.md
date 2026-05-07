---
name: fastapi
description: Primary guidance for building FastAPI backend endpoints with async execution, typed schemas, secure auth, and frontend-oriented API contracts.
tags:
  - fastapi
  - python
  - sqlalchemy
  - pydantic
  - async
  - authentication
  - authorization
  - openapi
  - typescript
---

Use these rules when building and reviewing FastAPI back-end endpoints.

## 1) Scope and architecture

- Favor a **backend-for-frontend (BFF)** shape for endpoint contracts.
  - Expose frontend-facing actions, not raw domain service internals.
  - Aggregate and compose data per use case.
- Prefer explicit RPC-style endpoints over generic CRUD patterns.
- Keep APIs small, explicit, and stable for consumers.

## 2) Routers and endpoint design

- Define endpoints with `APIRouter` and group by bounded context/use case.
- Use consistent route prefixes/tags and explicit response status codes.
- Keep route semantics clear and action-oriented.
- Prefer read/update/create/delete endpoints that reflect business actions, not table-level CRUD abstractions.

## 3) Async and session handling

- Use `async`/`await` for all I/O in route handlers.
- Inject `AsyncSession` via dependencies for all DB interactions.
- Session lifecycle must avoid long-lived or dangling sessions:
  - commit on success,
  - rollback on failure,
  - close/cleanup promptly.
- Use `flush()` when immediate generated values are required in the same request flow.

## 4) Request/response schema standards

- Define explicit Pydantic request and response models.
- Always set `response_model` on route decorators for response typing.
- Keep response models separate from internal persistence models when needed.
- Keep API contracts explicit for OpenAPI docs quality and consumer expectations.

## 5) Error handling and HTTP behavior

- Return/raise consistent `HTTPException` errors with explicit status codes.
- Use secure, non-leaky error messages.
- Encode validation, authorization, and domain errors predictably across endpoints.

## 6) Security: authn/authz

- Use prebuilt FastAPI authentication and authorization dependencies for protected endpoints/routers.
- Enforce authorization at route or router scope as appropriate.
- Use OPA-based authorization for protected actions.
- When adding or modifying endpoints, update the matching `api.rego` policy file.

## 7) OpenAPI and typed client generation

- Regenerate OpenAPI after endpoint or schema changes.
- Regenerate TypeScript types via the TypeScript OpenAPI skill (`bun run generate-types`) after OpenAPI updates.
- Keep OpenAPI and generated types synchronized with route and schema changes.

## 8) Database access guardrails

- Keep query behavior bounded and intention-revealing.
- Avoid broad unbounded reads in request handlers when a bounded subset is enough.
- Do not use psql meta-commands (for example `\timing`, `\echo`, `\prompt`) in app code or migration workflow references here.

## 9) Prohibited patterns

- Missing `response_model` on external endpoints.
- Sync/blocking DB access in async routes.
- Opening sessions and leaving them uncommitted/unrolled back.
- CRUD-style wrappers that hide action intent.
- Adding endpoints without corresponding OPA policy updates.

## 10) Review checklist

Before merging a FastAPI change, verify:

1. Route names/paths are clear and BFF-oriented.
2. Handler uses `async` and `AsyncSession` DI.
3. `response_model` is explicitly declared and response schemas are correct.
4. Transaction behavior is safe: commit/rollback/close are covered.
5. Authn/authz dependencies are applied correctly.
6. OPA policy update is present for new/changed protected endpoints.
7. OpenAPI and TS types are regenerated after API/schema changes.
