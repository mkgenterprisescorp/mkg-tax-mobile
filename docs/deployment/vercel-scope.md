# Vercel deployment scope — MKG Tax client web

**Vercel project name:** `mkg-tax-mobile` (alias target; docs historically said `mkg-tax-client-web`)  
**GitHub:** `mkgenterprisescorp/mkg-tax-mobile`  
**Production branch:** `main`  
**Vercel team:** `mkgtaxconsultants` (`team_5uxQCVdAhb1FImpmmkm9rAa5` → set as `VERCEL_ORG_ID`)  
**Production alias:** `https://mkg-tax-mobile.vercel.app`

Vercel deploys **only** the taxpayer-facing web frontend. It must not deploy,
execute, expose, or directly modify federal/state tax engines, Laravel, IRS MeF,
native iOS/Android, Neon migrations, document storage, or production credentials.

## Detected reality (this repository)

| Item | Finding |
|---|---|
| Web framework | **Flutter Web** (not Vite/React, not Next.js) |
| Web root today | **Repository root** (`.`) — `pubspec.yaml` + `lib/` + `web/` + `assets/` |
| Preferred long-term root | `apps/web` (not present yet — see [monorepo-migration-plan.md](monorepo-migration-plan.md)) |
| Tax engines in this repo | **None** — live under Laravel (`mkg-tax-backend` / `mkg-tax-backend-2`) on DigitalOcean |
| Database migrations | **Not in this repo** — Neon via Laravel CI/CD |
| Documents | DigitalOcean Spaces (metadata via Laravel) |

**Do not move files solely to match `apps/web`.** Configure Vercel against the
actual Flutter root until a deliberate monorepo migration is approved.

## Deployment model

```text
GitHub: mkgenterprisescorp/mkg-tax-mobile
├── Flutter web frontend (lib/, web/, assets/)  →  Vercel (mkg-tax-mobile, prebuilt only)
├── Flutter/native mobile (ios/, android/)      →  separate CI (outside Vercel)
├── (future) federal / state engines            →  Laravel on DigitalOcean
├── (future) database migrations                →  Neon via backend CI/CD
└── documents                                   →  DigitalOcean Spaces

Browser
  → Vercel web frontend (HTTPS)
  → Laravel API on DigitalOcean (HTTPS)
  → Federal and state tax engines
  → Neon PostgreSQL
```

Flutter never connects to Neon. Do **not** install the Neon–Vercel integration
for this frontend project.

### Stable deploy steps (required)

1. Set secrets (Cursor Cloud / GitHub Actions): `VERCEL_TOKEN`, `VERCEL_ORG_ID`,
   `VERCEL_PROJECT_ID`. Org ID value: `team_5uxQCVdAhb1FImpmmkm9rAa5`
   (also committed in `deploy/vercel/project.json`).
2. Disable Vercel Git auto-deploy (`gitProviderOptions.createDeployments=disabled`)
   — already applied on the live project; `scripts/vercel-ignore-build.sh` always
   skips as belt-and-suspenders.
3. Build + deploy + smoke:

```bash
export VERCEL_TOKEN=…          # required
export VERCEL_ORG_ID=team_5uxQCVdAhb1FImpmmkm9rAa5
export VERCEL_PROJECT_ID=…     # or rely on deploy/vercel/project.json
bash scripts/deploy-vercel-web.sh           # prod + smoke
bash scripts/deploy-vercel-web.sh --preview # preview
bash scripts/smoke-vercel-web.sh            # re-check production alias
```

## Important distinction

Connecting GitHub to Vercel grants **read** access. That does **not** make every
file a running Vercel service. Scope is enforced by:

| Setting | Current Flutter value |
|---|---|
| Root Directory | `.` (repo root — **not** `ios/`) |
| Framework preset | Other |
| Build / deploy | **`scripts/deploy-vercel-web.sh` or GitHub Actions + `vercel deploy --prebuilt` only**. `scripts/build-vercel-web.sh` is a gated fallback (`ALLOW_VERCEL_NATIVE_FLUTTER_BUILD=1`) — Vercel Git must not cold-build Flutter (auto-deploy disabled). |
| Output Directory | `build/web` |
| Ignore Build Step | `bash scripts/vercel-ignore-build.sh` |

### Automatic deploy path (required)

1. Install workflow from `docs/deployment/vercel-web-deploy.workflow.yml.example`
   → `.github/workflows/vercel-web-deploy.yml`.
2. CI runs `flutter analyze` / `test` / `build web`, assembles `.vercel/output`,
   then `vercel deploy --prebuilt` (preview on PR, `--prod` on `main`).
3. Leave Vercel Git “Build” disabled or accept that `buildCommand` fails closed
   unless the gated fallback flag is set after Flutter is installed.

## DNS / API host verification (2026-07-20)

| Host | DNS | Notes |
|---|---|---|
| `app.mkgtaxconsultants.com` | **Live** | `GET /api/v1/health` → 200 (`mkg-tax-backend-2`) — **use for Preview** |
| `api.finance.mkgtaxconsultants.com` | **No DNS** | Intended production API — **do not wire until it resolves** |
| `staging-api.finance.mkgtaxconsultants.com` | **No DNS** | Intended dedicated preview API — **do not wire** |
| `finance.mkgtaxconsultants.com` | **No DNS** (from this agent) | Marketing host — use portal/marketing hosts that resolve |

Do **not** set Preview env vars to non-resolving `*.finance.mkgtaxconsultants.com`
API hosts. That would break every preview deployment.

## In scope for Vercel

- `lib/**` (shared Dart UI — browser-safe only)
- `web/**`
- `assets/**`
- `pubspec.yaml` / `pubspec.lock`
- `vercel.json`
- `deploy/vercel/**`
- `scripts/build-vercel-web.sh` / `scripts/vercel-ignore-build.sh`

## Out of scope (must not be built, packaged, or executed by Vercel)

| Path / system | Notes |
|---|---|
| `ios/**` | Legacy iOS — maintenance/migration only |
| `android/**` | Android runner — separate Flutter mobile CI |
| `apps/mobile/**`, `apps/legacy-ios/**` | Preferred layout (future) |
| `backend/**`, `services/tax-api/**` | Laravel — DigitalOcean |
| `tax-engines/**` | Federal / state / CA 540 / business — server-side only |
| `database/**` | Neon migrations — backend CI only |
| `storage/**`, `certificates/**`, `private/**`, `secrets/**` | Never in browser |
| `infrastructure/**` | Outside Vercel |
| Neon credentials, MeF keys, encryption keys | Prohibited on Vercel |

Recommended exclude path called out for legacy mobile: **`ios/`**.

## Public environment (browser / dart-define)

Flutter compiles public config via `--dart-define` (equivalent intent to
`VITE_*` / `NEXT_PUBLIC_*`). These values **become part of the browser bundle**.

| Dart-define | Production (when DNS live) | Preview (verified now) | Development |
|---|---|---|---|
| `API_BASE_URL` | `https://api.finance.mkgtaxconsultants.com/api/v1` *(pending DNS)* | `https://app.mkgtaxconsultants.com/api/v1` | `http://localhost:8000/api/v1` (+ `ALLOW_INSECURE_LOCAL_DEV=true`) |
| `LARAVEL_API_BASE_URL` | `https://api.finance.mkgtaxconsultants.com` *(pending)* | `https://app.mkgtaxconsultants.com` | `http://localhost:8000` |
| `WEB_BASE_URL` | `https://finance.mkgtaxconsultants.com` | same | local as needed |
| `APP_NAME` | `MKG Tax Consultants` | same | same |
| `APP_ENV` | `production` | `preview` | `development` |

Until `api.finance.mkgtaxconsultants.com` resolves, production builds that must
ship should also target the verified Laravel host (`app.mkgtaxconsultants.com`)
or wait on DNS. Never point preview at production IRS MeF or a production-only
DB. Never wire Preview to `staging-api.finance…` while it has no DNS.

Vite/Next `VITE_*` / `NEXT_PUBLIC_*` names apply only after a monorepo migration
to a JS web app under `apps/web`. They are **not** used by the current Flutter
web target. Never put secrets in any public prefix (`VITE_`, `NEXT_PUBLIC_`, or
Flutter dart-defines).

## Prohibited Vercel environment variables

Never set on the `mkg-tax-client-web` project:

`DATABASE_URL`, `NEON_DATABASE_URL`, `PGHOST`, `PGUSER`, `PGPASSWORD`,
`PGDATABASE`, `IRS_MEF_PRIVATE_KEY`, `IRS_MEF_CERTIFICATE`,
`IRS_MEF_CERTIFICATE_PASSWORD`, `SSN_ENCRYPTION_KEY`,
`TAXPAYER_ENCRYPTION_KEY`, `APP_KEY`, `JWT_PRIVATE_KEY`,
`DIGITALOCEAN_ACCESS_TOKEN`, `AWS_SECRET_ACCESS_KEY`, `STRIPE_SECRET_KEY`,
`SENDGRID_API_KEY`.

Do not enable Neon→Vercel `DATABASE_URL` injection for this frontend project.

## Tax-engine scope (frontend)

**May:** collect validated questionnaire inputs; call backend estimate endpoints;
display calculation results/explanations/forms returned by the API; show filing
status and workflow progress.

**Must not:** calculate authoritative federal/state liability in Dart/TS;
duplicate Laravel tax rules; determine credit eligibility independently;
directly update filed-return records; invoke IRS MeF; sign returns; access
EFIN/ERO credentials; create authoritative audit records client-side.

Approved API examples (Laravel remains source of truth):

- `POST /api/v1/tax-years/{taxYear}/federal/estimate`
- `POST /api/v1/tax-years/{taxYear}/states/{stateCode}/estimate`
- `POST /api/v1/tax-years/{taxYear}/business/{entityType}/estimate`
- `GET  /api/v1/returns/{returnId}`
- `GET  /api/v1/returns/{returnId}/calculation-trace`
- `POST /api/v1/returns/{returnId}/validate`

UI-only math (currency formatting, progress %, preliminary display estimates
clearly marked) is allowed. Laravel responses remain authoritative.

## Legacy iOS / Android / Flutter mobile

- **iOS:** remains in GitHub (`ios/`); outside Vercel. Separate workflow
  example: `docs/deployment/legacy-ios-build.workflow.yml.example` (install as
  `.github/workflows/legacy-ios-build.yml`). No Xcode/IPA/signing/TestFlight on
  Vercel. Apple credentials only in the approved iOS CI store.
- **Android / Flutter mobile:** `flutter analyze` / `test` / `appbundle` /
  `ipa` stay in mobile CI. Vercel may host Flutter **Web** only; it is not the
  mobile-app build service.

## Deployment triggers

- Production: `main`
- Preview: pull-request branches
- Skip when changes are limited to: `ios/**`, `android/**`, `apps/legacy-ios/**`,
  `services/tax-api/**`, `tax-engines/**`, `database/**`, `docs/**`,
  `archive/**`, `legacy/**`, `experimental/**`, etc.

Enforced by Actions path filters + `scripts/vercel-ignore-build.sh`.

## API / CORS (Laravel — not configured in this frontend)

Recommended allowlist origins:

- `https://finance.mkgtaxconsultants.com`
- `https://www.finance.mkgtaxconsultants.com`
- `https://mkg-tax-mobile.vercel.app`

Preview URLs must not automatically receive production API access — use staging
API, Vercel Deployment Protection, and/or an explicit preview-origin allowlist.
Never `Access-Control-Allow-Origin: *` on authenticated taxpayer endpoints.

## Source maps / logging

No taxpayer PII in browser logs, Vercel logs, analytics, exceptions, or source
maps (SSN, ITIN, DOB, bank numbers, transcripts, W-2/1099 identity values,
IRS PIN, identity documents, MeF payloads). Production source maps disabled or
uploaded privately to an approved error platform.

## Verification

```bash
bash scripts/verify-vercel-scope.sh .
bash scripts/vercel-ignore-build.sh; echo "exit=$?"   # 0=skip 1=build
```

CI: `docs/deployment/web-ci.workflow.yml.example` (Flutter analyze/test +
scope verification). Copy to `.github/workflows/web-ci.yml` with a
`workflow`-scoped token (same convention as other workflow examples in this
repo). Legacy iOS: `docs/deployment/legacy-ios-build.workflow.yml.example`
→ `.github/workflows/legacy-ios-build.yml`.

## Manual dashboard / secrets steps

1. Vercel project **`mkg-tax-mobile`** under team **`mkgtaxconsultants`** (live).
2. Connect GitHub App to **only** `mkgenterprisescorp/mkg-tax-mobile` (selected repos).
3. Root Directory `.`, Framework Other, Output `build/web`, Ignore Build Step
   `bash scripts/vercel-ignore-build.sh`.
4. **Disable Vercel Git auto-deploy** (`createDeployments=disabled`). Deploy only
   via `scripts/deploy-vercel-web.sh` / Actions `--prebuilt`.
5. Set Cursor Cloud + Actions secrets:
   - `VERCEL_TOKEN`
   - `VERCEL_ORG_ID=team_5uxQCVdAhb1FImpmmkm9rAa5`
   - `VERCEL_PROJECT_ID` (matches `deploy/vercel/project.json`)
6. Preview/public dart-defines: `API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1`
   (verified). Do **not** set `staging-api.finance…` until DNS exists.
7. Production API host: wait for `api.finance.mkgtaxconsultants.com` DNS, or
   temporarily keep `app.mkgtaxconsultants.com`.
8. Confirm Neon integration is **not** installed on this project.
9. Configure Laravel CORS for `https://mkg-tax-mobile.vercel.app` (and previews).
10. Copy workflow examples from `docs/deployment/*.workflow.yml.example` into
    `.github/workflows/` with a `workflow`-scoped token.
