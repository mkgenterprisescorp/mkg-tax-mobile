# Account sync contracts (Flutter mirror)

See authoritative document in `mkg-tax-backend-2/docs/account-sync/OWNERSHIP_AND_CONTRACTS.md`.

## Flutter rules (this milestone)

- Registration UI stays **unavailable** (`usesLaravelAuth` path).
- Do not call `/internal/*` or store portal DB credentials.
- Public API only: `https://app.mkgtaxconsultants.com/api/v1`.
- Internal portal origin is never compiled into the APK.

## Domains

| Role | Host |
|---|---|
| Marketing | `https://mkgtaxconsultants.com` |
| Web portal | `https://financemkgtax.com` |
| Mobile API | `https://app.mkgtaxconsultants.com/api/v1` |
| Internal S2S | portal `/internal/mobile/v1` (server-only) |
