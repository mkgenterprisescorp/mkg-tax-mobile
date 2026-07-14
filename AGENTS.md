# AGENTS.md

## Cursor Cloud specific instructions

### Product topology
- Flutter app (`mkg-tax-mobile`) is the mobile SoT for iOS/Android.
- One Laravel API (`api.financemkgtax.com` → `/api/v1`) backs web + mobile; transitional web host is `financemkgtax.com`.
- Until `api.financemkgtax.com` DNS is live, device builds may point `API_BASE_URL` at `https://financemkgtax.com` (cookie/session auth). Sanctum bearer path activates when `API_BASE_URL` contains `/api/v1`.

### Tax Organizer (web parity)
- Mobile `/organizer` writes **canonical** `tax_returns.data` keys shared with `financemkgtaxpro` `Organizer.tsx` (not only `mobileOrganizer`).
- Defaults live in `assets/organizer/default_form_data.json` (exported from web `defaultFormData`).
- `prepType` drives steps: `personal` / `business` → personal 1040 flow (Schedule C when `business` or `businessIncome > 0`); entity types `form1041|form1065|form1120S|form1120|form990|form990EZ` → 4-step entity flow.
- Schedule E in organizer uses `scheduleE.rentalProperties[]` (web Organizer shape). Standalone web `/schedule-e` uses `properties[]` — merge carefully.
- Save: `PUT /api/tax-returns/:id` with `{ year, status, filingStatus, data }` after deep-merge load.

### Brand assets
- Splash/auth logo is the MKG Insurance Agency & Tax Consultants lockup from web `11zon_cropped_(1)_…` (replaces the old solid green MKG/TAX tile). Use `BoxFit.contain` on a white plate over the green chrome.

### Commands
- Analyze: `flutter analyze`
- Schema tests: `flutter test test/organizer_schema_test.dart`
- Debug APK: `flutter build apk --debug`
- Dev run needs Android SDK + JDK 21 for Flutter Gradle.
