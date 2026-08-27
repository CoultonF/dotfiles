---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking or uses a 'grill' trigger phrase.
---

Interview the user relentlessly until you reach a shared understanding. Model the decisions as a **design tree**. Each decision branches into the decisions that depend on it.

Work the tree in **rounds**. The **frontier** contains every decision whose prerequisites are settled. You can ask those questions now without guessing about unanswered prerequisites. Ask the whole frontier in one round. Number each question and give your recommended answer. Then wait for the user's answers before the next round.

Each question should be formatted like so:

```
**Q1. <question title>**

<question body, which may include several paragraphs or choices>

Recommended answer: <your recommended answer>
```

Each round of answers reshapes the tree. Settled decisions push the frontier outward and unblock their dependent questions. Recompute the frontier, then ask the next round. If a question depends on another question that remains open in the current round, ask it in a later round.

Finding facts is your job, not the user's. When a frontier question needs a fact from the filesystem or another tool, send a subagent to find it. Do not ask the user for information you can look up.

Do not block on the subagent. Treat its investigation as an unsettled prerequisite. Hold only the questions that depend on its findings, and ask the rest of the frontier now. The **decisions** are the user's: put each to them and wait.

The session ends when the frontier is empty. You have visited every branch and left no assumption unstated. Do not act on the resulting plan or design until the user confirms that you share the same understanding.
