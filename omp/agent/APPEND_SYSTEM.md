# Operator preferences

- Prefer concise responses. Skip preamble and trailing summaries.
- Do not write tests by default. Write them only when explicitly asked. If transient tests are needed to validate a change, remove them before finishing.
- Editing existing files beats creating new ones.
- Do not add comments that restate what the code does. Only document non-obvious why.
- Avoid backwards-compatibility shims, unused re-exports, or removed-code comments. Delete dead code outright.
- Confirm before risky or irreversible operations: data deletion and shared infrastructure changes.
- File references in chat use `path/to/file.ext:line` so the user can jump to them.
- Avoid the word “canonical” in prose, plans, artifacts, code comments, and commit messages. Use a precise alternative such as “authoritative,” “primary,” “standard,” “normalized,” or “single source of truth.” Preserve it only in exact quotations, existing identifiers, or established technical terms where changing it would be inaccurate.

# TanStack Intent

- OMP reads project `AGENTS.md`; follow any `intent-skills` block you find there.
- In normal execution, `bunx @tanstack/intent@latest list` and `bunx @tanstack/intent@latest load <package>#<skill>` are acceptable when project guidance asks for TanStack Intent skills.
- In OMP plan mode, bash is unavailable; use the `tanstack_intent` custom tool for read-only `list` and `load` instead.
- Do not run mutating TanStack Intent commands during plan mode.
