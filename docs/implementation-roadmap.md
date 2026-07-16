# Implementation Roadmap

**Mode:** Incremental. Phase 0 is documentation-only (this PR).  
**Do not implement feature code until Phase 0 inventory is reviewed.**  
**Do not run staging/production migrations without explicit approval.**

---

## Phase 0 — Inventory (current)

**Deliverables**

- [x] `docs/mobile-platform-architecture.md`
- [x] `docs/web-mobile-parity-matrix.md`
- [x] `docs/api-gap-analysis.md`
- [x] `docs/implementation-roadmap.md`
- [x] `docs/security-and-compliance-boundaries.md`

**Exit criteria**

- Product + engineering review of parity matrix and API gaps
- Agreement on adapter vs ownership moves for tax returns / documents / chat
- Agreement that Flutter remains free of Neon and hard-coded state tax tables

---

## Phase 1 — Foundations

**Goals:** Client/entity hierarchy, tax-year workspace, authz, audit, API contracts.

**Laravel**

- Domain modules: Identity (extend), Clients, Entities, TaxYears
- Policies for client/entity/tax-year access + information barriers
- Align routes under `/api/v1` with OpenAPI skeleton
- Structured errors, pagination, UUID public IDs
- Expand audit events for login, device revoke, access denials
- Identity bridge: keep fail-closed; coordinate financemkgtaxpro S2S endpoint separately (out of scope unless approved)

**Flutter**

- Align Sanctum client paths with `/api/v1`
- Replace `/api/mobile/tax-years` expectations with `/api/v1/tax-years`
- Introduce `features/clients`, `features/entities`, `features/tax_years` repositories (no raw HTTP in widgets)
- Keep portal dual-client behind feature flag until cutover

**Tests**

- Auth feature tests (mock + production mock refusal)
- Policy isolation tests
- Flutter repository tests with mocked API

**Exit criteria:** Authenticated mobile client can select a tax year and see workspace shell from Laravel (even if organizer still adapter-backed).

---

## Phase 2 — Organizers

**Goals:** Individual + business organizers, conditional question engine, completion / change-request workflow.

**Laravel**

- Organizer domain + tax-year-versioned question graphs
- Orchestration API (`/organizers`) — persistence strategy via owned tables and/or TaxReturnAdapter
- Completion percentage server-authoritative
- Professional change-request workflow

**Flutter**

- Evolve existing organizer hub to consume server section schemas (progressive enhancement of current UI)
- Keep `default_form_data.json` only as offline bootstrap / fixture, not SoT

**Tests**

- Branching tests for prepType and income-driven sections
- Entity vs individual flow tests
- Cross-client isolation

**Exit criteria:** Personal and entity organizers save/load through Laravel contracts; Flutter does not embed business rules for section visibility beyond rendering server instructions.

---

## Phase 3 — States and documents

**Goals:** State residency/nexus intake, state workspaces, secure documents, tasks, filing status.

**Laravel**

- StateTax rules engine (50 + DC), versioned by tax year
- Document service: signed upload/download URLs, classification, malware scan hook, retention metadata
- Tasks API; filing status fields on tax-year workspace

**Flutter**

- `features/states`, deepen `features/documents`
- Never store document bytes offline; never log signed URL query secrets

**Tests**

- Document access denial across entity/tax-year
- State-rule version fixtures
- Task list AuthZ

**Exit criteria:** CA + at least one multi-state path driven by server rules; documents upload/download via signed URLs only.

---

## Phase 4 — Payroll

**Goals:** Paycheck calculator, W-4 worksheet, versioned calculation tables, authoritative fixtures.

**Laravel**

- `/payroll-calculations`, `/w4-estimates`
- Tax-year tables server-managed
- Estimate disclaimers; no automatic payroll election submission

**Flutter**

- `features/payroll`, `features/w4`
- Display-only results; clear estimate labeling

**Tests**

- Fixture vectors for federal/FICA and sample states
- Regression on table version bumps

**Exit criteria:** Mobile parity with web paycheck + W-4 tools for supported years, server-side only.

---

## Phase 5 — Communications and payments

**Goals:** Messages, notifications, invoice/payment display, hosted provider flows.

**Laravel**

- Messaging domain (or MessagingAdapter to web)
- Push dispatch using stored tokens; **no PII in notification previews**
- Invoice/Payment adapters; Idempotency-Key; webhook status updates
- Do **not** replace production payment processors without separate approval

**Flutter**

- `features/messages`, `features/tasks`, `features/payments`
- Hosted checkout via provider SDK / external page

**Tests**

- Thread participant isolation
- Webhook idempotency
- Push preview scrubbing unit tests

**Exit criteria:** Client can message staff in entity/tax-year context and view/pay invoices via hosted flow.

---

## Phase 6 — Banking preparation

**Goals:** Provider-neutral interfaces + compliance documentation only.

**Allowed**

- `BankingProviderAdapter` interface
- KYC/KYB/AML/sanctions workflow **boundaries** documented
- Account/transaction **display** contracts (read models) without live money movement

**Forbidden without separate approval**

- ACH/card money movement
- Storing banking credentials in Flutter
- Representing MKG as a bank
- Enabling live provider keys in staging/production casually

**Exit criteria:** Interfaces + compliance docs merged; no live banking actions.

---

## Cross-cutting engineering practices

| Practice | Rule |
|----------|------|
| Migrations | Additive + reversible; explicit approval before staging/prod apply |
| Controllers | Thin |
| Flutter HTTP | Repositories / API clients only |
| Secrets | Secure storage; never in git or logs |
| Dual stack | Portal cookie path is transitional tech debt with a cutover ticket |
| Production DNS / DO apps | Untouched by roadmap agents unless separately tasked |

---

## Suggested sequencing dependencies

```text
Phase 0 review
    → Phase 1 foundations (authz + tax-year + contracts)
        → Phase 2 organizers
            → Phase 3 states + documents (+ tasks)
                → Phase 4 payroll (can partially parallel Phase 3 after contracts stable)
                → Phase 5 messaging/payments (after identity + entity context)
                    → Phase 6 banking prep (anytime after Phase 1 for interfaces, but no live actions)
```
