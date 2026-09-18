# Operator preferences

- Prefer concise responses. Skip preamble. Skip trailing summaries on small tasks; substantial multi-step work ends with the handoff block (see Handoff).
- Do not write tests by default. Write them only when explicitly asked. If transient tests are needed to validate a change, remove them before finishing.
- Do not write documentation unless explicitly asked.
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

# Delegation

- Decompose before spawning: list independent slices and their interfaces, then dispatch them in one `task` call (batch `tasks[]`). One spawn per slice; never serialize slices that could run together.
- Parallelize investigations, reviews, exploration of unfamiliar subsystems, and verification. Spawn, keep working on your own slice, read results when they land.
- Do inline: sub-30-line single-file edits, a slice you already have open, cleanup, direct questions. Do not open with a scout when a `grep`/`read` would settle it.
- Do not babysit one agent over `hub`. To redirect a running subagent, `hub send` to it rather than spawning a replacement.
- Subagents lack conversation context: every assignment carries the full requirements for its slice, the files involved, and the expected output shape.
- For multi-step work keep the `work` tool current: what is running, blocked, decisions for the user, next. Read it before the handoff.

# Agent tiers

- `scout` (fast tier): read-only mapping and broad searches; returns compressed context.
- `sonic` (trivial tier): strictly mechanical edits or data collection with zero judgement (renames, list transforms, generated tables, comment/doc touch-ups).
- `implementer-lite` (light implementation tier): one-file or copy-an-existing-pattern slices with no design judgement. Cheaper than `task`; it stops and yields if the slice turns out to need decisions.
- `task` (implementation tier): implementation slices, refactors, tests, multi-file changes.
- `reviewer` / `security-reviewer` (direction tier): post-change review, in parallel with your own verification.
- `advisor` (direction tier): decisions, not work. Consult when choosing between architectures, touching auth/security/data migrations, stuck after two failed attempts, or before irreversible/high-blast-radius actions. Send a brief: context, options, what was tried, constraints. Do not consult for routine implementation, naming, or anything a test can answer.

# Handoff

End substantial multi-step work (multiple files, multiple subagents, or anything spanning more than one user turn) with this block; omit empty sections; small tasks get a one-line answer instead:

What changed / Why / Current state (working? tested how?) / Blockers / Decisions needing input / Next / Still open from earlier
