# Troubleshooting

## 403 Forbidden from Datadog provider

A **403 Forbidden** when running `terraform plan` or `terraform apply` almost always means one of:

### 1. Wrong Datadog site

Your API and App keys are tied to a specific Datadog site. Use the matching API URL:

- **US5** (e.g. `us5.datadoghq.com`): `https://api.us5.datadoghq.com` — default in this repo
- **US1:** `https://api.datadoghq.com`
- **EU:** `https://api.datadoghq.eu`

**Fix:** Set the API URL before running Terraform (or rely on the default in `environments/dev` for US5).

In `.env` (and `set -a && source .env && set +a` before Terraform):

```bash
DD_API_URL=https://api.us5.datadoghq.com
```

Or in `terraform.tfvars` or when prompted: `dd_api_url = "https://api.us5.datadoghq.com"`.

### 2. Invalid or swapped keys

- Confirm the **API key** and **Application key** in [Organization Settings → API Keys / Application Keys](https://app.datadoghq.com/organization-settings/api-keys) (or the EU equivalent).
- Don’t swap them: **API key** → `dd_api_key` / `DD_API_KEY`, **Application key** → `dd_app_key` / `DD_APP_KEY`.

### 3. Application key scope

The **Application key** must have at least **Synthetics** read/write (or a broader scope). Create a new key with the right scopes and use that.

---

After changing `.env` or tfvars, reload the environment (e.g. `set -a && source .env && set +a`) and run `terraform plan` again from `environments/dev` (or the env you use).
