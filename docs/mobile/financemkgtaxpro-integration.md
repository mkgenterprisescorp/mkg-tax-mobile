# Mobile → financemkgtaxpro architecture

## Source of truth
- **Web UI to clone:** `mkgenterprisescorp/financemkgtaxpro` (production portal)
- **Live host:** `https://financemkgtax.com`
- **API:** same origin `/api/*` on that host (Express + session cookies)
- **Not the API target:** legacy `finance.mkgtaxconsultants.com` native endpoints, or the draft Laravel `mkg-tax-backend` (Chinese Wall platform work is separate)

## Auth model
Web uses **cookie sessions** (`credentials: "include"`), not Bearer tokens.
Flutter must:
1. Point Dio at `https://financemkgtax.com`
2. Persist cookies with `cookie_jar` + `dio_cookie_manager`
3. Call `POST /api/login` / `POST /api/register` / `GET /api/auth/user` / `POST /api/logout`

## Client flows to mirror (MVP)
| Web route | Mobile route | API |
|-----------|--------------|-----|
| `/login`, `/register` | `/login`, `/register` | `/api/login`, `/api/register` |
| `/dashboard` | `/forms` (hub) | `/api/auth/user`, `/api/tax-returns/current` |
| `/organizer` | `/organizer` | `/api/tax-returns/:id` GET/PUT |
| `/documents` | `/documents` | `/api/documents/upload`, list docs |
| `/profile` | `/profile` | `/api/user/profile`, `/api/user/kyc-submit` |
| `/ai-assistant` | `/tessa` | `/api/conversations` |
| `/payments` | `/billing` | `/api/invoicing/*`, `/api/stripe/*` |
| `/financials` | `/financial` | `/api/loans/*` |

## Branding
Clone web tokens from `financemkgtaxpro/client/src/index.css`:
- Primary green ~`#0f7a3a` (HSL 142 76% 26%)
- Accent gold ~`#e8b90a` (HSL 45 93% 47%)
- Do **not** use legacy Android blue `#006FCD` for the Flutter SoT going forward.

## Status
Draft / not production-ready until session auth, organizer parity, KYC, and payments are fully verified on device.
