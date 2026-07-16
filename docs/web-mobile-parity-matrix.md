# Web ↔ Mobile Parity Matrix

**Inventory date:** 2026-07-16  
**Sources of truth inspected:**
- Flutter: `mkgenterprisescorp/mkg-tax-mobile` @ `cursor/unified-flutter-web-parity-f489`
- Laravel: `mkgenterprisescorp/mkg-tax-backend-2` (mobile scaffold + staging)
- Web: `financemkgtaxpro` client portal

**Legend**

| Status | Meaning |
|--------|---------|
| **Existing** | Present and usable for the channel |
| **Partial** | UI and/or subset of APIs; gaps vs web or target architecture |
| **Missing** | Required for mobile platform; not implemented |
| **Web-only** | Intentionally not a mobile client priority (or staff/ops only) |
| **Provider-dependent** | Needs approved third-party / regulated partner |

Do **not** implement feature work until this matrix is reviewed (Phase 0 gate).

---

## Identity & access

| Capability | Web | Flutter | Laravel mobile API | Status | Notes |
|------------|-----|---------|--------------------|--------|-------|
| Email/password login | Existing | Existing (portal cookie default; Sanctum when `/api/v1`) | Existing (mock / bridge) | Partial | Staging uses Sanctum mock; production bridge fails closed until financemkgtaxpro service-auth exists |
| Register | Existing | Existing (portal only) | Missing | Partial | Sanctum register not enabled |
| Logout / session revoke | Existing | Existing | Existing (token + mobile_sessions) | Partial | Device revocation exists; MFA session model still MFA-ready only |
| Google OAuth | Existing | Missing | Missing | Web-only / Provider-dependent | Defer unless product requires |
| TOTP 2FA | Existing (staff required) | Missing (portal login may block) | Missing (architecture reserved) | Partial | MFA-ready design; no mobile TOTP UX yet |
| Device registration | N/A | Partial (not primary UX on cookie path) | Existing | Partial | Wire Flutter devices UI to Laravel when on Sanctum |
| Roles / permissions | Existing | Partial (consumer vs professional editions) | Claims cached on session | Partial | Entity-level policies not built |
| Audit / security events | Partial | Partial (client report path exists on API) | Existing tables/routes | Partial | Expand event taxonomy |
| Rate limiting | Existing | N/A | Existing on login | Existing | Extend per mutating domain |

## Client & entity management

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Individual profile | Existing | Partial (KYC/profile via portal) | Missing domain | Partial | Target: clients module on Laravel |
| Dependents | Existing (organizer) | Existing (organizer `dependents[]`) | Missing | Partial | Stored today in portal `tax_returns.data` |
| Multiple business entities | Existing (prepTypes / CRM) | Partial (prepType switch, not multi-entity graph) | Missing | Missing | Need entity hierarchy + permissions |
| Ownership / responsible parties | Partial | Missing | Missing | Missing | |
| Tax-year separation | Existing | Partial (selector + portal year returns) | Missing tax-year tables | Partial | Flutter has local/Laravel tax-year client stubs pointing at `/api/mobile/tax-years` (not on backend-2 yet) |
| My Clients / All Returns (staff) | Existing | Existing (portal APIs) | Missing | Partial / Web-only for deep CRM | Keep staff CRM web-first initially |

## Individual organizer

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Filing status / identity | Existing | Existing | Missing | Partial | Writes portal `tax_returns` |
| Dependents | Existing | Existing | Missing | Partial | |
| Income / W-2 forms | Existing | Existing | Missing | Partial | |
| Investments / crypto | Existing (interview) | Partial | Missing | Partial | Deepen vs web interview |
| Self-employment / Sch C | Existing | Existing | Missing | Partial | |
| Rental / Sch E | Existing | Existing (`rentalProperties[]`) | Missing | Partial | Standalone web `/schedule-e` shape differs |
| Retirement / education / healthcare | Existing | Partial | Missing | Partial | |
| Deductions / credits / Sch A | Existing | Partial | Missing | Partial | |
| Estimated payments | Existing | Partial | Missing | Partial | |
| Foreign activity | Existing | Partial | Missing | Partial | |
| Conditional branching engine | Existing (web interview) | Partial (prepType/step heuristics) | Missing | Missing | Server-driven rules target |
| Completion / change requests | Existing | Partial (completion heuristics) | Missing | Missing | Professional change-request workflow |
| Review & e-sign consents | Existing | Existing | Missing | Partial | |

## Business organizer

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Entity classification (1041/1065/1120/1120-S/990/990-EZ) | Existing | Existing (entity prepTypes + NestedMapEditor) | Missing | Partial | Shorter mobile entity flow |
| Ownership / EIN / formation | Existing | Partial | Missing | Partial | |
| Income/expenses / COGS / inventory | Existing | Partial | Missing | Partial | |
| Assets / depreciation | Existing | Partial | Missing | Partial | |
| Payroll & contractors (intake Qs) | Existing (Qs only) | Partial | Missing | Partial | Not a payroll-run product |
| Loans / officer comp / basis | Existing | Partial | Missing | Partial | |
| Related parties / foreign | Existing | Partial | Missing | Partial | |
| State nexus / apportionment | Existing | Missing | Missing | Missing | Phase 3 |
| Financial statement uploads | Existing (docs) | Partial (doc type `business`) | Missing | Partial | |

## Federal / state intake

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Tax-year-versioned rules | Partial | Missing | Missing | Missing | No Flutter hard-coding of state tax rules |
| 50 states + DC | Partial (CA deep; others lighter) | Partial (CA 540 step) | Missing | Missing | |
| Resident / NR / part-year | Existing (CA interview) | Partial | Missing | Missing | |
| Multi-state allocation | Partial | Missing | Missing | Missing | |
| Business nexus questionnaire | Partial | Missing | Missing | Missing | |
| Local tax flags | Partial | Missing | Missing | Missing | |
| Extensions / estimates | Partial | Missing | Missing | Missing | |
| Professional review | Existing | Partial | Missing | Partial | |

## Documents

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Upload / list | Existing | Existing (portal) | Missing | Partial | Must move to signed-URL authZ model |
| OTP / secure download | Existing | Partial (fallback to web) | Missing | Partial | |
| Classification (W-2/1099/K-1) | Partial | Partial (type picker) | Missing | Partial | |
| Malware scanning | Existing (web pipeline claims) | N/A | Missing | Provider-dependent | |
| Encrypted object storage | Existing | N/A (bytes not stored in app DB) | Missing | Missing | |
| Retention / deletion policies | Partial | Missing | Missing | Missing | |
| Entity + tax-year AuthZ | Partial | Partial (year-scoped return) | Missing | Missing | |

## Payroll & W-4

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Paycheck calculator | Existing (`/paycheck-calculator`) | Missing | Missing | Missing | |
| W-4 / DE-4 worksheet | Existing (`/withholding-calculator`) | Missing | Missing | Missing | |
| Versioned tax tables | Partial (web) | Missing | Missing | Missing | Server-managed only |
| Employer cost estimate | Partial | Missing | Missing | Missing | |
| Disclaimers / no auto election | Existing | N/A | N/A | Required | |

## Messaging, tasks, notifications

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Secure staff/client chat | Existing | Existing (portal rooms) | Missing | Partial | |
| TESSA / AI assistant | Existing | Existing (portal conversations) | Missing | Partial / Provider-dependent | AI remains adapter |
| Tasks | Partial | Partial (Laravel tasks client stub) | Missing | Missing | |
| Push tokens | N/A | Missing UI | Existing API | Partial | |
| No PII in push previews | N/A | N/A | Required | Required | |
| Attachments on messages | Existing | Missing | Missing | Missing | |

## Payments & banking

| Capability | Web | Flutter | Laravel | Status | Notes |
|------------|-----|---------|---------|--------|-------|
| Invoice list / status | Existing | Existing (portal invoices) | Missing | Partial | Adapter target |
| Hosted Stripe/Square checkout | Existing | Web handoff | Missing | Provider-dependent | Do not replace prod processors without approval |
| Card/bank credential storage | Forbidden | Forbidden | Forbidden | Existing boundary | |
| Refund advance / Pathward | Existing (estimate UI) | Partial (calculate/apply portal) | Missing | Provider-dependent | |
| Bookkeeping intake | Existing | Stub screen | Missing | Partial | |
| Business banking (live) | Intake pages | Stub | Missing | Provider-dependent | Phase 6 interfaces only |
| Plaid linking | Existing | Deferred to web | Missing | Provider-dependent | |

## Platform / ops (explicitly web-only for mobile client)

| Capability | Status | Notes |
|------------|--------|-------|
| Softphone / WebRTC | Web-only | |
| IRS e-file ATS / ERO tooling | Web-only | |
| QuickBooks deep ops | Web-only | |
| Admin / white-label / site monitor | Web-only | |
| Virtual terminal staff POS | Web-only | |
| CRM campaigns | Web-only | |

---

## Summary counts (mobile-relevant rows)

Approximate classification of mobile-relevant capabilities above:

| Status | Rough share |
|--------|-------------|
| Existing (end-to-end on a channel) | Minority (auth scaffold, health, some Flutter↔portal flows) |
| Partial | Majority of client tax flows today |
| Missing | Entity graph, state engine, payroll/W-4, Laravel domain APIs, signed docs |
| Web-only | Staff/ops surfaces |
| Provider-dependent | Payments deep, banking, malware, AI, Pathward |

**Phase 0 exit criterion:** Product/engineering review of this matrix, then Phase 1 foundations only.
