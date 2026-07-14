# mkg-tax-mobile

Flutter single source of truth for MKG Tax Consultants iOS and Android.

## Architecture

```text
Flutter → https://api.financemkgtax.com/api/v1 (Laravel on DigitalOcean) → Neon
Web     → https://financemkgtax.com (DigitalOcean) → Laravel API → Neon
```

- Flutter **never** connects to Neon PostgreSQL.
- Public config: `API_BASE_URL=https://api.financemkgtax.com/api/v1`, `WEB_BASE_URL=https://financemkgtax.com`
- Details: `docs/mobile/financemkgtaxpro-integration.md`

## Run / build

```bash
flutter pub get

# Production target (requires api.financemkgtax.com DNS + Laravel on DigitalOcean)
flutter run --dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com

flutter build apk --release --build-name=1.0.0 --build-number=11 \
  --dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com

# Transitional device-verify (portal cookie login while API DNS is pending)
flutter build apk --release --build-name=1.0.0 --build-number=11 \
  --dart-define=API_BASE_URL=https://financemkgtax.com \
  --dart-define=WEB_BASE_URL=https://financemkgtax.com
```

## Branch

`cursor/unified-flutter-web-parity-f489` (PR #2)

## Status

- Dual-brand IA: Home | Tax Center | Advisory | Chat | More
- Device display name: **MKG Tax**
- Sanctum auth when `API_BASE_URL` targets `/api/v1`; cookie portal auth when pointing at `financemkgtax.com`
- **No iOS build on Linux** (needs macOS + Xcode)
