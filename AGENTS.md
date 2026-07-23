# AGENTS.md

## Cursor Cloud specific instructions

### Shared API contract (next improvement)
- Laravel OpenAPI SoT: sibling `mkg-tax-backend-2` → `openapi/openapi.yaml` + `docs/architecture/openapi-client-generation.md`.
- Flutter consumer plan: `docs/api-client-strategy.md`. Keep hand-written Dio until generated Dart covers auth + tax-returns + organizer.
- Vercel Flutter web is prototype / companion / fallback / pre-release API checker — same Sanctum account + Neon records as native. See `docs/deployment/vercel-scope.md`.
- **Faster web iteration:** `bash scripts/dev-vercel-preview.sh` (preview) or `bash scripts/deploy-vercel-web.sh` (prod). Requires `VERCEL_TOKEN` (+ optional `VERCEL_ORG_ID=team_5uxQCVdAhb1FImpmmkm9rAa5`, `VERCEL_PROJECT_ID`). Prebuilt only — do not cold-build Flutter on Vercel Git. Production alias: `https://mkg-tax-mobile.vercel.app`. Laravel CORS must allowlist that origin.

### Tessa multi-agent platform
- Architecture SoT (backend): `mkg-tax-backend-2` `docs/architecture/multi-agent-tessa.md`
- Flutter summary: `docs/tessa-multi-agent.md` — `/tessa` only; engines authoritative; `/chat` is Advisor Chat (do not redirect to Tessa).
- **Multilingual Phase 1:** `docs/architecture/tessa-multilingual.md` — EN/ES ARB + `/language-setup`; send `preferred_language` on chat; never put Gemini/STT/TTS keys in Flutter; never infer language from device.

### Flutter performance
- Playbook: `docs/performance/flutter-performance-playbook.md` — DevTools-first, lazy load, Riverpod, network/assets, skeleton UI, isolates.
- Local/CI guardian: `bash scripts/performance-guardian.sh` · workflow example `docs/deployment/performance-guardian.workflow.yml.example`.
- Targets: cold start <2.5s, organizer step <200ms, stable 60 FPS; engines stay on Laravel.

### Profile / KYC submit (Sanctum)
- Profile screen **must not** call portal `/api/user/kyc-submit` on Sanctum builds (404 → “The requested item is unavailable.”).
- Use `AuthRepository.submitProfileForReview` → `GET` then versioned `PATCH /api/v1/profile` (retry once on 409). SSN is not accepted on this bridge — collect via Organizer/Documents.

### Auth / API / website hosts
- **DO web app (client login):** `https://mkgtaxconsultants.com` (`financemkgtaxpro` + DO Postgres) — clients manage taxes/forms; also owns IRS XML / MeF. Notifications/chats/staff UI live here, **not** in WordPress.
- **WordPress:** marketing only (`WEB_BASE_URL` may be `https://finance.mkgtaxconsultants.com` or legacy `www`). No WP portal for app users / notifications / chats. See `mkg-tax-marketing-wp` `docs/MOBILE_MOAT_INSTALL.md`.
- **Mobile API (required):** `API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1` (Sanctum + Neon).
- **Payments deep links / Stripe return:** portal `https://mkgtaxconsultants.com/payments` (`portalRoot`).
- **Bidirectional sync:** Flutter ↔ Laravel ↔ portal APIs — **latest successful update wins** on both surfaces. Flutter never talks to Neon/`/internal/*`/portal S2S credentials directly.
- **Product role (owner clarification):** Flutter is the **CRM + POS** client **and** the surface that delivers **automation + workflow triggers** to **new and existing users** (onboarding, renewals, document chase, payment reminders, prep milestones, Technology Access entitlement). Billing/comms ride the same app. Does **not** submit IRS e-file — pushes tax data to `financemkgtaxpro` over API; pulls web status back.
- **Split SoT:** mobile → **Neon**; web → **DO Postgres**. No shared DB URL.
- Domain cutover notes: financemkgtaxpro `docs/account-sync/DOMAIN_TRANSITION.md`.
- Detail: `docs/architecture/mobile-crm-pos-automation.md`.
- **Workflow notices SoT:** portal `financemkgtaxpro` schedules new-user **document prompts**, **Apr 15 / Oct 15** filing reminders, and LLC/Corp dense notices (**3w→8h**). Flutter presents / deep-links only — see that doc’s “Filing / document workflow triggers” section.
- **In-app inbox:** `/notifications` → `GET /api/v1/notifications?has_documents=&prep_type=` (Laravel `WorkflowTriggerBuilder`). Tapping a card deep-links to `/documents` or `/organizer`.

### Why Flutter (not native Swift/Kotlin)
- **Third-party ecosystem:** Prefer pub.dev plugins for cross-platform needs (networking, secure storage, file pickers, deep links) instead of duplicating iOS/Android SDK wiring.
- **Hot Reload:** Use `flutter run` and press `r` / `R` to iterate UI without full rebuilds — especially for Tax Center, Organizer, and Refund Advance hubs.
- Current stack packages: `flutter_riverpod`, `go_router`, `dio` (+ cookie jar), `flutter_secure_storage`, `file_picker`, `url_launcher`. Add new plugins via `flutter pub add <package>` then `flutter pub get`.

### Product topology
- **Flutter** (`mkg-tax-mobile`) is the **CRM + POS + automation/workflow** client for iOS/Android (and Flutter web companion) — not Swift/Kotlin. Same app serves **new signups** and **existing clients** (grace → subscribe via portal Technology Access).
- **Client web portal:** `https://mkgtaxconsultants.com` (financemkgtaxpro + DO Postgres) — login, taxes, forms, chats; Stripe Technology Access SoT; staff/ERO ops remain web-first where noted in the parity matrix.
- **Mobile API/DB:** `https://app.mkgtaxconsultants.com/api/v1` + **Neon** — orchestrates CRM/POS façades + workflow trigger delivery; engines stay Laravel.
- **WordPress:** marketing only (optional `finance.` on DO).
- Legacy `www` WP Engine may redirect to `finance.` when marketing cutover is approved.
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

### Nationwide regional estimates (Regions 1–6)
- Flutter calls Laravel facades only — **no tax math in the app**. Prefer `RegionalStateTaxRepository` → `POST /api/v1/regions/{n}/estimate` (Region 1 legacy shape still works; R2–6 return StateTaxRouter payloads).
- Estimate button shows for broad-PIT resident individual workflows (`regional_estimate_support.dart`). CA stays on Form 540; no-broad-PIT states stay intake-only.
- Bundled catalog `assets/region1-west-forms-ty2025.json` is nationwide (all regions); R2–5 PIT individual returns are `estimate_supported`.

### Tax Organizer (web parity)
- Mobile `/organizer` opens an **icon hub** of sections first; tap a tile to walk through that section, then return to the hub.
- Personal walkthrough includes **Form 1040-X** (`form1040x` / section `form_1040x`) before State Tax Returns.
- Writes **canonical** `tax_returns.data` keys shared with `financemkgtaxpro` `Organizer.tsx` (not only `mobileOrganizer`).
- Defaults live in `assets/organizer/default_form_data.json` (exported from web `defaultFormData`).
- **Credits & Deductions** maps TY2025 Form 1040 lines (10, 12e, 13a/b, 19–20, 23, 27a–31) via `organizer_credits_step.dart` + `organizer_credits_math.dart`. Schemas include `schedule1`, `schedule1A`, `scheduleA`, `scheduleSE`, `schedule8812`, `schedule2`/`3`, `form8889`/`8863`/`5695`/`8995`/`8839`/`2441`. HSA is `form8889`/`schedule1.hsaDeduction` (not `healthInsurancePremiums`). Rollups are intake estimates, not e-file.
- **Form 8863 credit type** is a dropdown: American Opportunity vs Lifetime Learning (`educationCreditTypeOptions` / `normalizeEducationCreditType` in `organizer_credits_tessa_sheet.dart`). Stored values remain `american_opportunity` / `lifetime_learning`.
- **Tessa credits guidance** sheet on Credits & Deductions explains eligibility, disallowance, false-claim penalties, and that supporting documentation may be required; acknowledgement persists as `creditsGuidanceAcknowledged`.
- **Organizer autosave:** Neon PUTs often take 4–8s. Credits/Income/State use a longer debounce; organizer writes use 60s send/receive timeouts + one retry on timeout/connection errors. Answers are JSON-sanitized (no nulls / non-finite numbers) before PUT.
- **Income (1040)** maps paper-form intake via `organizer_income_forms_step.dart` + `organizer_income_math.dart`: `w2Forms` (1a/25a), `form1099NEC`/`form1099K` (business), `form1099R` (4a–5b), `formSSA1099` (6a/6b), `form1099G` (Sch. 1 unemployment/refund), `form1099DA`/`form1099B` (Line 7), `form1099INT`/`form1099DIV` (2b/3a/3b). Do **not** surface IRS Free File line-by-line links in the UI. Form tiles are collapsed by default for faster section open.
- **Load-speed notes (Sanctum):** `POST .../tax-years/activate` already embeds `organizer` + `tasks` (~4–5s). Do **not** immediately chain `GET .../tasks` or `GET .../organizer` after activate — reuse `TaxYearState.organizerSnapshot` / embedded tasks. Snapshot is cleared after Organizer save so the next open re-fetches. Credits/State/Income heavy blocks use `OrganizerLazySection` (build on expand). Forms hub (`/forms`) paints from the warm workspace first; portal `/api/tax-returns` soft-enrichment is non-blocking (those routes 404 on the Laravel app host).
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

### Flutter web (staging DO)
- Platform folder: `web/` (enabled). Cookie jar uses in-memory storage on web (`cookie_jar_factory_web.dart`); Sanctum bearer tokens still use secure storage.
- Document upload uses `MultipartFile.fromBytes` (file_picker `withData: true`). Portal cookie download on web opens the portal vault instead of writing a temp file.
- **Live DO app:** `mkg-tax-mobile-web` → `https://mkg-tax-mobile-web-9rbiq.ondigitalocean.app` (App ID `65d2c864-ed24-4afd-8563-1d749d5a9205`). Spec: `.do/app.yaml` + `Dockerfile`. **Not** `financemkgtax-app` / Laravel API app.
- Health: `GET /health` → `ok`. Redeploy: `doctl apps create-deployment 65d2c864-ed24-4afd-8563-1d749d5a9205 --force-rebuild` (`deploy_on_push: false`).
- Laravel `CORS_ALLOWED_ORIGINS` on staging must include that origin (plus optional `http://127.0.0.1:8088` for local static smoke).
- Build: `flutter build web --release` with staging dart-defines (see README / `docs/toolchain-versions.md`). Local: `python3 -m http.server 8088 -d build/web` then `/` and `/#/banking`.
- Manual CI: copy `docs/staging-web.workflow.yml.example` → `.github/workflows/staging-web.yml` (PAT needs `workflow` scope). Also see Vercel web deploy docs under `docs/deployment/` / `docs/vercel-web-deploy.md` if using that path.


### Mobile login / Play Internal testers
- Signup is **disabled** on Sanctum production builds (`usesLaravelAuth` / `MOBILE_REGISTRATION_ENABLED=false`).
- Login requires portal S2S (`FINANCEMKGTAXPRO_*` ↔ portal `MOBILE_SERVICE_CLIENT_*`). If Laravel logs show `[financemkgtaxpro-bridge] ... authenticate ... unauthorized`, fix **duplicate** `MOBILE_SERVICE_CLIENT_ID`/`SECRET` on the DigitalOcean `financemkgtaxpro` app (keep plain ID + first secret only), then retest.
- Designated testers: Marsh `mkgtax@gmail.com`, Erin `erin.mkgtax@gmail.com` (must be portal **client** users: active + approved + email verified; TOTP off or OTP UI required).

### Commands
- Deps: `flutter pub get` (refresh pub.dev plugins after pull)
- Analyze: `flutter analyze`
- Schema tests: `flutter test test/organizer_schema_test.dart`
- Hot Reload dev: `flutter run` then `r` (reload) / `R` (restart)
- Debug APK: `flutter build apk --debug`
- Staging web: `flutter build web --release` (+ dart-defines in README)
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
