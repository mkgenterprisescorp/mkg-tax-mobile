# AGENTS.md

## Cursor Cloud specific instructions

### Auth / API host (until DigitalOcean API URL is live)
- **Web client portal:** `https://mkgtaxconsultants.com` (not `financemkgtax.com`).
- **Staging mobile API:** `https://app.mkgtaxconsultants.com/api/v1` (Sanctum).
- Cookie/portal transitional builds may use `API_BASE_URL=https://mkgtaxconsultants.com`; Sanctum activates when `API_BASE_URL` contains `/api/v1`.
- Flutter never talks to Neon or `/internal/*` directly.

### Why Flutter (not native Swift/Kotlin)
- **Third-party ecosystem:** Prefer pub.dev plugins for cross-platform needs (networking, secure storage, file pickers, deep links) instead of duplicating iOS/Android SDK wiring.
- **Hot Reload:** Use `flutter run` and press `r` / `R` to iterate UI without full rebuilds — especially for Tax Center, Organizer, and Refund Advance hubs.
- Current stack packages: `flutter_riverpod`, `go_router`, `dio` (+ cookie jar), `flutter_secure_storage`, `file_picker`, `url_launcher`. Add new plugins via `flutter pub add <package>` then `flutter pub get`.

### Product topology
- **Flutter** (`mkg-tax-mobile`) is the mobile SoT for iOS/Android — not Swift.
- **Web client portal:** `https://mkgtaxconsultants.com` (financemkgtaxpro).
- **Mobile API:** `https://app.mkgtaxconsultants.com/api/v1` (mkg-tax-backend-2).
- Do not configure S2S / portal bridge against `financemkgtax.com`.

### Brand assets
- Official mark: **circular MKG Tax Consultants seal** (Fast Refunds 8–21 days / Accurate / Secure / Year-Round Support) at `assets/brand/mkg_tax_logo.png`.
- Use `BoxFit.contain` on a white plate over green chrome for splash/auth/app bar.

### Tax Refund Advances (Flutter)
- Hub: `/refund-advance` (also `/financial`).
- Walkthrough icons: Overview → **Loan Estimate** (0% \$250/\$500/\$1k; **36% APR** at 25/50/75%) → **TILA** → apply.
- APIs: `POST /api/loans/calculate`, `POST /api/loans/apply` (web parity: `financemkgtaxpro` `Financials.tsx`, Pathward N.A.).
- Written Guarantee: `/refund-advance/guarantee`.

### Tax Organizer (web parity)
- Mobile `/organizer` opens an **icon hub** of sections first; tap a tile to walk through that section, then return to the hub.
- Writes **canonical** `tax_returns.data` keys shared with `financemkgtaxpro` `Organizer.tsx` (not only `mobileOrganizer`).
- Defaults live in `assets/organizer/default_form_data.json` (exported from web `defaultFormData`).
- `prepType` drives steps: `personal` / `business` → personal 1040 flow (Schedule C when `business` or `businessIncome > 0`); entity types `form1041|form1065|form1120S|form1120|form990|form990EZ` → 4-step entity flow.
- Personal depth: **dependents[]** (name/ssn/relationship/dob) + **w2Forms[]** (boxes 1–2/3/5/15–17; wages roll up).
- Schedule E in organizer uses `scheduleE.rentalProperties[]` (web Organizer shape). Standalone web `/schedule-e` uses `properties[]` — merge carefully.
- Load/create is **year-scoped** via tax-year selector; staff can open `/organizer?returnId=<id>` from All Returns.
- Save: `PUT /api/tax-returns/:id` with `{ year, status, filingStatus, data }` after deep-merge load.
- Tax Center also uses a 2-column icon grid for the main sections to complete.

### Documents
- `/documents` is year-scoped: `getOrCreateReturnForYear` → list/upload with document type picker.
- Cookie download tries `/api/documents/:id/download` then secure-download; OTP may still require web vault.

### Advisor Chat
- `/chat` lists portal rooms (`GET /api/chat/rooms`) and supports send (`POST .../messages`); TESSA remains `/tessa`.

### Commands
- Deps: `flutter pub get` (refresh pub.dev plugins after pull)
- Analyze: `flutter analyze`
- Schema tests: `flutter test test/organizer_schema_test.dart`
- Hot Reload dev: `flutter run` then `r` (reload) / `R` (restart)
- Debug APK: `flutter build apk --debug`
- Dev run needs Android SDK + JDK 21 for Flutter Gradle.

### Cookie-auth progress
- When `API_BASE_URL` is portal (no `/api/v1`), Home/Tax Center workspace progress comes from portal `tax_returns` via `TaxYearWorkspace.fromPortalReturn`.
- When `API_BASE_URL` contains `/api/v1`, tax years/entities/organizer/documents/payroll/messages/invoices/banking use Laravel Sanctum repositories under `/api/v1/*` (see `docs/openapi-v1-sketch.md` on backend and Flutter `features/*/data/*_repository.dart`).

### Phases 1–6 (Sanctum builds)
- Login field sent as `identifier` to `POST /auth/login`; identity via `GET /me`.
- Tax-year activate: ensure entity → `POST /entities/{id}/tax-years/activate`.
- Documents: multipart upload + signed download URL (never log query secrets).
- Payroll/W-4: estimate-only UI at `/payroll-tools`.
- Banking: connection stub only — MKG is not a bank; no credentials / money movement.
- **Do not** run staging/prod migrations or change DO DNS from agent sessions without explicit approval.
