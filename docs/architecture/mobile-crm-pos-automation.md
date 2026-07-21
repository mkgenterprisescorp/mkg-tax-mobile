# Mobile CRM + POS + automation / workflow triggers

**Status:** Product-role SoT (owner clarification)  
**Repos:** `mkg-tax-mobile` (client), `mkg-tax-backend-2` (orchestration), `financemkgtaxpro` (Stripe / staff / MeF)

## Role

The Flutter app is the primary **CRM** and **POS** experience for MKG clients and field staff, and the primary channel that **delivers automation and workflow triggers** to:

| Audience | Examples |
|----------|----------|
| **New users** | Signup → Technology Access checkout → onboarding checklist → first organizer / document intake → first payment |
| **Existing users** | Grace window → renew Technology Access → document chase → prep milestones → payment reminders → renewals |

Automation **policy and entitlement** (including the \$2.50/mo Technology Access subscription) live on the **portal** (`financemkgtaxpro`). Flutter **surfaces** triggers and CRM/POS actions; Laravel **orchestrates** delivery (push, tasks, deep links). Flutter never holds Stripe secret keys or invents entitlement truth.

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
