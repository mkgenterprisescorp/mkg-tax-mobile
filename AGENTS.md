# AGENTS.md

## Cursor Cloud specific instructions

### Auth / API / website hosts
- **Web client portal:** `https://mkgtaxconsultants.com` (financemkgtaxpro — not WordPress).
- **WordPress marketing:** `https://finance.mkgtaxconsultants.com` (`WEB_BASE_URL` default). Hosts the **WordPress site + WordPress database** on DigitalOcean. Registrar GoDaddy; DNS for `finance`/`app` is DigitalOcean nameservers.
- **Mobile API (required):** `API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1` (Sanctum). Do **not** reuse `app.` or `finance.` for the wrong product.
- **Payments deep links / Stripe return:** stay on portal `https://mkgtaxconsultants.com/payments` (`PAYMENTS_WEB_URL` / `portalRoot`).
- **WordPress is marketing only.** Never store tax returns, SSNs, bank data, uploads, or taxpayer records in the WordPress DB. Taxpayer SoT stays in Laravel + portal + Neon + Spaces.
- Flutter never talks to Neon, `/internal/*`, or portal S2S credentials.
- Domain cutover is **not** complete until portal internal routes on `mkgtaxconsultants.com` return controlled 401 for unsigned S2S (see financemkgtaxpro `docs/account-sync/DOMAIN_TRANSITION.md`).

### Why Flutter (not native Swift/Kotlin)
- **Third-party ecosystem:** Prefer pub.dev plugins for cross-platform needs (networking, secure storage, file pickers, deep links) instead of duplicating iOS/Android SDK wiring.
- **Hot Reload:** Use `flutter run` and press `r` / `R` to iterate UI without full rebuilds — especially for Tax Center, Organizer, and Refund Advance hubs.
- Current stack packages: `flutter_riverpod`, `go_router`, `dio` (+ cookie jar), `flutter_secure_storage`, `file_picker`, `url_launcher`. Add new plugins via `flutter pub add <package>` then `flutter pub get`.

### Product topology
- **Flutter** (`mkg-tax-mobile`) is the mobile SoT for iOS/Android — not Swift.
- **WordPress marketing:** `https://finance.mkgtaxconsultants.com` (DO — site + WP DB only).
- **Web client portal:** `https://mkgtaxconsultants.com` (financemkgtaxpro).
- **Mobile API:** `https://app.mkgtaxconsultants.com/api/v1` (mkg-tax-backend-2).
- Legacy `www` WP Engine may still redirect/alias until cutover to `finance.` is complete.
- Do not configure S2S / portal bridge against `financemkgtax.com`.

### Brand assets
- Official mark: **circular MKG Tax Consultants seal** (Fast Refunds 8–21 days / Accurate / Secure / Year-Round Support) at `assets/brand/mkg_tax_logo.png`.
- Use `BoxFit.contain` on a white plate over green chrome for splash/auth/app bar.

### Tax Refund Advances (Flutter)
- Hub: `/refund-advance` (also `/financial`).
- Walkthrough: Overview → **Refund calculator** (`/refund-advance/estimate`) → **Loan Estimate** (0% \$250/\$500/\$1k; **36% APR** at 25/50/75%) → **TILA** → apply.
- Sanctum APIs (preferred): `POST /api/v1/refund-advance/calculate|tila|apply`, `POST /api/v1/tax-estimates`. Portal cookie fallback still uses `/api/loans/*` when not on Laravel auth.
- Written Guarantee: `/refund-advance/guarantee`.
- Apply persists a **mobile application receipt** (invoice projection) — not live Pathward funding.

### Address + state dropdowns
- Shared widget: `AddressAutofillFields` (street/ZIP suggest via `GET /api/v1/address/autocomplete`, US state dropdown).
- Wired on Organizer Personal address + Profile KYC. W-2 Box 15 uses state dropdown.
- Nominatim is Laravel-side (`ADDRESS_AUTOCOMPLETE_PROVIDER`); never call OSM from the APK.

### Form 1040 autofill
- Route: `/organizer/form-1040` — `GET /api/v1/tax-year-workspaces/{id}/organizer/form-1040-preview`.
- SSN / bank numbers are never silent-autofilled.

### Official form links (TY 2025)
- CA 540 booklet: `https://www.ftb.ca.gov/forms/2025/2025-540-booklet.html`
- CA 540 instructions: `https://www.ftb.ca.gov/forms/2025/2025-540-instructions.html`
- CA 540 PDF / 540-X PDF: `…/2025-540.pdf`, `…/2025-540-x.pdf`
- IRS 1040-X: `https://www.irs.gov/forms-pubs/about-form-1040x` (+ `f1040x.pdf`)
- Wired in Organizer State Tax Returns, Form 1040-X step, and Form 1040 autofill screen (`official_form_links.dart`).

### CA Form 540 calculator
- Route: `/ca-540` (alias `/organizer/ca-540`).
- Laravel: `POST /api/v1/ca540/calculate`, `GET .../organizer/ca540-estimate` (`Ca540Calculator` — portal Organizer line math + FTB links).
- Saves computed `ca540` totals back to organizer section `state_ca_540`. Estimate-only (no CA e-file XML).

### Tax Organizer (web parity)
- Mobile `/organizer` opens an **icon hub** of sections first; tap a tile to walk through that section, then return to the hub.
- Personal walkthrough includes **Form 1040-X** (`form1040x` / section `form_1040x`) before State Tax Returns.
- Writes **canonical** `tax_returns.data` keys shared with `financemkgtaxpro` `Organizer.tsx` (not only `mobileOrganizer`).
- Defaults live in `assets/organizer/default_form_data.json` (exported from web `defaultFormData`).
- **Credits & Deductions** maps TY2025 Form 1040 lines (10, 12e, 13a/b, 19–20, 23, 27a–31) via `organizer_credits_step.dart` + `organizer_credits_math.dart`. Schemas include `schedule1`, `schedule1A`, `scheduleA`, `scheduleSE`, `schedule8812`, `schedule2`/`3`, `form8889`/`8863`/`5695`/`8995`/`8839`/`2441`. HSA is `form8889`/`schedule1.hsaDeduction` (not `healthInsurancePremiums`). Rollups are intake estimates, not e-file.
- **Income (1040)** maps Free File line-by-line intake via `organizer_income_forms_step.dart` + `organizer_income_math.dart`: `w2Forms` (1a/25a), `form1099NEC`/`form1099K` (business), `form1099R` (4a–5b), `formSSA1099` (6a/6b), `form1099G` (Sch. 1 unemployment/refund), `form1099DA`/`form1099B` (Line 7), `form1099INT`/`form1099DIV` (2b/3a/3b). IRS help: https://www.irs.gov/e-file-providers/line-by-line-instructions-free-file-fillable-forms
- `prepType` drives steps: `personal` / `business` → personal 1040 flow (Schedule C when `business` or `businessIncome > 0`); entity types `form1041|form1065|form1120S|form1120|form990|form990EZ` → 4-step entity flow.
- Personal depth: **dependents[]** (name/ssn/relationship/dob) + **w2Forms[]** (boxes 1–2/3/5/15–17; wages roll up).
- Schedule E in organizer uses `scheduleE.rentalProperties[]` (web Organizer shape). Standalone web `/schedule-e` uses `properties[]` — merge carefully.
- Load/create is **year-scoped** via tax-year selector; staff can open `/organizer?returnId=<id>` from All Returns.
- Save: `PUT /api/tax-returns/:id` with `{ year, status, filingStatus, data }` after deep-merge load.
- Tax Center also uses a 2-column icon grid for the main sections to complete.

### Documents
- `/documents` is year-scoped: `getOrCreateReturnForYear` → list/upload with document type picker.
- Cookie download tries `/api/documents/:id/download` then secure-download; OTP may still require web vault.
- **Smart intake** (`/documents/smart-intake`): upload → `POST /api/v1/documents/{id}/extract` → verify UI → apply to organizer. SSN fields are never silent-autofilled. No OpenAI/Adobe/Stripe secrets in the APK.

### Billing / Stripe
- `/billing` shows fee schedule (`GET /api/v1/billing/fee-schedule`) + invoices; pay via **hosted Stripe Checkout** URL from Laravel (`fee-checkout` / `invoices/{id}/checkout`). Do **not** add `flutter_stripe` PaymentSheet unless product explicitly overrides hosted checkout.

### Advisor Chat + TESSA
- `/chat` lists portal rooms (`GET /api/chat/rooms`) and supports send (`POST .../messages`).
- `/tessa` uses Laravel `GET/POST /api/v1/tessa/conversations*` (portal S2S when available; **local keyword fallback** when portal TESSA is down).

### Financial Tools hub (`/tools`, alias `/financial-tools`)
- Paycheck & W-4: `/payroll-tools` → `POST /api/v1/payroll-calculations`, `POST /api/v1/w4-estimates` (estimate only).
- Refund estimator: `/refund-advance/estimate`.
- Refund advance loans: `/refund-advance` (loan estimate → TILA → apply).
- Payments: `/billing` (hosted Stripe Checkout via Laravel).
- Tax savings: `/tax-savings` (native checklist; optional web AI at `/tax-savings`).
- Things to bring: `/things-to-bring` (client checklist; staff email/SMS stays on portal).

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
