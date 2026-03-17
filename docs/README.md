# Synthetic Tests Documentation

This folder documents the approach for synthetic testing of our GraphQL APIs (Apollo Server).

## Dev-only scope

The schema exploration, MCP, and synthetic-test development setup described here is **dev-only**. There is a deliberate firewall between dev and production; none of it should be used with production. Promoting dev configuration to production will be a **separate process**, defined later. See [Dev-only scope and production firewall](./dev-only-scope.md).

## Contents

- **[Dev-only scope and production firewall](./dev-only-scope.md)** — This tooling is dev-only; production promotion is a separate process (to be defined)
- **[Schema ingestion](./schema-ingestion.md)** — How we pull and use the schema from Apollo Server
- **[Apollo MCP + Cursor](./apollo-mcp-cursor.md)** — Connect Apollo Server to Cursor via MCP so the AI can get the schema and run queries to determine synthetic data needs
- **[Configurable synthetic data](./configurable-synthetic-data.md)** — How required data is documented (by Cursor) and supplied by the user in one place, so the framework is environment-configurable and the suite can grow iteratively
- **[Queries as synthetic tests](./queries-as-synthetics.md)** — Implementing schema queries as synthetic tests (starting point)
- **[Mutations as workflows](./mutations-as-workflows.md)** — Multi-step workflows (create → modify → delete) to avoid polluting production

## Principles

- **Queries first**: Implement and validate query-based synthetics before tackling mutations.
- **Mutations as workflows**: Mutations are exercised in self-contained, multi-step flows that clean up after themselves.
- **Production-safe**: Tests run in prod-like settings without leaving synthetic data behind.
