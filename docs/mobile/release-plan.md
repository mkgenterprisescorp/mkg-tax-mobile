# Release Plan

1. Scaffold (this branch)
2. Auth + MFA against Laravel
3. Organizer + documents
4. Billing
5. Bookkeeping + Tessa
6. Store submission after UAT + security review

## Production distribution (2026-07-20)

- API: `https://app.mkgtaxconsultants.com/api/v1` only.
- Build APK/AAB on CI/build machine — not DigitalOcean App Platform Web Service.
- Marketing download page is WordPress (`www`) linking to owner-approved GitHub Release metadata.
- See `docs/deployment/PRODUCTION_APK_GATES.md`. Promotion and production signing are **blocked** until backend promote-in-place gates pass.
