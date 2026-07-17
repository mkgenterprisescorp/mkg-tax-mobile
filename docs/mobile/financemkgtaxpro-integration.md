# Mobile → Laravel API → portal architecture

## Sources of truth
- **Web client portal:** `https://mkgtaxconsultants.com` (financemkgtaxpro on DigitalOcean).
- **Legacy portal host (transition only):** `https://financemkgtax.com` — do not point Flutter or S2S here for new work.
- **Laravel mobile API:** `https://app.mkgtaxconsultants.com/api/v1` (`mkg-tax-backend-2`) — **only** host Flutter may call for auth/sync/tax/profile.
- **Internal S2S (server-only):** `https://mkgtaxconsultants.com/internal/mobile/v1` — Laravel → portal HMAC. **PROHIBITED in Flutter.**
- **Database:** Neon PostgreSQL (server-side only). Flutter never connects to Neon.

## Data flow
```text
Flutter iOS/Android
        │ HTTPS (Sanctum bearer)
        ▼
app.mkgtaxconsultants.com/api/v1   (Laravel)
        │ HMAC S2S (server-only)
        ▼
mkgtaxconsultants.com/internal/mobile/v1   (financemkgtaxpro)
        │
        ▼
Portal Neon (authoritative users / tax / organizer)
```

## Flutter public config
```text
API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1
WEB_BASE_URL=https://mkgtaxconsultants.com
```

**Prohibited in Flutter:**
- `mkgtaxconsultants.com/internal/mobile/v1`
- `financemkgtax.com/internal/*`
- `MOBILE_SERVICE_CLIENT_*` / `FINANCEMKGTAXPRO_SERVICE_CLIENT_*`
- any Neon `DATABASE_URL`

Build:
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 \
  --dart-define=WEB_BASE_URL=https://mkgtaxconsultants.com
```

## Dual edition (one binary)
| Edition | Portal roles | Primary mobile surfaces |
|---------|--------------|-------------------------|
| **Consumer** | `client` | Home, Tax Center, Advisory (Finance Advisors), Advisor Chat, More |
| **Professional** | preparer / EA / CPA / admin / manager / ERO staff, etc. | Same primary tabs; Clients / iERO under **More** |

## Auth
- Laravel Sanctum `POST /api/v1/auth/login` → Bearer token (secure storage).
- Forgot-password, organizer, tax-return, registration (when enabled), profile, and sync continue through Laravel façades only.

## Domain transition gate

Do not treat the portal migration as complete until `mkgtaxconsultants.com` serves the financemkgtaxpro internal mobile API (unsigned → controlled 401; signed probes succeed). Until then, remote Section 10 E2E and APK cutover remain blocked. See portal `docs/account-sync/DOMAIN_TRANSITION.md`.

## Related
- Tax-year workspace: `docs/mobile/tax-year-workspace.md`
- Account sync contracts: `docs/account-sync/OWNERSHIP_AND_CONTRACTS.md`
- Flutter SoT repo: `mkg-tax-mobile`.
