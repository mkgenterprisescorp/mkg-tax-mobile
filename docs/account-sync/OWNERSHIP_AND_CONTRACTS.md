# Account sync contracts (Flutter mirror)

See authoritative document in `mkg-tax-backend-2/docs/account-sync/OWNERSHIP_AND_CONTRACTS.md`.

## Flutter rules (this milestone)

- Registration UI stays **unavailable** (`usesLaravelAuth` path) — do not enable until staging bridge E2E gates pass.
- Do not claim synchronization is complete from the mobile client.
- Do not call `/internal/*` or store portal DB / service credentials.
- Public API only: `https://app.mkgtaxconsultants.com/api/v1`.
- Internal portal origin is never compiled into the APK.
- No new APK until authoritative staging smoke tests pass.

## Domains

| Role | Host |
|---|---|
| Marketing | `https://mkgtaxconsultants.com` |
| Web portal | `https://mkgtaxconsultants.com` |
| Mobile API | `https://app.mkgtaxconsultants.com/api/v1` |
| Internal S2S | `https://mkgtaxconsultants.com/internal/mobile/v1` (server-only; never in Flutter) |

> **Domain correction:** The web client portal is `mkgtaxconsultants.com`, not `financemkgtax.com`.
