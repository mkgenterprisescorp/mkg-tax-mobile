# Vercel Flutter Web Deploy

This document describes how the **taxpayer-facing Flutter web UI** is built and
deployed to **Vercel**, and how it fits into the wider MKG Tax architecture.

Vercel hosts **only** the static Flutter web frontend. The federal tax engine,
state engines, IRS MeF integration, audit/authorization, tax records, and the
legacy iOS/Android deploys stay on their existing hosts. Vercel is used purely
to accelerate the web interface and its preview workflow.

## Target architecture

```text
Vercel
└── Taxpayer-facing Flutter Web UI (this repo, build/web → prebuilt static)

DigitalOcean App Platform
└── Laravel API
    ├── Federal tax engine
    ├── Region 1 state engine
    ├── Region 2 state engine
    ├── California tax adapters
    ├── IRS MeF integration
    └── Audit and authorization

GitHub Actions
├── Web validation + Vercel deploy (this workflow)
├── Backend deployment
├── Android deployment
└── Legacy iOS build and migration

Neon
└── Authoritative PostgreSQL database
```

The Flutter web app calls the Laravel API, e.g.:

- `POST {API_BASE_URL}/federal-tax/evaluate`
- `POST {API_BASE_URL}/state-tax/evaluate`
- `POST {API_BASE_URL}/regions/1/estimate`
- `POST {API_BASE_URL}/regions/2/estimate`

Flutter never talks to Neon/Postgres directly — all data flows through the
Laravel API. See `docs/mobile/security-model.md`.

## Why prebuilt (GitHub Actions builds, Vercel serves)

Vercel does **not** ship a Flutter framework preset, so we do not let Vercel
run the build. Instead:

1. GitHub Actions installs Flutter, runs `flutter analyze` + `flutter test`,
   and runs `flutter build web --release`.
2. CI assembles the [Vercel Build Output API v3](https://vercel.com/docs/build-output-api/v3)
   layout: `build/web` → `.vercel/output/static`, and
   `deploy/vercel/config.json` → `.vercel/output/config.json`.
3. CI runs `vercel deploy --prebuilt`, which uploads the artifact without any
   Vercel-side build step.

Workflow (ships as an example — see install note below):
[`docs/vercel-web-deploy.workflow.yml.example`](vercel-web-deploy.workflow.yml.example)
Routing/headers source of truth: [`deploy/vercel/config.json`](../deploy/vercel/config.json)

> **Install the workflow:** copy the example to
> `.github/workflows/vercel-web-deploy.yml` and commit it with a
> `workflow`-scoped token (or via the GitHub UI). The example lives under
> `docs/` because the automation token used here lacks the GitHub `workflow`
> scope required to push files under `.github/workflows/` — the same reason
> `docs/staging-web.workflow.yml.example` exists.

`config.json` provides SPA fallback so `go_router` deep links resolve to
`index.html`, long-cache headers for hashed assets, and `no-store` for
`index.html`/service worker so clients always pick up new deploys.

## Triggers & preventing unrelated deployments

The workflow is **path-filtered** so unrelated changes never redeploy the web
frontend. It runs only when web-affecting files change:

```yaml
paths:
  - "lib/**"        # shared Flutter/Dart code
  - "web/**"        # Flutter web platform files
  - "assets/**"     # bundled assets
  - "pubspec.yaml"
  - "pubspec.lock"
  - "deploy/vercel/**"
  - ".github/workflows/vercel-web-deploy.yml"
```

Deliberately excluded: `ios/**`, `android/**`, backend/tax-engine changes, and
docs. A change to the federal engine or the legacy iOS app does **not** trigger
a web redeploy. (Note: the original recommendation listed `ios/**` as a trigger;
that is intentionally omitted here because the same recommendation requires that
legacy-iOS changes must not redeploy the web frontend. iOS builds have their own
workflow.)

Deploy targets:

- **Pull request** → Vercel **preview** deployment (`vercel deploy --prebuilt`).
- **Push to `main`** → Vercel **production** deployment (`--prod`).
- **Manual** (`workflow_dispatch`) → preview off non-`main`, production off `main`.

## Configuration

### Public build variables (not secrets)

Set as GitHub Actions **Variables** (Settings → Secrets and variables → Actions
→ Variables). They are baked into the build via `--dart-define` and default to
the values below if unset:

| Variable | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `https://api.finance.mkgtaxconsultants.com/api/v1` | Laravel API root (must end with `/api/v1`, https). Validated by `AppConfig.validate()`. |
| `LARAVEL_API_BASE_URL` | `https://api.finance.mkgtaxconsultants.com` | Laravel origin without `/api/v1`. |
| `WEB_BASE_URL` | `https://finance.mkgtaxconsultants.com` | Portal deep links only. |

Never put Neon URLs, database credentials, or portal S2S secrets in these
values or anywhere in the client build.

### Deploy secrets

Set as GitHub Actions **Secrets**:

| Secret | Where to find it |
|---|---|
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens |
| `VERCEL_ORG_ID` | Vercel project `.vercel/project.json` after `vercel link`, or team settings |
| `VERCEL_PROJECT_ID` | Same as above |

The Vercel CLI reads `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` from the environment,
so no `vercel link` step is needed in CI.

## Alternative: Vercel Git integration + ignored build step

If you connect the repo to Vercel directly (instead of deploying from GitHub
Actions), Vercel still cannot build Flutter with a native preset. You would
need a custom `installCommand` that downloads the Flutter SDK and a
`buildCommand` of `flutter build web ...`, plus an **Ignored Build Step** so
Vercel skips builds when web files are unaffected, e.g.:

```bash
# Deploy only when web-affecting files changed since the previous commit.
git diff --quiet HEAD^ HEAD -- lib web assets pubspec.yaml pubspec.lock && exit 0 || exit 1
```

The GitHub Actions prebuilt path above is preferred: it reuses the same pinned
Flutter toolchain as the APK/DO builds, runs tests before deploying, and keeps
the Flutter build off Vercel's build container.

## Local dry run

```bash
flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.finance.mkgtaxconsultants.com/api/v1 \
  --dart-define=LARAVEL_API_BASE_URL=https://api.finance.mkgtaxconsultants.com \
  --dart-define=WEB_BASE_URL=https://finance.mkgtaxconsultants.com

# Assemble the prebuilt output exactly as CI does:
rm -rf .vercel/output && mkdir -p .vercel/output/static
cp -r build/web/. .vercel/output/static/
cp deploy/vercel/config.json .vercel/output/config.json

# With VERCEL_TOKEN/ORG/PROJECT set, deploy a preview:
vercel deploy --prebuilt --token="$VERCEL_TOKEN"
```
