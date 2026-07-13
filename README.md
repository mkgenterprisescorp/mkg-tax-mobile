# mkg-tax-mobile

Flutter single source of truth for MKG Tax Consultants iOS and Android.

## Stack

Flutter, Dart, Riverpod, go_router, dio, freezed, json_serializable, flutter_secure_storage.

## Config

Public only:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

No secrets in the app. Laravel is authoritative.

## Branch

`migration/unified-flutter-mobile`

## Status

**Not production-ready yet.**

- Draft-only: GitHub remote/PR pending org repo creation
- Demo auth UI (does not yet call Laravel Sanctum/MFA as authority)
- Debug signing only (`app-debug.apk`)
- Android debug build succeeds in this environment
- **No iOS device/simulator build here** (Linux VM — needs macOS + Xcode)
