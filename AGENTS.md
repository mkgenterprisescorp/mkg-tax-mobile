# AGENTS.md

## Cursor Cloud specific instructions

### Product topology
- **Flutter** (`mkg-tax-mobile`) is the mobile SoT for iOS/Android — not Swift.
- One Laravel API (`api.financemkgtax.com` → `/api/v1`) backs web + mobile; transitional web host is `financemkgtax.com`.
- Until `api.financemkgtax.com` DNS is live, device builds may point `API_BASE_URL` at `https://financemkgtax.com` (cookie/session auth). Sanctum bearer path activates when `API_BASE_URL` contains `/api/v1`.

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
- Schedule E in organizer uses `scheduleE.rentalProperties[]` (web Organizer shape). Standalone web `/schedule-e` uses `properties[]` — merge carefully.
- Save: `PUT /api/tax-returns/:id` with `{ year, status, filingStatus, data }` after deep-merge load.
- Tax Center also uses a 2-column icon grid for the main sections to complete.

### Commands
- Analyze: `flutter analyze`
- Schema tests: `flutter test test/organizer_schema_test.dart`
- Debug APK: `flutter build apk --debug`
- Dev run needs Android SDK + JDK 21 for Flutter Gradle.
