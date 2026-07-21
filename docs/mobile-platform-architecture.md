# MKG Tax Mobile Platform Architecture

**Status:** Phase 0 design (documentation only — no migrations or feature code in this PR)  
**Repos:** `mkg-tax-mobile` (Flutter), `mkg-tax-backend-2` (Laravel mobile API), `financemkgtaxpro` (existing web)  
**Staging API:** `https://app.mkgtaxconsultants.com/api/v1` (`mkg-tax-backend-2-staging` on DigitalOcean; Neon for Laravel DB)  
**Base branch for this design PR:** `cursor/unified-flutter-web-parity-f489`

## 1. Objectives

Deliver a mobile-first client platform for:

- **CRM + POS** for clients and field workflows (lists, follow-ups, invoice/payment collection UX)
- **Automation + workflow triggers** for **new and existing users** (onboarding, renewals, document chase, prep milestones, Technology Access entitlement)
- Individual and business tax preparation
- Complete organizers (federal + state intake)
- Payroll calculators and W-4 guidance
- Documents, messaging, tasks, payments
- Future business banking services (architecture only until regulated partner approval)

Product-role detail: [`architecture/mobile-crm-pos-automation.md`](architecture/mobile-crm-pos-automation.md).

Flutter **never** connects to Neon. All data access is HTTPS through the Laravel mobile API (and authorized adapters to web/business services).

## 2. Topology

```text
Flutter (iOS/Android)  mkg-tax-mobile
        │  HTTPS + Sanctum bearer token
        ▼
Laravel mobile API     mkg-tax-backend-2  (/api/v1)
        ├── Mobile identity / devices / sessions
        ├── Organizer orchestration (target)
        ├── Tax-year workspaces (target)
        ├── Document authorization (target)
        ├── Payroll calculation service (target)
        ├── State-intake rules engine (target)
        ├── Audit / security events
        └── Adapters → authorized web / business services
                │
                ├── Neon PostgreSQL (Laravel DATABASE_URL only)
                ├── Encrypted object storage (document bytes)
                └── Approved providers (payments, push, banking partner, etc.)

financemkgtaxpro (web) remains SoT for many shared business domains until
explicit S2S adapters move ownership or proxy contracts are approved.
```

### Staging vs production

| Concern | Staging (current) | Production |
|---------|-------------------|------------|
| Laravel host | `app.mkgtaxconsultants.com` (DO app `mkg-tax-backend-2-staging`) | Not changed by this design work |
| Temporary DO URL | `mkg-tax-backend-2-staging-56eon.ondigitalocean.app` | N/A |
| Auth mode today | Sanctum + `MOBILE_AUTH_MODE=mock` (or bridge when ready) | Fail-closed without financemkgtaxpro service-auth bridge |
| Neon | Staging Laravel DB only | Untouched by mobile agents |
| DNS / other domains | Do not attach `app.mkgtaxconsultants.com` elsewhere; do not change apex/www/finance DNS | Untouched |

### Transitional Flutter auth (existing branch)

On `cursor/unified-flutter-web-parity-f489`, Flutter still supports:

1. **Portal cookie auth** when `API_BASE_URL` points at `financemkgtax.com` (legacy transitional path)
2. **Sanctum bearer** when `API_BASE_URL` contains `/api/v1` (target path for `app.mkgtaxconsultants.com`)

Target steady state for new modules: Sanctum only against `mkg-tax-backend-2`.

## 3. Core data hierarchy

```text
User (identity from financemkgtaxpro bridge → MobileIdentityAnchor)
└── Client profile
    ├── Individual taxpayer
    └── Business entities
        ├── Sole proprietorship / Schedule C
        ├── Single-member LLC
        ├── Partnership
        ├── S corporation
        ├── C corporation
        ├── Nonprofit
        └── Trust / estate
            └── Tax-year workspace
                ├── Federal organizer
                ├── State workspaces
                ├── Documents (metadata + storage keys)
                ├── Tasks
                ├── Messages
                ├── Payments (display / hosted flows)
                └── Filing status
```

**Hard rule:** `mobile_identity_anchors` is a Sanctum morph target (`external_user_id` only). It is **not** a duplicate portal `users` table and must never store name/email/SSN/profile PII.

## 4. Bounded modules

| # | Module | Owns | Does not own |
|---|--------|------|--------------|
| 1 | Identity & access | Sanctum tokens, devices, sessions, MFA-ready hooks, roles/claims cache, audit, rate limits | Portal password hashes, Google OAuth, staff TOTP secrets (remain on web until bridge) |
| 2 | Client & entity management (CRM) | Profiles, dependents, entities, ownership, entity permissions, tax-year separation, client follow-ups, automation trigger presentation | Staff-only blast campaign engine / softphone (web-first until APIs exist) |
| 3 | Individual organizer | 1040 sections, conditional branching, completion, change requests | Final e-file ATS |
| 4 | Business organizer | Entity classification through financial statement uploads | Live payroll run / banking money movement |
| 5 | Federal/state intake | Tax-year-versioned server rules, 50 states + DC, nexus, allocation | Hard-coded Flutter tax tables |
| 6 | Documents | AuthZ, signed URLs, classification, retention metadata | Document bytes in DB or Flutter offline store |
| 7 | Payroll & W-4 | Gross-to-net, withholding estimates, versioned tables, disclaimers | Automatic payroll election submission |
| 8 | Messaging / tasks / notifications | Threads, context, push tokens, read status | PII in push previews |
| 9 | Payments / POS | Invoice/status adapters, hosted checkout, POS-style pay UX, Technology Access deep link | Card/bank credentials; Stripe webhook SoT; replacing production processors without approval |
| 9b | Automation / workflows | Trigger inbox, deep links, task CTAs for new + existing users (entitlement-gated) | Inventing entitlement truth; running Stripe Billing in-app |
| 10 | Business banking | Provider-neutral interfaces, KYC/KYB/AML boundaries | Live money movement; representing MKG as a bank |

## 5. API conventions

- Base path: `/api/v1`
- JSON responses; UUID public identifiers for new domain resources
- Pagination for collections
- Idempotency keys for financial / mutating operations
- Form Request validation; Policy authorization
- Structured error codes (stable machine strings)
- Tax-year and entity context on every protected domain resource
- OpenAPI documentation; versioned contracts
- No PII or secrets in logs

### Recommended endpoint groups (target)

```text
/auth  /me  /devices
/clients  /entities  /tax-years
/organizers  /states  /documents
/tasks  /messages  /notifications
/payroll-calculations  /w4-estimates
/invoices  /payments
/banking-connections
/security-events
```

**Already live on staging Laravel (scaffold):**  
`/health`, `/app-version`, `/auth/login|logout`, `/me`, `/devices`, `/push-token`, `/security-events`, `/telemetry`, `/sync/status`

## 6. Flutter structure (target)

```text
lib/
├── app/
├── core/
│   ├── auth/
│   ├── config/
│   ├── networking/
│   ├── security/
│   └── storage/
└── features/
    ├── onboarding/
    ├── clients/
    ├── entities/
    ├── tax_years/
    ├── organizer/
    ├── states/
    ├── documents/
    ├── payroll/
    ├── w4/
    ├── messages/
    ├── tasks/
    ├── payments/
    └── banking/
```

**Rules:** UI widgets do not make raw HTTP calls. Repositories consume API clients. Sensitive tokens use platform secure storage. Offline storage excludes unnecessary PII and document contents.

**Current branch reality:** Feature modules exist under `lib/features/*` with a transitional `PortalRepository` + `LaravelApiClient` split. Target structure is an incremental refactor, not a big-bang rewrite.

## 7. Laravel structure (target)

```text
app/
├── Domain/
│   ├── Identity/
│   ├── Clients/
│   ├── Entities/
│   ├── TaxYears/
│   ├── Organizer/
│   ├── StateTax/
│   ├── Documents/
│   ├── Payroll/
│   ├── Messaging/
│   ├── Payments/
│   └── Banking/
├── Http/
│   ├── Controllers/Api/V1/
│   ├── Requests/
│   ├── Resources/
│   └── Middleware/
├── Policies/
├── Services/
└── Integrations/
```

**Rules:** Controllers stay thin. Business logic in domain/application services. External providers use adapter interfaces. Migrations must be additive and reversible. **Do not run staging or production migrations without explicit approval.**

**Current scaffold reality:** Identity/devices/sessions/audit/telemetry only; Domain folders above are planned.

## 8. Non-goals for Phase 0

- No migrations
- No feature-code changes
- No DigitalOcean / DNS / Neon / production changes
- No live banking
- No replacement of production payment processors
- No Flutter → Neon shortcuts

## 9. Related documents

- [`web-mobile-parity-matrix.md`](./web-mobile-parity-matrix.md) — inventory status per capability
- [`api-gap-analysis.md`](./api-gap-analysis.md) — Flutter calls vs Laravel routes vs web
- [`implementation-roadmap.md`](./implementation-roadmap.md) — Phases 0–6
- [`security-and-compliance-boundaries.md`](./security-and-compliance-boundaries.md) — hard boundaries
- Existing: `docs/mobile/financemkgtaxpro-integration.md`, `docs/mobile/security-model.md`, `docs/mobile/offline-storage-policy.md`
