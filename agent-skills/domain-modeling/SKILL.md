---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when discussing codebase terminology, writing or editing a CONTEXT.md, or recording or editing an ADR.
---

# Domain modeling

Build and sharpen the project's domain model as you design. This is the *active* discipline. Challenge terms, invent edge-case scenarios, and write the glossary and decisions down when they become clear. Reading `CONTEXT.md` for vocabulary is a separate one-line habit. Use this skill when you are changing the model, not merely consuming it.

## File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/                 ← context-specific decisions
```

Create files lazily: only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose one precise term. "The word 'account' is ambiguous. Do you mean Customer or User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update CONTEXT.md as terms settle

When a term is resolved, update `CONTEXT.md` at once. Do not batch these changes. Follow [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

Keep `CONTEXT.md` free of implementation details. It is a glossary, not a spec, scratch pad, or place for implementation decisions.

### Offer ADRs sparingly

Offer to create an ADR only when all three conditions are true:

1. **Hard to reverse.** The cost of changing your mind later is meaningful.
2. **Surprising without context.** A future reader will wonder, "Why did they do it this way?"
3. **Real trade-off.** The team considered real alternatives and chose one for specific reasons.

If any condition is missing, skip the ADR. Follow [ADR-FORMAT.md](./ADR-FORMAT.md).
