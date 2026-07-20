# Flutter performance playbook — MKG Tax

**Stack:** Flutter (iOS/Android/Web) + Laravel + Neon + DigitalOcean + Vercel  
**Goal:** Keep the app feeling responsive as federal forms, 50-state engines,
business returns, and AI/Tessa workflows grow.

Slow screens are usually a mix of oversized widgets, unnecessary rebuilds,
synchronous initialization, inefficient network requests, and accumulated
legacy code — not a single magic fix.

Related: [tessa-multi-agent.md](../tessa-multi-agent.md),
[api-client-strategy.md](../api-client-strategy.md),
[deployment/vercel-scope.md](../deployment/vercel-scope.md).

## High-impact improvements

### 1. Flutter DevTools (highest priority)

Every performance effort starts with profiling — do not guess.

Measure:

- Widget rebuild counts
- Frame rendering (60/120 FPS)
- Memory allocations
- CPU usage
- Network timing
- Shader compilation
- Startup time

### 2. Deferred (lazy) loading

Do **not** initialize every module at launch.

- Tax Organizer — only when selected
- State Tax Engine UI — after the user chooses a state
- Business Filing modules — when needed
- Mortgage features — when entered
- AI/Tessa — after the home screen is interactive

Prefer deferred imports / route-level loading where practical.

### 3. Riverpod optimization

This app uses `flutter_riverpod`. Audit providers for unnecessary rebuilds.

Prefer:

- `select()`
- `autoDispose`
- `AsyncNotifier`
- Provider families
- Fine-grained providers

Avoid large global providers that rebuild many widgets.

### 4. Clean up legacy artifacts

Remove over time (Codex/Cursor assisted, review carefully):

- Unused widgets / duplicate screens
- Deprecated services / old state management
- Unused assets / obsolete dependencies
- Dead routes / duplicate models
- Commented-out code

### 5. Network optimization

Common issues: duplicate calls, sequential work that could be parallel,
refetching unchanged data, large JSON, UI blocked on I/O.

Improvements:

- Parallelize independent requests
- Cache reference data (states, filing statuses, document types)
- Gzip/Brotli on Laravel responses
- Pagination where appropriate
- Offline/static caching for reference content
- Never call Neon/MeF from Flutter — stay on `/api/v1`

### 6. Image and asset optimization

- WebP where possible; SVG for icons
- Pre-cache only frequently used assets
- Defer illustrations / optional graphics
- Flag oversized images in Performance Guardian CI

### 7. Skeleton loading

Prefer skeleton placeholders over bare spinners so structure appears immediately.

### 8. Background work

Move off the UI isolate / to Laravel:

- OCR and tax form parsing
- Large JSON parsing
- PDF generation
- AI preprocessing

### 9. Reduce widget rebuilds

- `const` constructors
- Smaller widgets
- `RepaintBoundary` where it helps
- Keys only when necessary
- Split large screens into reusable components

### 10. Build optimization

- Tree shaking enabled
- Drop unreferenced packages
- Keep dependencies current (see `docs/toolchain-versions.md`)

## AI-assisted tools

| Tool | Best for |
|---|---|
| **Flutter DevTools** | Continuous measure/validate |
| **Codex** | Repo-wide cleanup, dead code, deps, CI, tests |
| **Cursor** | Guided Flutter refactor, modularization, Riverpod cleanup |

## Suggested audit phases

| Phase | Focus |
|---|---|
| **1 — Repository health** | Dead code, unused assets/packages, duplicate widgets, deps |
| **2 — Startup** | Lazy load, deferred imports, async/bg init, config cache |
| **3 — Screen performance** | Rebuilds, lists, transitions, skeletons |
| **4 — Networking** | Parallelism, cache, retry/backoff, compression, errors |
| **5 — Memory** | Dispose controllers, listener leaks, cache limits, heap |

## Target performance goals

| Metric | Target |
|---|---|
| Cold start | < 2.5 s |
| Warm start | < 1 s |
| Screen transition | < 300 ms |
| Initial dashboard render | < 500 ms |
| Tax organizer step change | < 200 ms |
| API response → cached UI update | < 150 ms after response |
| Memory after login | < 250 MB |
| Frame rate | Stable 60 FPS (120 where supported) |
| Janky frames | < 1% |

Treat these as **goals to measure**, not hard CI gates until baselines exist on
device and web. Bundle-size and analyze gates can fail PRs earlier.

**Web bundle note:** `build/web` with CanvasKit is typically ~45–55 MiB. The
Performance Guardian soft/CI ceiling is **60 MiB** (`MAX_WEB_BUNDLE_BYTES`) to
catch regressions, not to match a native APK size.

## Performance Guardian CI

On every relevant PR, automatically:

1. `flutter analyze --no-fatal-infos`
2. `flutter test`
3. Detect unused Dart files / assets (best-effort scripts)
4. Flag oversized images and web/APK bundles
5. Dependency health hints (`flutter pub outdated` summary)
6. Compare artifact size vs previous build when a baseline is present
7. Fail on agreed regressions (bundle size first; startup later once instrumented)

Workflow example (copy with a `workflow`-scoped token):

[`docs/deployment/performance-guardian.workflow.yml.example`](../deployment/performance-guardian.workflow.yml.example)

Local:

```bash
bash scripts/performance-guardian.sh
```

## What this does not change

- Authoritative tax math stays in Laravel engines (not Dart, not the LLM)
- Vercel hosts Flutter **web** companion only (prebuilt)
- Native camera, biometrics, push, store signing remain on Flutter/CI/Xcode/Play
