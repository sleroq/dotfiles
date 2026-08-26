# DDD Guide

Use DDD to keep business logic explicit, testable, and isolated from technical details.

## Core rule

When deciding where code belongs, ask:

* **Domain**: business rules, invariants, and state changes.
* **Application**: coordinates use cases and orchestration.
* **Infrastructure**: databases, HTTP, queues, external APIs, etc.

Dependencies should point toward the domain:

```text
HTTP / gRPC / CLI
        ↓
   Application
        ↓
      Domain

Infrastructure → Application / Domain abstractions
```

The **Domain must not depend on Application or Infrastructure**.

## Modeling rules

* **Entity**: use when identity and lifecycle matter.
* **Value Object**: use when the value itself defines the concept. Prefer immutable value objects.
* **Domain Service**: use for business behavior that does not naturally belong to one entity or value object.
* **Aggregate**: treat it as a transactional consistency boundary.
* Modify aggregate state through its aggregate root.
* Keep aggregates small. Reference other aggregates by ID instead of building large object graphs.
* Define **bounded contexts** where terminology and business rules have consistent meanings.
* Allow different bounded contexts to model the same real-world concept differently.
* Keep application services focused on orchestration, not business decisions.
* Use domain events for meaningful business facts that need to affect other parts of the system.

## Do

* Use business terminology in code.
* Put business rules inside domain entities, value objects, or domain services.
* Protect invariants and prevent invalid states.
* Prefer intent-revealing methods:

```go
order.Pay()
subscription.Suspend()
```

instead of:

```go
order.Status = "paid"
```

* Use value objects for meaningful concepts such as `Money`, `Email`, or `OrderID`.
* Keep aggregate boundaries based on consistency requirements.
* Define small interfaces near their consumers.
* Keep persistence and external services behind abstractions where useful.
* Define repositories around domain needs, not generic database CRUD.
* Organize packages around business capabilities where practical.
* Keep domain logic testable without databases, HTTP servers, queues, or external APIs.

## Don't

* Don't model the domain as database tables.
* Don't let HTTP, SQL, Kafka, Redis, or framework types leak into domain code.
* Don't pass transport or persistence DTOs directly into the domain.
* Don't create giant shared `models`, `services`, `repositories`, or `utils` packages.
* Don't force bounded contexts to share one universal model.
* Don't put business decisions into application services.
* Don't turn domain services into dumping grounds for unrelated logic.
* Don't create interfaces or abstractions “just in case.”
* Don't use domain events where a normal method call is sufficient.
* Don't add DDD patterns unless they solve an actual problem.

## Repositories

Repositories should expose operations required by the domain or application:

```go
type OrderRepository interface {
    ByID(ctx context.Context, id OrderID) (*Order, error)
    Save(ctx context.Context, order *Order) error
}
```

Avoid designing repositories as generic database wrappers:

```go
Create()
Read()
Update()
Delete()
List()
```

## Application services

Application services coordinate a use case:

```text
Load aggregate
→ invoke domain behavior
→ persist changes
→ call external systems
→ return result
```

They may handle transactions, authorization, repositories, and external calls, but should contain little or no business decision-making.

## Domain events

Use domain events when an important domain fact needs to trigger behavior elsewhere, especially across aggregate boundaries.

Prefer past-tense names:

```text
OrderPaid
SubscriptionCancelled
InvoiceOverdue
```

Events represent facts that have already happened.

## Decision checklist

When adding new behavior, ask:

1. **What is the business concept?**
2. **What invariant must always hold?**
3. **Which bounded context owns it?**
4. **Which aggregate owns the rule?**
5. **Is this a business decision or just orchestration?**
6. **Does it depend on external infrastructure?**
7. **Can the domain behavior be tested without DB/network access?**

## Default principle

Prefer the **simplest design that keeps business rules explicit and domain boundaries clean**.

DDD is about modeling the business well, not maximizing the number of folders, interfaces, abstractions, or patterns.
