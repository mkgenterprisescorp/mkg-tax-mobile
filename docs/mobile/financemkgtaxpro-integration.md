# Mobile → financemkgtaxpro architecture

## Source of truth
- **Web UI to clone:** `mkgenterprisescorp/financemkgtaxpro` (production portal)
- **Live host:** `https://financemkgtax.com`
- **API:** same origin `/api/*` on that host (Express + session cookies)
- **Not the API target:** legacy `finance.mkgtaxconsultants.com` native endpoints, or the draft Laravel `mkg-tax-backend` (Chinese Wall platform work is separate)
- **Flutter SoT repo:** this package (`mkg-tax-mobile`). Mirror into `legacy-android-app/mkg-tax-mobile` when publishing monorepo syncs.

## Auth model
Web uses **cookie sessions** (`credentials: "include"`), not Bearer tokens.
Flutter must:
1. Point Dio at `https://financemkgtax.com`
2. Persist cookies with `cookie_jar` + `dio_cookie_manager`
3. Call `POST /api/login` / `POST /api/register` / `GET /api/auth/user` / `POST /api/logout`
4. Honor soft KYC / pending-approval redirects (same cutoff as web: users created on/after 2026-02-22)

## Client flows wired (MVP parity)
| Web route | Mobile route | API |
|-----------|--------------|-----|
| `/login`, `/register` | `/login`, `/register` | `/api/login`, `/api/register` |
| `/dashboard` | `/forms` | `/api/tax-returns`, `/api/user/verification-status` |
| `/organizer` | `/organizer` | `/api/tax-returns/current`, `PUT /api/tax-returns/:id` |
| `/documents` | `/documents` | `GET /api/tax-returns/:id/documents`, `POST /api/documents/upload` |
| `/profile` | `/profile` | `POST /api/user/kyc-submit`, `POST /api/user/ssn` |
| `/ai-assistant` | `/tessa` | `/api/conversations` (+ SSE message stream) |
| `/chat` | `/messages` | `/api/chat/rooms` |
| `/payments` | `/billing` | `/api/invoicing/invoices` |
| `/financials` | `/financial` | `/api/loans/calculate`, `/api/loans/apply` |
| `/refund-tracker` | `/refund-tracker` | External IRS/FTB links |

## Branding
- Primary green `#1A5632`, accent gold `#C9A84C`
- Logo assets under `assets/brand/`

## Status
Draft / not production-ready. Core client loops above are live against financemkgtax.com; Plaid Link, full Stripe WebView checkout, OTP document download, and camera KYC ID upload still lean on web for complete coverage.
