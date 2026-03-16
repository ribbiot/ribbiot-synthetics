# Required synthetic data

This doc summarizes **where** we document required synthetic test config (data, locations, assertions). The canonical list is in **[synthetic-test-config/](../synthetic-test-config/)**. GraphQL tests use **synthetic-test-config/graphql/<env>/** (one YAML per service per environment), with per-query synthetic_data, implemented, locations, and assertions.

- **synthetic-test-config/README.md** — Purpose, layout (graphql scope), and how to derive assertions from a response.
- **synthetic-test-config/graphql/dev/asset-service.yaml** — Asset service (dev): queries, synthetic_data, implemented, locations, assertions.
- **synthetic-test-config/graphql/prod/asset-service.yaml** — Asset service (prod): same structure, prod-specific values.
- **synthetic-test-config/graphql/dev/job-service.yaml** (and prod) — Job service (placeholder until populated).
- **synthetic-test-config/graphql/dev/user-service.yaml** (and prod) — User service (placeholder).
- **synthetic-test-config/graphql/dev/timecard-service.yaml** (and prod) — Timecard service (placeholder).
- **docs/synthetic-test-config-schema.md** — Full schema (scope, environments, assertions, derive script).

Supply values in the YAML files; run `npm run tfvars:from-synthetic-test-config` to inject them into Terraform. See [Configurable synthetic data](./configurable-synthetic-data.md).

When you add a new query or data requirement, update the service file in **synthetic-test-config/graphql/<env>/** and (if needed) Terraform.
