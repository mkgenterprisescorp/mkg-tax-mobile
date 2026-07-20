# Tessa multi-agent platform (Flutter view)

**SoT architecture:** sibling `mkg-tax-backend-2` →
`docs/architecture/multi-agent-tessa.md`

## What Flutter owns

- Single taxpayer chat entry for Tessa: `/tessa` (do **not** redirect `/chat` → `/tessa`)
- Capture interview answers, documents, and progress via Laravel `/api/v1`
- Display engine-backed estimates and statuses returned by the API
- Native only: camera, biometrics, push — never authoritative tax math

## What Flutter must not do

- Calculate authoritative federal/state liability in Dart
- Call IRS MeF, Neon, or portal S2S credentials directly
- Treat LLM text as filed amounts without an engine response id / audit trail

## Agent mesh (summary)

| Agent | Flutter touchpoint |
|---|---|
| Tessa | `/tessa` conversation UI |
| Federal / State | Organizer + Tax Center (API-driven) |
| Document Intelligence | Documents / upload / extraction review |
| Audit & Compliance | Validation banners, missing-item lists |
| Planning | Advisory surfaces (clearly labeled non-filing) |
| Mortgage Readiness | Banking / financial readiness flows |
| Customer Success | Notifications, reminders, doc requests |
| Workflow Orchestrator | Server-side only |
| Identity & Fraud | KYC / soft-gate screens; rules-first |

## Continuity

Same Sanctum account + Neon records across:

iPhone → Vercel desktop web → documents → back to mobile

See also: [api-client-strategy.md](api-client-strategy.md),
[deployment/vercel-scope.md](deployment/vercel-scope.md).
