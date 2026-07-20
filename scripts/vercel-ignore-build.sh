#!/usr/bin/env bash
# Vercel Ignored Build Step for mkg-tax-mobile (Flutter Web).
#
# Exit codes (Vercel convention):
#   0 = skip this deployment
#   1 = proceed with the build
#
# STABLE POLICY: always skip Vercel Git cold-builds. Flutter is not on the
# default Vercel image; Git-triggered builds fail with BUILD_UTILS_SPAWN_1.
# Deploy only via scripts/deploy-vercel-web.sh or GitHub Actions
# `vercel deploy --prebuilt` (see docs/deployment/vercel-web-deploy.workflow.yml.example).
#
# Dashboard: gitProviderOptions.createDeployments should be "disabled".
# This script is belt-and-suspenders if Git deploy is re-enabled.

set -euo pipefail

echo "ignore-build: skipping Vercel Git build (prebuilt-only policy)."
echo "ignore-build: use scripts/deploy-vercel-web.sh or Actions --prebuilt."
echo "ignore-build: ios/, android/, tax engines, backend, and database stay outside Vercel."
exit 0
