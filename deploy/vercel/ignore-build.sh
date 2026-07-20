#!/usr/bin/env bash
# Vercel Ignored Build Step.
#
# Exit codes (Vercel convention):
#   0 = skip this deployment (no web-affecting changes)
#   1 = proceed with the build
#
# Important distinction: connecting this GitHub repo to Vercel gives Vercel
# permission to *read* the repository. That does NOT mean every file becomes
# a running Vercel service. What Vercel builds and publishes is controlled by:
#   - Root Directory
#   - Build Command
#   - Output Directory
#   - this Ignore Build Step
#
# Legacy iOS (`ios/`) remains in the repository for maintenance and migration,
# but it is intentionally NOT in the watch list below and is never compiled or
# published by Vercel. Same for `android/` and backend/tax-engine trees.

set -euo pipefail

# Paths that *do* affect the taxpayer-facing Flutter web UI.
WEB_PATHS=(
  lib
  web
  assets
  pubspec.yaml
  pubspec.lock
  deploy/vercel
  vercel.json
)

# Compare against the previous commit. If none of the web-affecting paths
# changed, skip — e.g. a commit that only touches ios/ or android/.
if git diff --quiet HEAD^ HEAD -- "${WEB_PATHS[@]}"; then
  echo "ignore-build: no web-affecting changes; skipping Vercel deploy."
  echo "ignore-build: ios/ (legacy), android/, and other non-web paths do not trigger a build."
  exit 0
fi

echo "ignore-build: web-affecting files changed; proceeding with build."
exit 1
