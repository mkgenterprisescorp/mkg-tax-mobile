# Figma design source of truth

- **File:** [tax-filling-app-v2](https://www.figma.com/design/7qoVoDkkHlANDeXChDESSK/tax-filling-app-v2?node-id=19-2&t=AKGTVqjY25mXMaQi-1)
- **File key:** `7qoVoDkkHlANDeXChDESSK`
- **Entry node:** `19:2`
- **Access:** link viewable without login (confirmed)

## Extracted tokens (visual sampling)
- Primary blue: `#007AFF` (NEXT / SUBMIT / headers)
- Background: white / `#F5F7FA`
- Pages: `ui design`, `ui-old`, `UI STATUS`, `splashes`

## Flows mirrored in Flutter (partial)
| Figma | Flutter route |
|-------|---------------|
| Splash / onboarding-wel | `/splash`, `/onboarding` |
| Login / register | `/login`, `/register` → API financemkgtax.com |
| Consent to Use / Disclose | `/organizer` steps 1–2 |
| Schedule A medical / taxes / contributions | `/organizer` steps 3–4 |
| SUBMIT | PUT `/api/tax-returns/:id` with `data.mobileOrganizer` |

## Still outstanding vs full Figma canvas (~50+ frames)
TILA disclosure, borrower signatures, full client data sheet, upload-doc-1, plan cards, filing status drawer, etc.

Optional: set secret `FIGMA_TOKEN` for precise Dev Mode inspect / PNG export via API.
