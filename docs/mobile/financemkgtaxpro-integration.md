# Mobile → financemkgtaxpro architecture

## Source of truth
- **Web UI to clone:** `mkgenterprisescorp/financemkgtaxpro` (production portal)
- **Live host:** `https://financemkgtax.com` (DigitalOcean; Replit is sunset)
- **Production DB:** Neon Postgres via the DigitalOcean app `DATABASE_URL` (portal `users` / tax returns). Flutter never connects to Neon directly.
- **API:** same origin `/api/*` on that host (Express + session cookies)
- **Not the API target:** legacy `finance.mkgtaxconsultants.com` native endpoints, or the draft Laravel `mkg-tax-backend` (Chinese Wall platform Neon is separate)
- **Flutter SoT repo:** this package (`mkg-tax-mobile`). Mirror into `legacy-android-app/mkg-tax-mobile` when publishing monorepo syncs.

## Dual edition (one binary)
| Edition | Portal roles | Primary mobile surfaces |
|---------|--------------|-------------------------|
| **Consumer** | `client` | Home, Tax Center, Advisory (Finance Advisors), Advisor Chat, More |
| **Professional** | preparer / EA / CPA / admin / manager / ERO staff, etc. | Same primary tabs; Clients / iERO under **More** |

Edition is derived from `user.role` after cookie login (`lib/core/auth/app_roles.dart`). Bottom nav is unified around dual branding; tax-year tools live under Tax Center.

## Branding
- Device display name: **MKG Tax** (`CFBundleDisplayName` / `app_name`) to avoid home-screen truncation
- Splash / auth: **MKG Tax Consultants** primary + **Finance Advisors** secondary tagline
- Primary nav: `Home | Tax Center | Advisory | Chat | More`

## Auth + API boundary
Web portal still uses **cookie sessions** on `API_BASE_URL` (default `https://financemkgtax.com`).
Tax-year workspace APIs are on **Laravel** (`LARAVEL_API_BASE_URL`) at `/api/mobile/tax-years/*`.
**Flutter never connects to Neon.** See `docs/mobile/tax-year-workspace.md`.

Flutter must:
1. Point Dio portal client at `https://financemkgtax.com` (transitional)
2. Persist cookies with `cookie_jar` + `dio_cookie_manager`
3. Call Laravel for tax-year catalog / workspace when configured
4. Honor soft KYC / pending-approval redirects (same cutoff as web: users created on/after 2026-02-22)

## Client flows wired (MVP parity)
| Web / product surface | Mobile route | API |
|-----------|--------------|-----|
| Home dashboard | `/home` | Laravel tax-year + portal status |
| Tax Returns workspace | `/returns` | `/api/mobile/tax-years/{year}/*` |
| `/login`, `/register` | `/login`, `/register` | `/api/login`, `/api/register` |
| Forgot password | `/forgot-password` | `POST /api/forgot-password` → code → `POST /api/reset-password` |
| Organizer | `/organizer` | Laravel organizer + portal Schedule A slice |
| Documents | `/documents` | Year-scoped UI + portal upload |
| TESSA | `/tessa` | `/api/conversations` (+ SSE) |
| More hub | `/more` | Profile, billing, pro tools, support |

## Branding
- Primary green `#1A5632`, accent gold `#C9A84C`
- Logo assets under `assets/brand/`

## Status
Draft / not production-ready. Core client loops above are live against financemkgtax.com; Plaid Link, full Stripe WebView checkout, OTP document download, and camera KYC ID upload still lean on web for complete coverage.
