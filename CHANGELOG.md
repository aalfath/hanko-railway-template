# Changelog

## 3.2.0 (2026-11-23)

- Breaking change upstream, only if you configured third-party sign-in yourself: a standalone `*` in `allowed_redirect_urls` is now rejected. Replace it with the redirect URLs your app needs before you apply this update. The template doesn't set third-party sign-in, so a default deploy is not affected.
- Security release: fixes six advisories in SAML (cross-tenant identity deletion, redirect allowlist wildcard, nonce and assertion replay, disabled IdP) and TOTP code reuse. No new variables. See the [v3.2.0 release notes](https://github.com/teamhanko/hanko/releases/tag/backend%2Fv3.2.0).
- Hanko v3.1.0 → **v3.2.0** (`ghcr.io/teamhanko/hanko:v3.2.0@sha256:1ead75c1938c28458b669e1dd9976595e6437d9bc643057f59c5d3c71b4441f6`); demo page uses Hanko Elements 3.2.0.
- Tested on Railway before merging: the published template was deployed, data was written, the service was switched to this version, and the data and login were still there.

## 3.1.0-1 (2026-11-16)

- README: Deploy on Railway button for the published template `hanko-1`. No change to the deployed service.

## 3.1.0 (2026-11-16)

- First release: Hanko `v3.1.0` (`ghcr.io/teamhanko/hanko:v3.1.0@sha256:80ea5d67937cb3674bdde157365c57ff04420d5337f1277232d47e858613b19c`), Caddy `2.11.9`, Railway Postgres.
- Demo page at `/demo/` using Hanko Elements `3.1.0`.
- Email delivery is off until `SMTP_HOST` is set.
