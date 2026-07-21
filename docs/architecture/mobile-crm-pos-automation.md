# Mobile CRM + POS + automation / workflow triggers

**Status:** Product-role SoT (owner clarification)  
**Repos:** `mkg-tax-mobile` (client), `mkg-tax-backend-2` (orchestration), `financemkgtaxpro` (Stripe / staff / MeF)

## Role

The Flutter app is the primary **CRM** and **POS** experience for MKG clients and field staff, and the primary channel that **delivers automation and workflow triggers** to:

| Audience | Examples |
|----------|----------|
| **New users** | Signup → Technology Access checkout → **tax document upload prompts** → first organizer / document intake → first payment |
| **Existing users** | Grace window → renew Technology Access → document chase → prep milestones → **Apr 15 / Oct 15 filing reminders** → renewals |
| **LLC / Corporation started** | Dense deadline notices at **3w / 2w / 1w / 3d / 48h / 24h / 8h** before the entity filing deadline (portal scheduler SoT) |

Automation **policy and entitlement** (including the \$2.50/mo Technology Access subscription) live on the **portal** (`financemkgtaxpro`). Flutter **surfaces** triggers and CRM/POS actions; Laravel **orchestrates** delivery (push, tasks, deep links). Flutter never holds Stripe secret keys or invents entitlement truth.

## Filing / document workflow triggers (portal SoT)

Portal owns SMS/email scheduling — see `financemkgtaxpro` `docs/filing-deadline-workflow-notices.md`:

| Trigger | Cadence |
|---------|---------|
| New-user tax document prompts | 1h, 1d, 3d, 7d after signup until a document is uploaded |
| April 15 / October 15 filing reminders | 21d, 14d, 7d, 3d before each deadline |
| LLC/Corp entity deadline notices (when return started) | 3w, 2w, 1w, 3d, 48h, 24h, 8h before Mar 15 (1065/1120-S), Apr 15 (1120), and Oct 15 extension |

Flutter should deep-link document prompts to Documents / smart intake and filing notices to Organizer / Tax Center. Do not invent a second deadline calendar in the APK.

## Boundaries

| Owns (mobile + Laravel façade) | Does not own |
|--------------------------------|--------------|
| Client CRM lists / cards / follow-ups (client-facing) | Full staff campaign blast engine until API exists |
| POS-style payment collection UX (hosted Stripe / invoice pay) | Card PAN / bank credential storage |
| Workflow trigger inbox, deep links, in-app CTAs | IRS MeF / ERO submit |
| Technology Access status display + deep link to portal checkout | Stripe webhook SoT / Price catalog |
| Task / notification presentation for new + existing users | Softphone / WebRTC staff ops |

## Related docs

- Platform architecture: [`../mobile-platform-architecture.md`](../mobile-platform-architecture.md)
- Parity matrix: [`../web-mobile-parity-matrix.md`](../web-mobile-parity-matrix.md)
- Portal Technology Access: `financemkgtaxpro` `docs/technology-access-subscription.md`
- Laravel entitlement notes: `mkg-tax-backend-2` `docs/architecture/technology-access-entitlement.md`
