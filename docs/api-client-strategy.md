# API client strategy (Flutter + Vercel)

**Contract SoT:** Laravel `mkg-tax-backend-2` OpenAPI  
→ see sibling repo `docs/architecture/openapi-client-generation.md` and
`openapi/openapi.yaml`.

## Today

| Surface | Client | Notes |
|---|---|---|
| Flutter iOS / Android / Web | Hand-written Dio + repositories | `lib/core/network/laravel_api_client.dart` |
| Vercel host | Same Flutter web binary (prebuilt) | Not a separate TypeScript app yet |

Both use the **same** staging API and Neon-backed records via Laravel:

`API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1`

## Target pipeline

```text
Laravel OpenAPI
    → generated TypeScript client (web tooling / future Vercel TS surfaces)
    → generated Dart client (Flutter)
```

Benefits: fewer field/type mismatches, consistent errors, Vercel as prototype +
fallback + pre-release API checker, synchronized progress across phone ↔ desktop.

## Cross-device continuity (required behavior)

```text
Start return on iPhone
        ↓
Continue on desktop browser (Vercel)
        ↓
Upload documents
        ↓
Return to mobile app
```

Same Sanctum account + same Laravel/Neon tax-return/organizer rows. Do not fork
workflow state into client-only storage.

## What stays out of Vercel / generated clients

Tax engines, MeF, Neon credentials, App Store/Play signing, native camera,
biometrics, push certs — see Vercel scope and the backend architecture doc.

## Next steps for this repo

1. Keep hand-written Dio until OpenAPI covers auth + tax-returns + organizer.
2. Add generated Dart package under e.g. `packages/mkg_api/` once YAML is green.
3. Point Vercel Preview + Flutter staging at the **same** staging API always.
4. Add contract/regression checks in CI before native store builds.
