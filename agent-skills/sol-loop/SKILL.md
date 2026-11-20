---
name: sol-loop
description: Use when the user says "sol loop".
---

# sol-loop

This is a workflow for making your code changes more correct before (or
sometimes after) filing a pull request. tl;dr - use OpenAI's GPT Sol and
Google's Gemini Neon to review your code in a loop.

Make the most minimal possible changes to appease the reviewers. Be careful
of scope creep and don't be scared to push back.

## Budget

- Default: 3 rounds total. Round 1 is full. Later rounds check only
  changed code and open findings.
- Extend to 5 only for security, permissions, auth, data loss, or
  state/concurrency, while a blocker or should stays open with evidence. Or when
  the user asks.
- Stop early if a round returns only nits. Declined nits and comment,
  doc, or format-only fixes need no new round.
- Two reviewers per round, Sol and Neon, run in parallel. Neither may start
  subagents or reviewers.
- Keep a ledger: id, reviewer, severity, outcome, usage if returned. Never
  guess it. One entry per issue; if both reviewers raise it, list both.

## 1. Scope

Run `git status --short`. Do not stash, discard, or include unrelated
changes. Limit review to the change paths if they separate cleanly.
Otherwise stop and ask.

Find the base after `git fetch origin`:

- PR: `gh pr view <n> --json baseRefName,headRefOid`. Check out the branch
  only if clean. Confirm `HEAD` is the PR head, or ahead only by this
  change. Base: `git merge-base HEAD origin/<baseRefName>`.
- Local: `git merge-base HEAD origin/<default-branch>`. No remote: a base
  the user names, or `HEAD` for uncommitted changes only.

The change is base to working tree in those paths, with untracked files.
Use one diff command all rounds. State intent and out-of-scope in 1-2
sentences. Run covering checks. Do not send code this change breaks. Note
missing or pre-failing checks in the brief.

## 2. Start Sol and Neon

In T3, call `orchestrator_capabilities`. Pick the latest Sol and the latest
Gemini Neon (Antigravity provider) unless the user named versions. Do not
hardcode an ID. Record provider, model, and effort only if exposed. Each
round, start both with `delegate_task` (`role: "review"`, `mode: "async"`)
and the same brief. Save each `taskId`. New `clientRequestId` per reviewer
per round. `childThreadId` is storage, not the next target. Do not use
`t3_thread_send`, `create_threads`, or `t3_thread_launch` for review.

If T3 tools are not listed, try one direct capability call. Outside T3, use
native subagents and keep their IDs. In Claude Code, use a custom subagent
only if it is set up to run that model. If no route runs Sol, report the
blocker. If no route runs Neon, tell the user and continue with Sol alone.
Do not substitute a model.

Do not edit scoped files while either review runs. Wait for the notices.
When one result arrives, check its findings while the other runs. Do not
poll or start extra reviewers. Timeout, error, or no reply is not approval.
On failure, cancel that reviewer, verify stop, restart it with the ledger.

Round 1 brief (T3 children get no history). Use id prefix `S` for Sol and
`N` for Neon:

```
Review only. Do not edit, commit, push, comment on PRs, or start subagents.
Id prefix: <S|N>
Repo: <abs path> Base: <sha> Intent: <intent> Out of scope: <scope> Checks: <results>
See: git diff <base> [-- <paths>]; git status --short (read untracked).
Read surrounding code. Find bugs, broken callers, mismatch with intent.
Skip style unless it hides a bug. Hold to the smallest change. Flag code,
tests, or guards the intent does not need. Other paths, rare cases, small
perf, extra compat: nits.
blocker = intended case wrong. should = real bug callers will hit, in intent. nit = rest.
Reply:
VERDICT: APPROVE or CHANGES
<prefix>1 [blocker|should|nit] <file>:<line> <claim>. Fix: <suggestion> (stable ids)
```

## 3. Answer findings

Check each finding and severity yourself. Another path, rare case, or
small cost is a nit, whatever label it came with. Agreement between the
reviewers is not evidence; check the code.

- Agree: smallest fix. Prefer delete or narrow over new lock, cache,
  helper, or option. Fix the case that happened. Add one focused test
  that fails without the fix, if intent needs it.
- Disagree: say why, with evidence (file:line, test, output).
- Out of scope or nit: decline in one line. List as follow-up.

Update the ledger. Re-run checks and `git diff --shortstat <base>`. If
review grew the diff, cut first. Do not agree just to end the loop.

## 4. Next round

Start one only if budget remains and a blocker or should is open, behavior code
changed, or approval does not cover the current behavior diff. Run both
reviewers again, even one that approved, if behavior code changed since its
approval. Use a fresh `delegate_task` per reviewer in T3, or follow up the
saved native IDs. Send the round 1 brief, the full ledger from both reviewers
(`fixed:` / `disagree:` / `declined:` + evidence), the same base diff, and the
change since last round. Tell each reviewer: open ids and changed code only.
Mark each old id `resolved` or `still open: <reason>`.

## 5. Stop and ship

Agreed: APPROVE from every reviewer that ran, on the current behavior
diff, no blocker or should open, no concern of your own. Stuck: an item stays disputed after two replies,
or budget ends. Show both sides in 2-3 lines each. The user decides.
Budget end is not approval.

Do not push during the loop. Push after agreement only if the user asked
to push, ship, or update the PR. If you push to a PR, add above the model
blurb:

`Reviewed with sol-loop: <N> rounds with <Sol model> and <Neon model>. Verdicts: Sol approved, Neon approved`.

Name only the reviewers that ran. Add `on <effort>` only if verified.

Report: rounds, models, what each reviewer changed, diff size before/after,
fixed and declined findings with reasons, usage if exposed (else say not),
pushed or not.
