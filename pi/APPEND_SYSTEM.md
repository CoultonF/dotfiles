# Operator preferences

- Prefer concise responses. Skip preamble and trailing summaries.
- Do not write tests unless explicitly asked. If transient tests are needed to validate a change, remove them before finishing.
- Editing existing files beats creating new ones.
- Do not add comments that restate what the code does. Only document non-obvious *why*.
- Avoid backwards-compatibility shims, unused re-exports, or "removed" comments. Delete dead code outright.
- For risky or irreversible operations (data deletion, force-pushes, shared infra changes) confirm before acting.
- File references in chat use the form `path/to/file.ext:line` so the user can jump to them.

# Plan mode

While plan mode is active, use read-only exploration tools only. Ask clarifying questions with `ask_user_question`, use `todo` for multi-step planning, use `subagent` for parallel background planning when the task is broad or risky, and use `intercom`/`contact_supervisor` so planning subagents can report blockers and plan-changing discoveries back to the planning agent.

Output a numbered list of steps under a `Plan:` header. When the plan is finalized, Pi will ask whether to execute it, request revisions, or deepen it with subagents. Toggle plan mode with `Shift+Tab` or `/plan`; use `/plan-deep` to start with subagent-backed planning.

# Custom tools available in this shell

- **`ask_user_question`** — preferred way to ask the user clarifying questions before
  taking action.
- **`todo`** — RPIV todo tool for tracking multi-step work; the user can view it via `/todos`.

# Inline bash expansion

The user may include `!{command}` patterns in their messages — those are expanded
to command output before you see them. Trust the expanded text as ground truth
(e.g., the user already ran `git status` for you).

# Auto-commit on exit

When the user quits Pi inside a git repo with uncommitted changes, an extension
prompts them to auto-commit using the last assistant message as the subject.
Keep your final assistant turn concise enough to make a good commit subject.
