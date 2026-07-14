# Mobile → Laravel API → Neon architecture

## Sources of truth
- **Public web:** `https://financemkgtax.com` (DigitalOcean). `www` redirects to apex.
- **Laravel API:** `https://api.financemkgtax.com` (DigitalOcean) — authoritative for mobile + web data.
- **Database:** Neon PostgreSQL (server-side `DATABASE_URL` on Laravel only).
- **Flutter never connects to Neon.** No DB URLs in Dart, Kotlin, Swift, or client JS.

## Data flow
```text
Flutter iOS/Android
        │ HTTPS
        ▼
api.financemkgtax.com  (Laravel on DigitalOcean)
        │ encrypted Postgres
        ▼
Neon PostgreSQL

React/Vite web (financemkgtax.com)
        │
        ▼
Laravel API → Neon
```

Large tax files (W-2, 1099, PDFs, IDs) go to encrypted object storage (e.g. DigitalOcean Spaces); Neon stores metadata only.

## Flutter public config
```text
API_BASE_URL=https://api.financemkgtax.com/api/v1
WEB_BASE_URL=https://financemkgtax.com
```
Optional override: `LARAVEL_API_BASE_URL` (defaults to API origin derived by stripping `/api/v1`).

Build:
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com
```

### Transitional device-verify (until `api.financemkgtax.com` DNS is live)
Cookie portal login still works against the web host:
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://financemkgtax.com \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com
```

## Dual edition (one binary)
| Edition | Portal roles | Primary mobile surfaces |
|---------|--------------|-------------------------|
| **Consumer** | `client` | Home, Tax Center, Advisory (Finance Advisors), Advisor Chat, More |
| **Professional** | preparer / EA / CPA / admin / manager / ERO staff, etc. | Same primary tabs; Clients / iERO under **More** |

## Auth
- **Production:** Laravel Sanctum `POST /api/v1/auth/login` → Bearer token (secure storage).
- **Transitional:** cookie session against `financemkgtax.com` when `API_BASE_URL` does not target `/api/v1`.

## Related
- Tax-year workspace: `docs/mobile/tax-year-workspace.md`
- Flutter SoT repo: `mkg-tax-mobile`. Mirror into `legacy-android-app/mkg-tax-mobile` when publishing monorepo syncs.
