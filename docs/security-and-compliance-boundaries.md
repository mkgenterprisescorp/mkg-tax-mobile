# Security and Compliance Boundaries

**Audience:** Mobile + Laravel engineers, security reviewers, compliance stakeholders  
**Scope:** `mkg-tax-mobile`, `mkg-tax-backend-2`, interactions with `financemkgtaxpro` and providers  
**Phase:** Design constraints (enforce in all later phases)

---

## 1. Hard architectural boundaries

| Boundary | Rule |
|----------|------|
| Neon | Flutter **never** receives `DATABASE_URL` or connects to Postgres. Only Laravel (and approved server jobs) use Neon. |
| Document bytes | Not stored in Flutter offline DB, not stored in ordinary Postgres text/bytea fields as primary storage. Use encrypted object storage + signed URLs. |
| Portal users | Do **not** create a duplicate `users` table with passwords/PII on `mkg-tax-backend-2`. Use `mobile_identity_anchors.external_user_id` + identity bridge. |
| Tax tables in Flutter | No hard-coded state tax / withholding tables in Dart. Server-versioned rules only. |
| Production systems | Do not change production DNS, DigitalOcean production apps, or production Neon from mobile platform design work. |
| Staging domain | `app.mkgtaxconsultants.com` is attached **only** to `mkg-tax-backend-2-staging`. Do not attach elsewhere. |
| Migrations | Additive and reversible. **No staging/production migrate without explicit approval.** |

---

## 2. Identity and access

### Sanctum

- Bearer personal access tokens only for native mobile (no cookie session dependency on Laravel for app clients).
- Tokens bind to `MobileIdentityAnchor`, not a local user profile row.
- Support session revocation (logout deletes token + deactivates `mobile_sessions`).
- Device registration and soft-revoke supported.

### Auth modes

| Mode | Allowed environments | Behavior |
|------|----------------------|----------|
| `mock` | local, staging | Deterministic test identities; **hard fail if `APP_ENV=production`** |
| `financemkgtaxpro` | staging/production when configured | S2S authenticate; **fail closed** if bridge URL/credentials missing or endpoint unavailable |

### MFA-ready

- Architecture must allow second factor without redesigning token ownership.
- Until mobile MFA ships, staff TOTP remains on web; Flutter must not silently downgrade staff security requirements.

### Authorization

- Policy checks on every protected resource.
- Client/entity/tax-year context required for domain resources.
- Information barriers: staff scopes must not leak cross-client data; client A cannot access client B.
- Rate limit authentication and sensitive mutations.

### Audit

- Append-only audit for login, logout, access denials, document access grants, payment intents, admin overrides.
- Security events from devices (jailbreak signals, token reuse suspicions) stored separately from product telemetry.
- **No PII or secrets in logs** (tokens, SSN, bank numbers, raw document contents, signed URL query strings).

---

## 3. Data classification

| Class | Examples | Handling |
|-------|----------|----------|
| Public | App version policy, health (non-detailed) | Cacheable carefully |
| Authenticated operational | Device list, sync metadata flags | Sanctum + ownership |
| Confidential PII | Name, email, phone, address | Server-side; minimize Flutter offline retention |
| Highly sensitive | SSN/ITIN, full account numbers, ID images | Encrypt at rest; signed short-TTL URLs; never in push previews or analytics |
| Regulated financial | Card/bank credentials, banking session secrets | **Never** stored by MKG Flutter or Laravel — provider vault only |

---

## 4. Documents

- Authorization before any signed URL issuance (entity + tax-year + role).
- Malware scanning hook before marking documents available to staff/clients.
- Classification labels (W-2, 1099, K-1, ID, etc.) as metadata.
- Retention and deletion policies server-enforced.
- OTP/secure-download patterns on web must not be bypassed by a weaker mobile path.

---

## 5. Organizer and tax data

- Organizer payloads may contain sensitive tax data — treat as confidential.
- Prefer server-side validation and branching; Flutter renders.
- Professional change requests must be authenticated and audited.
- Cross-year isolation: TY2024 data must not bleed into TY2025 workspace without explicit user/year context.

---

## 6. Payroll and W-4 estimates

- Calculations are **estimates** with mandatory disclaimers.
- No automatic payroll election submission from mobile.
- Versioned calculation tables; fixtures without real client data.
- Do not log full employee SSN in payroll estimate requests/responses.

---

## 7. Messaging and notifications

- Secure threads with explicit participants.
- Entity/tax-year context on threads.
- Push tokens stored for delivery; notification **previews must not include PII** (no names of dependents, SSNs, refund amounts with account numbers, etc.).
- Attachment access uses same document AuthZ rules.
- Read status recorded; message edits/deletes audited if supported.

---

## 8. Payments

- Display invoices and status through authorized adapters.
- Hosted payment pages or provider SDKs only.
- **Never** store card or bank credentials in MKG systems via mobile API.
- Idempotent payment actions (`Idempotency-Key`).
- Webhook-driven status with signature verification.
- **Do not replace** existing production payment processing without separate approval.

---

## 9. Business banking (Phase 6)

| Allowed now | Forbidden until regulated partner + approval |
|-------------|-----------------------------------------------|
| Provider-neutral interfaces | Money movement (ACH, push-to-card, wires) |
| Compliance workflow boundary docs | Storing banking login credentials in Flutter |
| Read-model display contracts | Representing MKG as a bank or FDIC insured institution |
| KYC/KYB/AML/sanctions **hooks** | Circumventing partner KYC |

---

## 10. Secure Flutter client practices

- Sanctum tokens in `flutter_secure_storage` (or platform Keychain/Keystore).
- Certificate validation always on — **never** bypass TLS for staging convenience.
- Prefer `app.mkgtaxconsultants.com` when cert is valid; otherwise temporary DO staging URL (still with TLS verify).
- Offline cache: drafts OK per `docs/mobile/offline-storage-policy.md`; exclude SSN, document bytes, raw tokens.
- No secrets in `--dart-define` beyond public base URLs.
- Release signing: staging may use existing debug-key release signing temporarily; production signing is a separate controlled process.

---

## 11. Threat notes (non-exhaustive)

| Threat | Mitigation |
|--------|------------|
| Stolen device | Short token TTL, remote revoke, app PIN/biometric later |
| Cross-client IDOR | Policies + UUID opacity + tests |
| Signed URL leakage | Short TTL, method-scoped signatures, audit on issue |
| Mock auth in production | Factory hard fail |
| Dual API confusion (portal vs Laravel) | Explicit cutover plan; feature flags; contract tests |
| Prompt injection via AI chat | Keep AI on adapter; never grant AI direct DB or payment tools |

---

## 12. Compliance documentation expectations (later phases)

Before live banking or expanded payment ownership:

- Data flow diagrams (Flutter → Laravel → Neon/storage/providers)
- Retention schedule
- Incident response contacts
- Vendor DPA checklist for each provider
- Explicit statement: MKG Tax Consultants / Finance Advisors are **not** a bank

---

## 13. Related docs

- [`mobile-platform-architecture.md`](./mobile-platform-architecture.md)
- [`web-mobile-parity-matrix.md`](./web-mobile-parity-matrix.md)
- [`api-gap-analysis.md`](./api-gap-analysis.md)
- [`implementation-roadmap.md`](./implementation-roadmap.md)
- `docs/mobile/security-model.md`
- `docs/mobile/offline-storage-policy.md`
- `mkg-tax-backend-2` `docs/data-ownership.md`, `docs/mobile-api-strategy.md`
