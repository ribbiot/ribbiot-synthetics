#!/usr/bin/env npx tsx
/**
 * Fetches an Auth0 access token using the same password grant as our dev synthetics
 * (environments/dev/graphql.tf). DEV ONLY — do not use for production. See docs/dev-only-scope.md.
 *
 * Requires (e.g. from .env): TF_VAR_dev_username, TF_VAR_dev_password, TF_VAR_dev_client_secret.
 * Use raw values in .env (no URL encoding); this script encodes them when building the form body.
 * Optional: TF_VAR_dev_auth0_domain or DEV_AUTH0_DOMAIN (default: devauth.ribbiot.com).
 *
 * Usage: dotenv -e .env -- npx tsx scripts/get-auth0-token.ts
 * Output: access_token only to stdout (errors to stderr, exit non-zero on failure).
 */

const AUTH0_CLIENT_ID = "1jA5AOlVzwDksR9YXX7u71tVVWa2tDFo";
const AUTH0_AUDIENCE = "https://v656y9o6s7.execute-api.us-east-1.amazonaws.com/dev";
const AUTH0_REDIRECT_URI = "https://google.com";
const AUTH0_SCOPE =
  "general:tracker mobileassets:user mobilehome:user mobile:provisioning mobile:user mobile:vtrackers ribbiot:admin timecard:admin timecard:user web:assetcrud web:assetmap web:invoice web:quoting web:schedule web:settings web:usercrud";

async function main(): Promise<void> {
  const domain =
    process.env.DEV_AUTH0_DOMAIN ??
    process.env.TF_VAR_dev_auth0_domain ??
    "devauth.ribbiot.com";
  const username = process.env.TF_VAR_dev_username ?? process.env.DEV_USERNAME;
  const password = process.env.TF_VAR_dev_password ?? process.env.DEV_PASSWORD;
  const clientSecret = process.env.TF_VAR_dev_client_secret ?? process.env.DEV_CLIENT_SECRET;

  if (!username || !password || !clientSecret) {
    console.error(
      "Missing Auth0 credentials. Set in .env: TF_VAR_dev_username, TF_VAR_dev_password, TF_VAR_dev_client_secret (see .env.example)"
    );
    process.exit(1);
  }

  const url = `https://${domain}/oauth/token`;
  const body = new URLSearchParams({
    username,
    password,
    client_id: AUTH0_CLIENT_ID,
    client_secret: clientSecret,
    grant_type: "password",
    audience: AUTH0_AUDIENCE,
    redirect_uri: AUTH0_REDIRECT_URI,
    scope: AUTH0_SCOPE,
  }).toString();

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const data = (await res.json()) as { access_token?: string; error?: string; error_description?: string };
  if (!res.ok || !data.access_token) {
    console.error("Auth0 token request failed:", data.error ?? res.status, data.error_description ?? await res.text());
    process.exit(1);
  }

  process.stdout.write(data.access_token);
}

main();
