# User Management Service — Schema reference for synthetic test config

This doc summarizes the **synthetic test config schema** and **GraphQL schema** for the User Management Service so you can create and maintain `synthetic-test-config/graphql/<env>/user-service.yaml`.

## 1. Synthetic test config (YAML) schema

Config files live at:

- **Dev:** `synthetic-test-config/graphql/dev/user-service.yaml`
- **Prod:** `synthetic-test-config/graphql/prod/user-service.yaml`

Full YAML shape is in [synthetic-test-config-schema.md](./synthetic-test-config-schema.md). For User Management Service use:

| Key | Value for User Service |
|-----|------------------------|
| `scope` | `graphql` |
| `environment` | `dev` or `prod` (must match folder) |
| `service` | `User service` (or "User management service") |
| `graph` | `Dev-UserService` (dev) or `Prod-UserService` (prod) |
| `terraform_file` | `environments/dev/graphql_user_service.tf` or `environments/prod/graphql_user_service.tf` |
| `queries` | List of query entries (see below) |

### Query entry (per query)

| Key | Required | Description |
|-----|----------|-------------|
| `name` | Yes | GraphQL query name (e.g. `userSystemCheck`, `publicUserServiceSettings`) |
| `excluded` | No | `true` = do not create a Datadog test for this query. Default `false`. |
| `synthetic_data` | No | List of `{ key, value?, purpose?, where_to_set?, format? }` for variables (e.g. none for `userSystemCheck`) |
| `notes` | No | Free-form notes |
| `locations` | No | e.g. `["aws:us-east-1", "aws:us-west-2", "gcp:us-west1"]`; omit to use env default |
| `assertions` | No | List of `{ jsonpath, operator, targetvalue }` for response validation |

### Assertion shape

| Key | Description |
|-----|-------------|
| `jsonpath` | e.g. `$.data.userSystemCheck.message` |
| `operator` | Usually `is`; also `contains`, `matches` |
| `targetvalue` | Expected string/number |

---

## 2. User Service GraphQL schema (relevant parts)

From the federated graph (Dev-UserService / Prod-UserService). Types and queries you can add synthetics for:

### Input

```graphql
input SystemCheckInput {
  checkLaunchDarkly: Boolean = false
  checkSQL: Boolean = false
}
```

### Types

```graphql
type GqlUserSystemCheck {
  message: String!
  environment: JSON!
  featureFlags: JSON
  launchDarklyStatus: String
  sqlStatus: String
  minimumAndroidVersion: String
  minimumIOSVersion: String
}

type PublicUserServiceSettings {
  minimumAndroidVersion: String
  minimumIOSVersion: String
}
```

### Queries (User Service)

| Query | Input | Description |
|-------|--------|-------------|
| `userSystemCheck(input: SystemCheckInput)` | Optional `{ checkLaunchDarkly, checkSQL }` | Health check; returns `GqlUserSystemCheck`. No synthetic_data needed if using default input. |
| `publicUserServiceSettings` | None | Public settings (min app versions). No auth/synthetic_data. |

---

## 3. Example: `userSystemCheck` in config

```yaml
queries:
  - name: userSystemCheck
    synthetic_data: []
    notes: Health check; optional input checkLaunchDarkly, checkSQL.
    locations:
      - aws:us-east-1
      - aws:us-west-2
      - gcp:us-west1
    assertions:
      - jsonpath: "$.data.userSystemCheck.message"
        operator: is
        targetvalue: "User Service is Running!"
      - jsonpath: "$.data.userSystemCheck.launchDarklyStatus"
        operator: is
        targetvalue: "OK"
      - jsonpath: "$.data.userSystemCheck.sqlStatus"
        operator: is
        targetvalue: "OK"
      # optional: minimumAndroidVersion, minimumIOSVersion (env-specific)
```

---

## 4. Adding more queries

1. **Get a working request + response** from dev (or prod) for the new query.
2. **synthetic_data:** From the request variables, add one `synthetic_data` item per variable (key = global name, e.g. `DEV_*`, value, purpose, where_to_set, format).
3. **assertions:** Run `npx tsx scripts/derive-assertions-from-response.ts response.json --query <queryName>` and paste the YAML into the query entry, or add assertions manually for important fields.
4. **Run:** `npm run tfvars:from-synthetic-test-config` → `npm run tf:plan:dev` → `npm run tf:apply:dev` (and add the new test in `graphql_user_service.tf` if it’s a new query).

---

## 5. Apollo schema source

- **Dev User Service:** [Apollo Studio – Dev-UserService](https://studio.apollographql.com/graph/Ribbiot-Serverless/variant/dev-current/schema/sdl?selectedSchema=Dev-UserService)
- **Config:** `config/schema-options.json` lists `Dev-UserService` and `Dev-UserService-Public`; use `npm run mcp:select-schema` to pick the User Service schema when working with MCP.
