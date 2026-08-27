# CONTEXT.md format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Keep terms specific to the project's context.** Exclude general programming concepts such as timeouts, error types, and utility patterns even if the project uses them often. Before adding a term, ask whether it is unique to this context. Add it only if the answer is yes.
- **Group terms under subheadings.** Add groups when natural clusters emerge. Keep a flat list when every term belongs to one area.

## Single vs multi-context repos

Most repos have one context. Put one `CONTEXT.md` at the repo root.

Repos with multiple contexts use a root `CONTEXT-MAP.md` to list each context, its location, and its relationships:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md): receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md): generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md): manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

Choose the structure with these rules:

- If `CONTEXT-MAP.md` exists, read it to find contexts.
- If only a root `CONTEXT.md` exists, single context.
- If neither exists, create a root `CONTEXT.md` lazily when the first term is resolved.

When multiple contexts exist, infer which context owns the current topic. If you cannot tell, ask.
