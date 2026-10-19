# Coulton's workflow

- **One set of development servers per devcontainer**, running in the repository root
  checkout. Never start them anywhere else.
- **Work that doesn't need the development servers goes in a git worktree**, and a worktree
  is plain git: edit, commit, push. Don't install dependencies or start servers in one, so
  the devcontainer stays lean.
- **To test worktree code against the development servers**, switch the root checkout to that
  code, but only if the root isn't actively in use by other work. Put the root back afterwards.
- **Work that needs the development servers from the start** goes in the root checkout when
  it is free.
- **When the root is busy and more parallel work needs the development servers**, launch a
  remote devcontainer and run that session there. Name them `aws1`, `aws2`, `aws3`, taking
  the first free name.

When starting a task, say in one line where it will run and why.

## Coding-agent routing

Use the lightest role that fits the assignment. Supply the objective, owned files or
interfaces, constraints, acceptance criteria, known evidence, and verification owner.
Keep existing `tmux-controller` use separate from this coding roster.

| Claude role | Model / effort | Assign when |
|---|---|---|
| `quick-scout` | haiku / low | A narrow factual question needs paths, callers, and a short trace, not a redesign. |
| `implementer-lite` | haiku / medium | The local change is decided or follows an established pattern. |
| `implementer` | sonnet / medium | One coherent behavior change needs implementation within agreed files and interfaces. |
| `reviewer` | opus / high | A supplied diff needs independent, evidence-backed defect review. |
| `background-planner` | opus / high | A change needs a recommendation, ordered edits, affected callers, and acceptance checks. |
| `evidence-researcher` | sonnet / high | One decision needs dated, versioned sources and contradictions resolved. |
| `ui-verifier` | sonnet / medium | An existing preview needs actual browser interaction and visual/console evidence. |

Codex uses the same saved role names. Dispatch there with the exact saved
`agent_type`; `agent_name` is only a lowercase underscore instance nickname, such as
`quick_scout` or `ui_verifier`, with `_2`, `_3`, etc. for additional instances.
OMP keeps its native `scout`, `task`, and `reviewer` identities for scout,
implementation, and review; its other four coding roles use the names above.
Existing OMP `advisor`, `sonic`, and `security-reviewer` remain separate roles.

## Ownership and evidence

- Workers own only their assigned scope and preserve unrelated changes. Return
  design/ownership ambiguity and blockers to the parent; model promotion is a
  parent decision carrying evidence and partial work, never a silent fallback.
  Account/model availability and effective tool exposure must be checked in the
  active harness. Report unavailable routing or conflicting local/project
  definitions rather than substituting a model. If the resolved Haiku model does
  not support effort, omit effort only for the two Haiku definitions and report
  that exception.
- Assign verification to one owner. Parent-owned checks stay pending in worker
  reports, not concurrent tests/builds/linters/formatters. A reviewer may run a
  bounded non-mutating reproduction in memory or disposable external scratch
  space, but runs caller-specified checks only when assigned verification ownership.
  Do not repeat a user-reported failure just to confirm it.
- Workers do not add permanent tests unless requested, push, merge, perform
  unrelated cleanup, or delegate recursively. Implementation workers commit only
  when asked. Planning and research return chat text, not files; background
  scheduling is caller-controlled.
- Scout uses `Read`, `Grep`, and `Glob` in plan mode. Planner/researcher add web
  search/fetch in plan mode. Reviewer has `Bash` in default permission mode, not a
  technical read-only sandbox: no repository/fixture edits, dependencies, servers,
  migrations, or production access. Implementers have editing and shell tools in
  default mode.
- UI inherits available browser MCP, tool discovery, and shell access but denies
  `Edit`, `Write`, `NotebookEdit`, and `Agent`. Use an existing browser facility,
  connected browser MCP, or already-installed headless Chromium through Playwright;
  direct DevTools protocol is an alternative if the module is unavailable. Never
  install a browser/package, add a connector, start a server, log in, or make
  consequential submissions. Use only the supplied preview and safe scenarios;
  keep drivers/screenshots outside the repository and release only owned resources.
  Missing interactive browser access or an inaccessible preview is `BLOCKED`,
  never screenshot-only success.
- Tool restrictions describe permitted use, not a security sandbox. Codex roles
  inherit parent permissions, including any bypass configuration; saved prose
  does not override it. OMP allowlists do not sandbox additive tools or `eval`.

Every worker returns `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`,
with concrete evidence and limitations. `DONE` requires assigned checks to pass.
A complete implementation with parent-owned checks pending returns
`DONE_WITH_CONCERNS` and names the unverified checks. Report exact executed
commands/results, relevant file anchors or sources, observed versus expected UI
behavior, and untested scope. Record a supplied revision or `unknown`, never an
invented revision or result.
