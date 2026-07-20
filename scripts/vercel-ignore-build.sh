#!/usr/bin/env bash
# Vercel Ignored Build Step for mkg-tax-client-web (Flutter Web).
#
# Exit codes (Vercel convention):
#   0 = skip this deployment
#   1 = proceed with the build
#
# Connecting GitHub to Vercel grants *read* access only. What is built and
# published is controlled by Root Directory, Build Command, Output Directory,
# and this Ignore Build Step — not by the mere presence of ios/, android/,
# tax engines, or backend trees in the same repository.
#
# Excluded from Vercel (never trigger a rebuild):
#   ios/  android/  apps/mobile/  apps/legacy-ios/
#   backend/  services/tax-api/  tax-engines/  database/
#   storage/  certificates/  private/  secrets/  infrastructure/  docs/

set -euo pipefail

# Paths that affect the taxpayer-facing Flutter web UI in the *current* layout
# (repo root Flutter project — not yet apps/web). See
# docs/deployment/monorepo-migration-plan.md for the long-term layout.
WEB_PATHS=(
  "lib/"
  "web/"
  "assets/"
  "pubspec.yaml"
  "pubspec.lock"
  "vercel.json"
  "deploy/vercel/"
  "scripts/build-vercel-web.sh"
  "scripts/vercel-ignore-build.sh"
)

PREV="${VERCEL_GIT_PREVIOUS_SHA:-}"
CURR="${VERCEL_GIT_COMMIT_SHA:-}"

if [[ -z "$PREV" || -z "$CURR" ]]; then
  # Local dry-run / first deploy / missing Git metadata → build (safe default).
  if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
    PREV="$(git rev-parse HEAD^)"
    CURR="$(git rev-parse HEAD)"
  else
    echo "ignore-build: no previous SHA available; proceeding with build."
    exit 1
  fi
fi

for path in "${WEB_PATHS[@]}"; do
  if ! git diff --quiet "$PREV" "$CURR" -- "$path"; then
    echo "ignore-build: relevant web change detected: $path"
    exit 1
  fi
done

echo "ignore-build: no Vercel web changes detected. Skipping deployment."
echo "ignore-build: ios/, android/, tax engines, backend, and database paths are outside scope."
exit 0
