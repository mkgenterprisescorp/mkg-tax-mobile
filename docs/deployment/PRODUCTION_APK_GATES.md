# Production APK gates (no DO Web Service)

**Policy:** Android Flutter is distributed via CI / controlled build machine → GitHub Release, Play internal testing, or secured object storage.  
**Do not** host the Android Flutter source as a DigitalOcean Web Service.  
**Do not** create a new `mkg-tax-mobile-web` App Platform app.  
**Do not** publish a production APK until mobile API promote-in-place gates pass.

## Required dart-defines (production)

```text
API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1
LARAVEL_API_BASE_URL=https://app.mkgtaxconsultants.com
```

Portal deep links remain `https://mkgtaxconsultants.com`.

## Sequence

1. Backend promote-in-place PASS (`mkg-tax-backend-2` `docs/deployment/PRODUCTION_PROMOTE_IN_PLACE.md`).
2. Build **testing** APK (staging or dedicated testing signing) against the production API URL.
3. Owner device QA:
   - invalid login, verified-client login, logout, session expiration
   - password reset, profile sync, organizer R/W, tax-return reads
   - document upload, offline/network errors, 429 handling
   - no raw API error strings in UI
4. Only then: production-signed AAB/APK, publish SHA-256 + signing-certificate digest.
5. Update WordPress `inc/mobile-apk-release.php` metadata; retain prior build for rollback.
6. Never commit keystores or APK binaries into `mkg-tax-marketing-wp`.

## Current testing artifact (pre-promotion)

| Field | Value |
|---|---|
| Version | 1.0.0+29 |
| Channel | staging-testing |
| SHA-256 | `504b31b61d38ac04e2fa7373cf3b05304bf51278bd58048cf26c55c4fac3903f` |
| Size | 63585832 bytes (~60.6 MB) |
| Signing | Staging / Flutter default release keystore — **not** Play production |
| Release | `staging-banking-web-1.0.0-29` |

Production signed release: **NOT BUILT** (gates blocked).
