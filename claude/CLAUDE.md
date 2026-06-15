# Global Claude Code Preferences

## Style
- No emojis in output or code unless explicitly requested
- Terse responses — one sentence per update, avoid trailing summaries
- No multi-paragraph docstrings or multi-line comment blocks
- Default to writing no comments; add one only when the WHY is non-obvious

## Behaviour
- Prefer editing existing files over creating new ones
- Don't add features, refactor, or introduce abstractions beyond what the task requires
- Don't add error handling for scenarios that can't happen
- Only validate at system boundaries (user input, external APIs)
- Don't create planning or analysis documents unless asked

## Subagent Execution — tmux right pane

When the user asks for work that should run in a subagent (or any
long-running/parallel worker), run it in a tmux pane to the RIGHT of my pane.
Reuse the existing right pane if one is already there; only create one if not.

**Contract:** at most ONE persistent worker pane to the right, reused across
tasks. My own pane (`$TMUX_PANE`) stays focused — workers run with `-d`.

### 1. Resolve-or-create the right pane (idempotent, stateless)
Shell state doesn't persist between commands, so re-resolve every time:
```bash
RIGHT=$(tmux display-message -p -t '{right-of}' '#{pane_id}' 2>/dev/null)
if [ -z "$RIGHT" ]; then
  RIGHT=$(tmux split-window -h -d -t "$TMUX_PANE" -c "$PWD" -P -F '#{pane_id}')
fi
echo "$RIGHT"   # e.g. %7  — empty {right-of} means "no right pane yet"
```

### 2. Launch the coding agent in that pane (once)

If the pane isn't already running an agent, start one:
```bash
tmux send-keys -t "$RIGHT" 'omp --model gpt-5.5 --thinking medium' Enter
```
(Use `claude` instead of `omp` if a Claude subagent is wanted.)

### 3. Dispatch a task to it

Type the prompt, THEN send Enter as a separate call — the agent TUI sometimes
swallows a trailing Enter sent in the same keystroke batch:
```bash
tmux send-keys -t "$RIGHT" 'Refactor utils.py to remove the duplicate parse fn'
tmux send-keys -t "$RIGHT" Enter
```

### 4. Read the result back

```bash
tmux capture-pane -p -t "$RIGHT" | grep -v '^[[:space:]]*$' | tail -40
```
Poll/capture until the worker is idle, then report its answer to the user.

### Notes

- **One-shot instead of persistent:** for a single task, skip the interactive
  agent and run `tmux send-keys -t "$RIGHT" 'omp -p --model gpt-5.5 "<task>"' Enter`.
- **True parallelism:** for multiple concurrent subagents, create extra splits
  with `tmux split-window -h -d -t "$RIGHT" -P -F '#{pane_id}'` and track each id.
- **Cleanup:** `tmux kill-pane -t "$RIGHT"` when the worker is no longer needed.
- **Reuse detection is geometric, not identity-based.** `{right-of}` finds whatever
  pane sits to the right — not necessarily the agent pane. To be precise, tag the
  worker with `tmux select-pane -T omp-worker` and match on `#{pane_title}`.
