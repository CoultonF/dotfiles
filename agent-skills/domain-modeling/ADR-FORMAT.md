# ADR format

ADRs use sequential numbers and live in `docs/adr/`: `0001-slug.md`, `0002-slug.md`, and so on.

Create the `docs/adr/` directory lazily: only when the first ADR is needed.

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

Keep an ADR to one paragraph when that paragraph captures the decision and its reason. Do not add empty sections.

## Optional sections

Add an optional section only when it provides information the main paragraph does not. Most ADRs do not need one.

- Add `Status` frontmatter with `proposed | accepted | deprecated | superseded by ADR-NNNN` only when the team may revisit a decision.
- Add `## Considered options` only when rejected alternatives are worth remembering.
- Add `## Consequences` only when the decision has non-obvious downstream effects.

## Numbering

Find the highest existing number in `docs/adr/` and increment it by one.

## When to offer an ADR

Offer an ADR only when all three conditions are true:

1. **Hard to reverse.** The cost of changing your mind later is meaningful.
2. **Surprising without context.** A future reader will wonder, "Why did they do it this way?"
3. **Real trade-off.** The team considered real alternatives and chose one for specific reasons.

Skip a decision that is easy to reverse because the team can simply reverse it. If the choice is obvious, no one will need an explanation. If there was no real alternative, record the result elsewhere instead of inventing a decision.

### What qualifies

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. This does not cover every library, only choices that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance requirements." "Response times must be under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered GraphQL and picked REST for subtle reasons, record it; otherwise someone will suggest GraphQL again in six months.
