# Schema Ingestion from Apollo Server

## Goal

Establish a repeatable process for **ingesting the GraphQL schema** from our Apollo Server so we can drive synthetic test implementation from the actual API contract.

## Scope

- Source: our Apollo Server (schema endpoint or introspection).
- Output: a representation of the schema (e.g. SDL file, introspection JSON, or generated types) that we can use to:
  - Discover available **queries** and **mutations**
  - Know argument types and return shapes
  - Generate or guide the implementation of synthetic tests

## Process (to be defined)

1. **Obtain schema** — Introspect Apollo Server or fetch published schema (e.g. from schema registry or CI artifact). **Alternatively (or in addition):** use [Apollo MCP Server + Cursor](./apollo-mcp-cursor.md) so the IDE and AI can get the schema and run queries via MCP.
2. **Persist schema** — Store the schema in the repo or a known location (e.g. `schema.graphql`, `schema.json`, or under `docs/` / a dedicated `schema/` folder).
3. **Use schema for test design** — Use the schema to enumerate queries and mutations and to drive which synthetics we implement (queries first, then mutation workflows).

## Notes

- Schema ingestion should be part of the pipeline so synthetic tests stay aligned with the live API.
- Consider automation (e.g. script or CI job) that runs periodically or on release to refresh the schema.
