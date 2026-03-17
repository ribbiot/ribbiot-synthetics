# Mutations as Workflows

## Goal

Exercise **mutations** from our Apollo Server schema in a **production-safe** way by implementing them as **multi-step API workflows** that create, optionally modify, and then **delete** (or otherwise tear down) data. This avoids polluting production with synthetic data while still testing mutation behaviour in a prod setting.

## Approach

- **Workflow = multi-step synthetic**: Each mutation (or group of related mutations) is tested as a **workflow**:
  1. **Create** — Call mutation(s) to create the minimal data needed (e.g. create a test entity).
  2. **Modify** (optional) — Call mutation(s) that update that data, if we want to test update behaviour.
  3. **Delete / teardown** — Call mutation(s) or cleanup steps to remove the data so the environment is left clean.

- **No persistent synthetic data**: By always ending with delete/teardown, we don’t leave synthetic records in production.

- **Prod setting**: These workflows run in the same prod (or prod-like) environment as the rest of our synthetics, so we validate real API behaviour and configuration.

## Why workflows instead of one-off mutation tests

- **One-off mutations** would create or change data and leave it behind → pollutes production and can confuse real usage.
- **Workflows** keep tests self-contained: create → use → delete, so production stays clean while we still cover create/modify/delete paths.

## Implementation notes (to be defined)

- Map each mutation (or logical group) in the schema to a workflow definition.
- Ensure workflows are **idempotent** or **isolated** where possible (e.g. unique IDs or names so concurrent runs don’t clash).
- Consider ordering and dependencies: some mutations may depend on data created in an earlier step of the same workflow.
