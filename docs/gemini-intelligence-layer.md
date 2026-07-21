# Gemini intelligence layer (Flutter notes)

Full SoT: **`mkg-tax-backend-2`** repository → `docs/architecture/gemini-intelligence-layer.md`.

## Hard rules for this app

- **Never** ship `GEMINI_API_KEY`, Vertex credentials, or GCP project secrets in the APK / web dart-defines.
- Document scan / smart intake calls Laravel only (`POST /api/v1/documents/{id}/extract`).
- Taxpayer confirms extracted fields in Flutter; Laravel validation + engines remain authoritative.
- Antigravity / Repo Maintainer agents are **dev-only** — not part of the taxpayer app.
- Tessa may guide and escalate; it must not submit MeF, sign returns, or override Laravel tax math.

## Existing UI to extend (do not fork)

- `/documents/smart-intake` — upload → extract → verify → apply
- `/tessa` — orchestrator chat (propose-only tools via Laravel)

## Phase 1 product focus

W-2 + major 1099 family via Laravel Gemini Document Processor (feature-flagged), then Tessa missing-document / status tools.
