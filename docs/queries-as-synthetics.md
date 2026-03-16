# Queries as Synthetic Tests

## Goal

Implement the **queries** exposed by our Apollo Server schema as a series of **synthetic tests**. Queries are read-only and do not change server state, so they are the preferred starting point.

## Approach

- **One query → one or more synthetic tests**: For each query in the schema (or a curated subset), implement at least one synthetic that:
  - Calls the query with valid arguments (and possibly with edge-case or invalid arguments where useful).
  - Asserts on response shape, status, and critical fields.
- **Schema-driven**: Use the ingested schema to:
  - List available queries.
  - Know required/optional arguments and types.
  - Validate that we have coverage for the queries we care about.

## Why start with queries

- No side effects: queries don’t create or modify data, so they’re safe to run repeatedly in production.
- Simpler than mutations: no need for setup/teardown or workflow ordering.
- Foundation for mutation workflows: once query synthetics are in place, we can reuse similar patterns and tooling for mutation workflows.

## Out of scope (for this phase)

- Mutations are handled separately as **workflows** (see [Mutations as workflows](./mutations-as-workflows.md)), not as one-off synthetic calls.
