# Holonia Role and Authority Architecture

This page expands the role model behind NearBridge without implying that the
future Holonia network is already implemented. NearBridge is the current
runnable foundation; Holonia Core and Specialized Networks remain later work.

## Role model

```mermaid
flowchart TD
    Person["Person or organization"] --> Account["Primary Holon Account<br/>stable identity, relationships, history"]
    Account --> Impl["Selected Primary Holon Implementation<br/>replaceable model or Agent"]
    Impl --> Proposal["Proposal"]
    Proposal --> Host["Holonia Host<br/>policy, keys, permissions, audit"]
    Host -->|"human-approved local action"| NearBridge["NearBridge<br/>current local capability path"]
    Host -.-> Core["Holonia Core<br/>future bounded requests"]
    Core -.-> Networks["Specialized Networks<br/>code, procurement, hiring, compute, …"]
```

## Interpretation

- A **Primary Holon Account** is the stable identity and relationship layer.
- A **Primary Holon Implementation** is replaceable software serving that
  account; selecting an implementation does not grant it Host authority.
- An implementation proposes work. The **Holonia Host** owns keys, policy,
  permissions, audit, and high-risk execution decisions.
- **NearBridge** is the implemented local path through which an explicitly
  approved, bounded capability can run and return correlated evidence.
- **Holonia Core** and **Specialized Networks** will later add propagation,
  private-session semantics, matching, acceptance, reputation, payment, and
  domain-specific rules.

The governing principle is unchanged:

> **Holon proposes. Host enforces. Human authorizes.**
