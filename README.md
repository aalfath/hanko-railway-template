# Hanko on Railway

Railway template for [Hanko](https://github.com/teamhanko/hanko), the open-source, passkey-first authentication and user management API.

It deploys:

- **Hanko** `v3.1.0` (`ghcr.io/teamhanko/hanko:v3.1.0`, pinned by digest in the `Dockerfile`), built from this repo, with:
  - `start.sh`: writes Hanko's `config.yaml` from the Railway variables, runs the database migrations, then starts Hanko.
  - Caddy (`caddy:2.11.9`), which serves Hanko's public API and a small demo page (`/demo/`) on the public domain.
  - Hanko's admin API on port `8001`, reachable only over Railway's private network (`http://hanko.railway.internal:8001`). It has no authentication of its own, so it is never exposed publicly.
- **Postgres** (Railway's own), which holds all of Hanko's data: users, credentials, sessions and the encrypted signing keys.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | URL of the app that embeds Hanko Elements. It is allowed for CORS and passkeys, and its host is the passkey relying party ID. The default is Hanko's own domain, where the demo page runs. |
| `SECRET_KEY` | `${{secret(32)}}` | Encrypts the keys Hanko signs session tokens with. Don't change it after the first deploy. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Postgres connection. |
| `PORT` | `8080` | Port Caddy listens on (the public domain targets it). |

Optional, add them on the service when you need them:

| Variable | What it does |
|---|---|
| `RP_ID` | Passkey relying party ID, if it should differ from `APP_URL`'s host (for example `example.com` for `app.example.com`). |
| `ALLOWED_ORIGINS` | Extra origins (comma-separated) allowed for CORS and passkeys. |
| `SMTP_HOST`, `SMTP_PORT` (587), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` | Turns on email: verification passcodes, passcode login, password recovery and security notifications. Without `SMTP_HOST`, users sign up with email + password and passkeys, and email addresses are not verified. |
| `SERVICE_NAME` | Name shown in emails and passkey prompts (default `Hanko`). |
| `DEMO_PAGE` | `false` turns off the demo page. |

Any other Hanko setting can be set with Hanko's own environment variables, which override the generated file, for example `ACCOUNT_ALLOW_SIGNUP=false` or `PASSWORD_ENABLED=false`. See the [configuration reference](https://github.com/teamhanko/hanko/wiki/config).

## Use it in your app

```js
import { register } from "@teamhanko/hanko-elements";
const { hanko } = await register("https://your-hanko.up.railway.app");
```

Then put `<hanko-auth></hanko-auth>` on your login page and `<hanko-profile></hanko-profile>` on the account page. Verify the session JWT in your backend with the JWKS at `https://your-hanko.up.railway.app/.well-known/jwks.json`. Set `APP_URL` to your app's URL first.

## Updates

This template builds from this repo's `main` branch. When a new Hanko release is pinned here, Railway shows an "update available" notice on your project; read `CHANGELOG.md` before you apply it. Migrations run on every start.
