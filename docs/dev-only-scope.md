# Dev-only scope and production firewall

## Intent

All tooling and configuration added for **schema exploration, MCP, and synthetic test development** (Apollo MCP Server, Auth0 token scripts, Cursor integration, configurable synthetic data) are for the **dev environment only**.

- **No production use:** This setup must not be used to connect to or run against production GraphQL, Auth0, or production data.
- **Firewall between dev and prod:** There is a clear boundary: dev configuration and credentials stay in dev. Production has its own, separate configuration and promotion process.
- **Production promotion:** Promoting what we configure and validate in dev to production will be a **separate process**, defined later. This doc and the current codebase focus solely on dev.

## What is dev-only (current scope)

- **Apollo MCP Server** — Default endpoint and config point at the dev router (`ribbiot-router-dev`). Credentials (Auth0) are dev credentials. Do not point MCP or these scripts at production endpoints or production Auth0.
- **Auth0 token script** (`scripts/get-auth0-token.ts`, `mcp:start:auth`) — Uses the same dev Auth0 credentials as our dev synthetics. Not for production.
- **Configurable synthetic data** — Required-data spec and configured data store are currently for dev; production values and promotion are out of scope until we define the promotion process.
- **Docs in this folder** — Schema ingestion, Apollo MCP + Cursor, queries-as-synthetics, mutations-as-workflows, and configurable synthetic data are written with dev in mind. Production will be addressed when we add the promotion process.

## What we are not doing yet

- Defining how to promote dev synthetic tests or config to production.
- Supporting production GraphQL endpoints, production Auth0, or production synthetic data in this tooling.
- Allowing the same scripts/config to target production by flipping an env var (by design; production will be a separate path).

## If you need production

Use the production synthetic tests and configuration that already exist (e.g. Terraform in `environments/prod`) and your existing release/promotion workflow. The new MCP and dev-focused workflow does not replace or touch that.
