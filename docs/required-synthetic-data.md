# Required synthetic data

This doc summarizes **where** we document required synthetic data. The canonical per-service list is in the **[synthetic-data](../synthetic-data/)** folder: one YAML file per service graph, with each query and the synthetic data it uses.

- **synthetic-data/README.md** — Purpose of the folder and file format.
- **synthetic-data/asset-service.yaml** — Asset inventory service: all queries (implemented and not) and their data keys, purpose, where to set, format.
- **synthetic-data/job-service.yaml** — Job service (placeholder until queries are added).
- **synthetic-data/user-service.yaml** — User service (placeholder).
- **synthetic-data/timecard-service.yaml** — Timecard service (placeholder).

Supply values in the configured store (e.g. Terraform variables, Datadog global variables, or a config file). See [Configurable synthetic data](./configurable-synthetic-data.md).

When you add a new query synthetic or a new data requirement, update the corresponding service file in **synthetic-data/** and (if needed) the Terraform variable / global variable in the environment.
