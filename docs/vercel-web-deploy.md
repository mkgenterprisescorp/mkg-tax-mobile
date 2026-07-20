# Vercel Flutter Web Deploy

This document describes how the **taxpayer-facing Flutter web UI** is built and
deployed to **Vercel**, and how it fits into the wider MKG Tax architecture.

Vercel hosts **only** the static Flutter web frontend. The federal tax engine,
state engines, IRS MeF integration, audit/authorization, tax records, and the
legacy iOS/Android deploys stay on their existing hosts. Vercel is used purely
to accelerate the web interface and its preview workflow.

## Important distinction: GitHub connection ≠ every file is a Vercel service

Connecting this GitHub repository to Vercel gives Vercel permission to **read**
the repository. That does **not** mean every file becomes a running Vercel
service.

What Vercel builds and publishes is controlled by the project settings:

| Setting | Value for this app | Effect |
|---|---|---|
| **Root Directory** | `.` (repo root) | Flutter needs `pubspec.yaml`, `lib/`, `web/`, and `assets/` together. Do **not** set Root Directory to `ios/` or `android/`. |
| **Build Command** | Prefer GitHub Actions + `vercel deploy --prebuilt` (see below). If using Vercel Git builds: custom Flutter install + `flutter build web --release …` | Only the web target is compiled. |
| **Output Directory** | `build/web` | Only the Flutter web static bundle is published. |
| **Ignore Build Step** | `bash deploy/vercel/ignore-build.sh` (also set via `ignoreCommand` in `vercel.json`) | Skips a deployment when no web-affecting files changed. |

Vercel supports selecting a project root directory and restricting deployments to
that application. In this repo the Flutter app *is* the repo root, so root is
`.`, and restriction comes from **Build Command + Output Directory + Ignore
Build Step** — not from moving `ios/` out of the tree.

### Legacy iOS app (`ios/`)

The legacy iOS runner remains in the repository for **maintenance and
migration**. It must **not** be part of the Vercel build:

| Path | In git? | Triggers Vercel deploy? | Published by Vercel? |
|---|---|---|---|
| `ios/` | Yes (maintenance / migration) | **No** | **No** |
| `android/` | Yes | **No** | **No** |
| `lib/`, `web/`, `assets/`, `pubspec.*` | Yes | **Yes** | Via `build/web` only |

Recommended ignore / exclude path for Vercel: **`ios/`** (plus `android/` and
other non-web trees — see `deploy/vercel/ignore-build.sh`).

Concrete controls:

1. **GitHub Actions path filter** (preferred deploy path) — workflow paths omit
   `ios/**` entirely.
2. **Vercel Ignored Build Step** — `deploy/vercel/ignore-build.sh` watches only
   web-affecting paths; a commit that only touches `ios/` exits `0` and skips
   the deployment.
3. **Output Directory = `build/web`** — even if the full repo is checked out,
   only the Flutter web artifact is published. Xcode projects under `ios/` are
   never compiled or served.

## Target architecture

```text
Vercel
└── Taxpayer-facing Flutter Web UI (this repo, build/web → prebuilt static)
    # ios/ stays in git for maintenance/migration — never built or published here

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
└── Legacy iOS build and migration   # owns ios/; not Vercel

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

Canonical files:

| File | Role |
|---|---|
| [`deploy/vercel/config.json`](../deploy/vercel/config.json) | Build Output API v3 routing/headers for `--prebuilt` deploys |
| [`vercel.json`](../vercel.json) | Project ignore-build + SPA rewrites/headers for Vercel Git / dashboard |
| [`deploy/vercel/ignore-build.sh`](../deploy/vercel/ignore-build.sh) | Ignored Build Step — skips when only non-web paths (e.g. `ios/`) change |

> **Install the workflow:** copy the example to
> `.github/workflows/vercel-web-deploy.yml` and commit it with a
> `workflow`-scoped token (or via the GitHub UI). The example lives under
> `docs/` because the automation token used here lacks the GitHub `workflow`
> scope required to push files under `.github/workflows/` — the same reason
> `docs/staging-web.workflow.yml.example` exists.

`config.json` / `vercel.json` provide SPA fallback so `go_router` deep links
resolve to `index.html`, long-cache headers for hashed assets, and `no-store`
for `index.html` so clients always pick up new deploys.

## Triggers & preventing unrelated deployments

Two layers keep unrelated changes (especially **`ios/`**) from redeploying the
web frontend:

### 1. GitHub Actions path filter (preferred)

```yaml
paths:
  - "lib/**"        # shared Flutter/Dart code
  - "web/**"        # Flutter web platform files
  - "assets/**"     # bundled assets
  - "pubspec.yaml"
  - "pubspec.lock"
  - "deploy/vercel/**"
  - "vercel.json"
  - ".github/workflows/vercel-web-deploy.yml"
```

Deliberately excluded: **`ios/**`**, `android/**`, backend/tax-engine changes,
and docs. A change to the federal engine or the legacy iOS app does **not**
trigger a web redeploy. (An earlier draft listed `ios/**` as a trigger; that
conflicts with “legacy iOS must not redeploy web,” so `ios/**` is omitted —
iOS has its own build/migration workflow.)

### 2. Vercel Ignored Build Step (Git integration / dashboard)

`deploy/vercel/ignore-build.sh` (wired via `vercel.json` → `ignoreCommand`)
exits `0` (skip) when none of the web-affecting paths changed since `HEAD^`.
Recommended path that must never count as a web change: **`ios/`**.

Deploy targets (Actions path):

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

### Vercel project settings checklist

When linking the GitHub repo in the Vercel dashboard:

1. **Root Directory** = `.` (repo root — not `ios/`).
2. **Framework Preset** = Other / None (Flutter is not a native preset).
3. **Output Directory** = `build/web`.
4. **Ignored Build Step** = `bash deploy/vercel/ignore-build.sh` (or rely on
   `ignoreCommand` in `vercel.json`).
5. Prefer deploying with GitHub Actions + `--prebuilt` so Vercel never needs a
   Flutter SDK install. If you do use Vercel Git builds, set a custom
   Install/Build command that downloads Flutter and runs
   `flutter build web --release` with the dart-defines above.

## Alternative: Vercel Git integration only

If you connect the repo to Vercel directly (instead of deploying from GitHub
Actions), Vercel still cannot build Flutter with a native preset. You would
need a custom `installCommand` that downloads the Flutter SDK and a
`buildCommand` of `flutter build web ...`, plus the **Ignored Build Step**
above so Vercel skips builds when only `ios/` (or other non-web paths) change.

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

# Exercise the ignore-build script (exit 0 = skip, 1 = build):
bash deploy/vercel/ignore-build.sh; echo "exit=$?"
```
