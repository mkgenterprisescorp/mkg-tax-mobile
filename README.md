# mkg_tax_mobile

Flutter single source of truth for **MKG Tax Consultants** on iOS and Android.

## Why Flutter

| Advantage | What it means for MKG Tax |
|-----------|---------------------------|
| **Third-party ecosystem** | Large pub.dev catalog of cross-platform plugins (HTTP, secure storage, file pickers, routing, state) — one integration for iOS + Android instead of separate Swift/Kotlin SDKs. |
| **Hot Reload** | Change UI/logic and see updates instantly without a full rebuild — faster organizer, Tax Center, and Refund Advance iteration. |
| **One codebase** | Shared Dart UI + business logic ships to both stores; legacy native Swift/Kotlin apps are historical only. |

Current pub packages in use include `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `file_picker`, `url_launcher`, and cookie session helpers.

## Architecture

```text
Flutter → https://app.mkgtaxconsultants.com/api/v1  (Laravel mkg-tax-backend-2) → Neon (Laravel DB only)
Web     → https://mkgtaxconsultants.com             (financemkgtaxpro portal)
S2S     → https://mkgtaxconsultants.com/internal/mobile/v1  (Laravel→portal only; NEVER in Flutter)
```

- Flutter **never** connects to Neon PostgreSQL.
- Flutter **never** calls `/internal/mobile/v1` or holds portal S2S secrets.
- Required dart-define: `--dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1`
- Portal deep links only: `--dart-define=WEB_BASE_URL=https://mkgtaxconsultants.com`
- Details: `docs/mobile/financemkgtaxpro-integration.md`, `docs/account-sync/OWNERSHIP_AND_CONTRACTS.md`

## Run / build (Hot Reload)

```bash
flutter pub get

# Staging / Sanctum mobile API (required)
flutter run --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://mkgtaxconsultants.com

flutter build apk --release --build-name=1.0.0 --build-number=15 \
  --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://mkgtaxconsultants.com

# Staging Flutter web (same dart-defines; also built by Dockerfile for DO)
flutter build web --release \
  --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 \
  --dart-define=LARAVEL_API_BASE_URL=https://app.mkgtaxconsultants.com \
  --dart-define=WEB_BASE_URL=https://finance.mkgtaxconsultants.com
```

`AppConfig.validate()` fails loudly if `API_BASE_URL` is omitted.

DigitalOcean App Platform staging web: `.do/app.yaml` + `Dockerfile` (nginx `:8080`).
Create/update with `doctl apps create --spec .do/app.yaml` (or upsert). Leave
`deploy_on_push: false` until the first build is green.

## Branch

`cursor/mobile-account-sync-f489` (account-sync / domain transition)

## Status

- Dual-brand IA: Home | Tax Center | Advisory | Chat | More
- Device display name: **MKG Tax**
- Sanctum auth against `app.mkgtaxconsultants.com/api/v1`
- Tax Organizer + Documents vault + Refund Advance flows
- Advisor chat rooms + TESSA AI
- Registration UI remains gated while `MOBILE_REGISTRATION_ENABLED=false` on Laravel
- **No iOS build on Linux** (needs macOS + Xcode)
- **No merge / APK / remote E2E** until portal host verification + Section 10 staging gates pass
