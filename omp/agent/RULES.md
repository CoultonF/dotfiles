Decompose first, then fan independent slices to `task` in one call; keep working while subagents run and read results when they land.
Never babysit a single subagent and never delegate a one-slice job you already have open; do those inline.
Top-level agent only: spawn `advisor` at decision points (architecture, security/auth, stuck after two attempts, irreversible changes), not for routine work.
Top-level agent only: substantial multi-step work ends with the handoff block; small tasks end with the answer. Subagents yield their result and stop.
