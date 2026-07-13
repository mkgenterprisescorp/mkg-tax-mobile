# mkg-tax-mobile

Flutter single source of truth for MKG Tax Consultants iOS and Android.

## Architecture

- **UI to clone:** `financemkgtaxpro` web portal (green/gold brand)
- **API host:** `https://financemkgtax.com` (`POST /api/login`, `/api/register`, `/api/auth/user`, …)
- Session cookies via Dio + cookie_jar (same model as the web `credentials: "include"` client)
- Details: `docs/mobile/financemkgtaxpro-integration.md`

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://financemkgtax.com
flutter build apk --debug --dart-define=API_BASE_URL=https://financemkgtax.com
```

## Branch

`migration/unified-flutter-mobile`

## Status

**Not production-ready yet.**

- Draft PR; debug signing only
- Login/register call live financemkgtaxpro; organizer/KYC/payments still partial
- **No iOS build on Linux** (needs macOS + Xcode)
