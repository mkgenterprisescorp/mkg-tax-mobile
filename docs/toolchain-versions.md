# Toolchain Versions (Windows Dev Setup)

This document records the exact toolchain versions used to build and validate
the MKG Tax mobile app locally on Windows, and the staging backend endpoints
the app is configured against. It contains no secrets — only version numbers
and public URLs.

## SDKs

| Component | Version | Notes |
|---|---|---|
| Flutter | 3.44.6 (stable) | Installed to `C:\src\flutter` (outside OneDrive/git) |
| Dart | 3.12.2 | Bundled with Flutter 3.44.6 |
| JDK | 17 (Eclipse Temurin, OpenJDK 17.0.19+10) | Installed to `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` |
| Android SDK Platform | 36 | Installed via `sdkmanager` to `C:\Android\Sdk` |
| Android Build-Tools | 36.0.0 | Installed via `sdkmanager` to `C:\Android\Sdk` |
| Android Platform-Tools | latest | Installed via `sdkmanager` to `C:\Android\Sdk` |

Run `flutter doctor -v` locally to reconfirm the exact Dart version bundled
with the installed Flutter SDK, since patch versions can shift between
Flutter releases.

## Staging Backend

| Purpose | Value |
|---|---|
| Primary staging domain | `https://app.mkgtaxconsultants.com` |
| API base URL | `https://app.mkgtaxconsultants.com/api/v1` |
| Temporary fallback (DigitalOcean generated URL) | `https://mkg-tax-backend-2-staging-56eon.ondigitalocean.app` |
| DigitalOcean app | `mkg-tax-backend-2-staging` |
| Health check | `GET /api/v1/health` → `200 OK` |

The custom domain `app.mkgtaxconsultants.com` is attached only to
`mkg-tax-backend-2-staging` and is owner-approved for staging use. The
fallback `*.ondigitalocean.app` URL is retained only as a backup reference;
prefer the custom domain for all staging builds and documentation.

## Secrets Policy

No secrets, API keys, database URLs, or credentials are configured at
compile time for this app. The staging API base URL above is a public
staging endpoint, not a secret, and is safe to bake into `--dart-define`
build flags and CI workflow files. Production signing keys, keystores, and
any `.env` files are excluded from git via `.gitignore` and must never be
committed.
