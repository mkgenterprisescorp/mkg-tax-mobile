# API Gap Analysis

**Purpose:** Compare what Flutter calls today, what `mkg-tax-backend-2` exposes, and what financemkgtaxpro provides — so Phase 1+ work closes gaps without inventing parallel systems.

**Constraints:** Flutter never talks to Neon. No production DNS/system changes in this design phase.

---

## 1. Current Flutter networking model

| Client | Config | Used for |
|--------|--------|----------|
| `ApiClient` + cookie jar | `API_BASE_URL` (default historically `https://financemkgtax.com`) | Portal REST under `/api/*` |
| `LaravelApiClient` + bearer | Sanctum token when `usesLaravelAuth` | Intended `/api/mobile/tax-years/*` and Sanctum `/auth/*` |
| Staging target | `API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1` | Sanctum mobile API |

**Gap:** Flutter’s tax-year repository still targets `/api/mobile/tax-years/...`, which **does not exist** on `mkg-tax-backend-2` (which uses `/api/v1/...`). Auth paths also differ (`/auth/login` vs `/api/v1/auth/login` depending on how `API_BASE_URL` is stripped). Contract alignment is a Phase 1 prerequisite.

---

## 2. Laravel `mkg-tax-backend-2` — live routes (staging)

| Method | Path | Status |
|--------|------|--------|
| GET | `/api/v1/health` | Live |
| GET | `/api/v1/app-version` | Live |
| POST | `/api/v1/auth/login` | Live (mock or fail-closed bridge) |
| POST | `/api/v1/auth/logout` | Live |
| GET | `/api/v1/me` | Live |
| POST/GET/DELETE | `/api/v1/devices...` | Live |
| POST/DELETE | `/api/v1/push-token...` | Live |
| POST/GET | `/api/v1/security-events` | Live |
| POST | `/api/v1/telemetry` | Live |
| POST | `/api/v1/sync/status` | Live (metadata only) |

**Tables owned (mobile-only):**  
`mobile_identity_anchors`, `personal_access_tokens`, `mobile_devices`, `push_tokens`, `mobile_sessions`, `app_version_policy`, `offline_sync_metadata`, `mobile_security_events`, `mobile_audit_events`, `mobile_telemetry`

---

## 3. Flutter → portal (`financemkgtax.com`) calls still in use

These power most operational mobile flows on the transitional branch:

| Area | Endpoints (representative) |
|------|----------------------------|
| Auth | `POST /api/login`, `GET /api/auth/user`, `POST /api/register`, forgot/reset, logout |
| Tax returns / organizer | `GET/POST/PUT /api/tax-returns`, `/current`, `/all`, toggle-lock |
| Documents | `GET .../documents`, `POST /api/documents/upload`, download/secure-download |
| Clients / bureau | `GET /api/clients/list`, `/api/bureau/ero-efin`, `/api/bureau/preparers` |
| KYC | `/api/user/verification-status`, `kyc-submit`, `ssn`, profile |
| Loans | `POST /api/loans/calculate`, `/apply` |
| Billing | `GET /api/invoicing/invoices` |
| Chat / AI | `/api/chat/rooms...`, `/api/conversations...` |

**Gap:** These are **not** implemented on `mkg-tax-backend-2`. Target architecture either:

1. Adds Laravel domain APIs + adapters that proxy/authorize against web services, or  
2. Keeps temporary dual-client Flutter until cutover (explicit tech debt).

Preferred long-term: (1) with thin controllers and Integration adapters — **no** second users/tax_returns schema that duplicates portal PII without an approved ownership move.

---

## 4. Target `/api/v1` groups vs today

| Group | Flutter need | Laravel today | Gap |
|-------|--------------|---------------|-----|
| `/auth`, `/me`, `/devices` | High | Present | Align path + Flutter client; expand MFA hooks |
| `/clients`, `/entities` | High | Absent | Phase 1 |
| `/tax-years` | High | Absent (Flutter expects `/api/mobile/tax-years`) | Phase 1 — rename Flutter to `/api/v1/tax-years` |
| `/organizers` | High | Absent | Phase 2 (orchestration; storage strategy TBD) |
| `/states` | High | Absent | Phase 3 |
| `/documents` | High | Absent | Phase 3 (signed URLs + AuthZ) |
| `/tasks` | Medium | Absent | Phase 3 |
| `/messages`, `/notifications` | High | Absent (push token only) | Phase 5 |
| `/payroll-calculations`, `/w4-estimates` | High | Absent | Phase 4 |
| `/invoices`, `/payments` | Medium | Absent | Phase 5 adapters |
| `/banking-connections` | Low (prep) | Absent | Phase 6 interfaces only |
| `/security-events` | Medium | Present | Expand taxonomy |

---

## 5. Auth bridge gap

| Mode | Behavior | Gap |
|------|----------|-----|
| `MOBILE_AUTH_MODE=mock` | Local/staging only; refuses production | OK for staging device tests |
| `MOBILE_AUTH_MODE=financemkgtaxpro` | Calls `POST /internal/mobile-identity/authenticate` | **Endpoint not built on financemkgtaxpro** → fail closed (503) |

**Do not** invent a duplicate portal user system on Laravel to bypass this.

---

## 6. Contract mismatches to fix in Phase 1 (docs → tickets)

1. **Base path consistency:** Flutter Sanctum calls must hit `/api/v1/auth/*` when `API_BASE_URL` ends with `/api/v1`.
2. **Tax-year path rename:** `/api/mobile/tax-years` → `/api/v1/tax-years` (or versioned alias with deprecation).
3. **UUID public IDs:** New Laravel resources use UUIDs; portal currently uses numeric return IDs — adapters must map carefully.
4. **Error envelope:** Agree structured `{ code, message, details? }` for Flutter parsing.
5. **Idempotency-Key** header for payments and document finalize operations.
6. **OpenAPI** published from Laravel; Flutter contract tests consume it.
7. **Pagination:** `?page=&per_page=` (or cursor) for collections.

---

## 7. Adapter strategy (shared domains)

Until product approves data-ownership moves:

```text
Flutter → Laravel Policy + Application Service → Integration Adapter
                                                      ↓
                                         financemkgtaxpro S2S / provider API
```

Adapters required (named interfaces, implementations later):

- `IdentityBridgeAdapter` (exists as HttpIdentityClient stub)
- `TaxReturnAdapter` / `OrganizerAdapter`
- `DocumentStorageAdapter`
- `MessagingAdapter` / `AiAssistantAdapter`
- `InvoiceAdapter` / `PaymentCheckoutAdapter`
- `LoanEstimateAdapter` (Pathward)
- `BankingProviderAdapter` (Phase 6 — no money movement)

---

## 8. Explicit non-APIs

Do **not** expose from Laravel mobile API:

- Direct Neon SQL or admin DB routes
- Raw document bytes in JSON
- Card/bank credentials
- E-file submission controls for unauthenticated clients
- Banking money-movement endpoints before partner approval

---

## 9. Testing implications (for later phases)

- Feature tests per new route group
- Policy isolation: client A cannot read client B entity/tax-year/docs
- Contract tests: Flutter repository fixtures vs OpenAPI
- No real client data in fixtures

See also: [`implementation-roadmap.md`](./implementation-roadmap.md), [`security-and-compliance-boundaries.md`](./security-and-compliance-boundaries.md).
