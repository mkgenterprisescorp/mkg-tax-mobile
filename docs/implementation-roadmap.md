# Implementation Roadmap

**Mode:** Incremental. Phases 0–6 are implemented in code on this branch (docs + Laravel domain + Flutter `/api/v1` clients).  
**Do not run staging/production migrations without explicit approval.**

---

## Phase 0 — Inventory

**Deliverables**

- [x] `docs/mobile-platform-architecture.md`
- [x] `docs/web-mobile-parity-matrix.md`
- [x] `docs/api-gap-analysis.md`
- [x] `docs/implementation-roadmap.md`
- [x] `docs/security-and-compliance-boundaries.md`

---

## Phase 1 — Foundations

**Status:** Implemented (Laravel + Flutter clients). Staging migrate/deploy still requires approval.

- [x] Laravel clients/entities/tax-years + ownership checks + `/api/v1` contracts
- [x] Flutter Sanctum paths (`/me`, `identifier` login)
- [x] Replace `/api/mobile/tax-years` with `/api/v1/tax-years` + entity activate
- [x] `features/clients`, `features/entities` repositories; portal dual-client retained

---

## Phase 2 — Organizers

**Status:** Implemented (server catalog + completion; Flutter Laravel path progressive).

- [x] Laravel organizer domain + section catalog, SSN strip, change-requests
- [x] Flutter `LaravelOrganizerRepository` + Sanctum load/save path
- [x] `default_form_data.json` remains offline bootstrap / portal fixture only

---

## Phase 3 — States and documents

**Status:** Implemented (metadata + signed URLs; no offline document bytes).

- [x] State rules catalog versioned by tax year
- [x] Document upload → object storage key + signed download
- [x] Tasks API on tax-year workspaces
- [x] Flutter `states`, `documents`, `tasks` repositories + Documents screen Sanctum path

---

## Phase 4 — Payroll

**Status:** Implemented (estimate-only).

- [x] `/payroll-calculations`, `/w4-estimates` + seedable tax tables
- [x] Flutter payroll tools screen (`/payroll-tools`)

---

## Phase 5 — Communications and payments

**Status:** Implemented (stubs/adapters; hosted checkout only).

- [x] Message threads + participant isolation
- [x] Notifications inbox stub (no PII in previews policy)
- [x] Invoice list + `Idempotency-Key` hosted checkout adapter
- [x] Flutter messages / notifications / invoices repositories + Billing checkout

---

## Phase 6 — Banking preparation

**Status:** Implemented (interfaces + stubs only — no live money movement).

- [x] `BankingProviderAdapter` + `NullBankingProvider`
- [x] Connection status + KYC begin stub
- [x] Flutter banking screen consumes stubs; compliance disclaimer shown

---

## Cross-cutting

| Practice | Rule |
|----------|------|
| Migrations | Additive + reversible; explicit approval before staging/prod apply |
| Flutter HTTP | Repositories / API clients only |
| Production DNS / DO apps | Untouched unless separately tasked |
| Live banking / card credentials | Forbidden |
