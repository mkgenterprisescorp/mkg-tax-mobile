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
Flutter → https://api.financemkgtax.com/api/v1 (Laravel on DigitalOcean) → Neon
Web     → https://financemkgtax.com (DigitalOcean) → Laravel API → Neon
```

- Flutter **never** connects to Neon PostgreSQL.
- Public **default** (transitional): `API_BASE_URL=https://financemkgtax.com` until DigitalOcean `api.financemkgtax.com` DNS is live
- Production cutover: `--dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1`
- Details: `docs/mobile/financemkgtaxpro-integration.md`

## Run / build (Hot Reload)

```bash
flutter pub get

# Dev with Hot Reload (r = hot reload, R = hot restart in the terminal)
flutter run --dart-define=API_BASE_URL=https://financemkgtax.com \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com

# Production target (requires api.financemkgtax.com DNS + Laravel on DigitalOcean)
flutter run --dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com

flutter build apk --release --build-name=1.0.0 --build-number=15 \
  --dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com
```

## Branch

`cursor/unified-flutter-web-parity-f489` (PR #2)

## Status

- Dual-brand IA: Home | Tax Center | Advisory | Chat | More
- Device display name: **MKG Tax**
- Sanctum auth when `API_BASE_URL` targets `/api/v1`; cookie portal auth when pointing at `financemkgtax.com`
- Tax Organizer (personal dependents/W-2 + business Schedule C/entity) + Documents vault + Refund Advance (Loan Estimate / TILA / 36% APR)
- Advisor chat rooms + TESSA AI
- **No iOS build on Linux** (needs macOS + Xcode)
