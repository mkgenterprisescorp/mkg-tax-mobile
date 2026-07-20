# Monorepo migration plan (preferred layout)

The preferred long-term layout for `mkg-tax-mobile` is:

```text
mkg-tax-mobile/
├── apps/
│   ├── web/           ← preferred Vercel Root Directory
│   ├── mobile/        ← Flutter iOS/Android SoT
│   └── legacy-ios/    ← historical Swift runner (outside Vercel)
├── services/
│   └── tax-api/       ← optional thin clients/docs only; engines stay on DO Laravel
├── packages/
│   ├── shared-models/
│   └── shared-ui/
├── tax-engines/       ← must remain server-side / not in Vercel output
│   ├── federal/
│   └── states/
├── database/
│   └── migrations/    ← Neon via backend CI only
└── .github/workflows/
```

## Current state

This repository is a **single Flutter project at the repo root**:

- Web target: `web/` + shared `lib/`
- Mobile runners: `ios/`, `android/`
- No `apps/`, `packages/`, `tax-engines/`, or `database/` trees
- Tax engines and Neon migrations live in sibling Laravel repos on DigitalOcean

## Rule

**Do not move files automatically** merely to satisfy the preferred layout.
Vercel Root Directory today must be **`.`** (Flutter project root). After an
approved migration, Root Directory becomes **`apps/web`**.

## Suggested phased migration (manual / separate PRs)

1. **Document only (this phase)** — scope scripts, ignore-build, CI gates, Vercel project settings for the Flutter root.
2. **Extract packages** — move shared Dart models/UI into `packages/` without changing runtime behavior.
3. **Split apps** — `apps/mobile` (Flutter) and optionally `apps/web` if the taxpayer web UI becomes a separate Vite/Next app *or* a Flutter Web package with its own `pubspec`.
4. **Never place** `tax-engines/`, `database/migrations/`, certificates, or MeF material under the Vercel root or into the browser bundle.
5. Update `scripts/vercel-ignore-build.sh` and `vercel.json` Root Directory to `apps/web` only when that directory exists and owns the production web build.

Until step 3 completes, treat `lib/` + `web/` + `assets/` as the web application surface for Vercel path filters.
