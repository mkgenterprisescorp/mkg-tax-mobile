#!/usr/bin/env bash
# Build the Flutter Web artifact for Vercel (Framework preset: Other).
#
# PRIMARY path: GitHub Actions builds Flutter and runs
#   `vercel deploy --prebuilt`
# (see docs/deployment/vercel-web-deploy.workflow.yml.example).
#
# This script is a DOCUMENTED FALLBACK only. Vercel Git integration must NOT
# invoke it cold — Flutter is not on Vercel's default image. The script refuses
# to run unless ALLOW_VERCEL_NATIVE_FLUTTER_BUILD=1 is explicitly set after
# Flutter has been installed in the build environment.
#
# Public dart-defines only. Never pass Neon, MeF, encryption, or S2S secrets.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${ALLOW_VERCEL_NATIVE_FLUTTER_BUILD:-}" != "1" ]]; then
  cat >&2 <<'EOF'
build-vercel-web: refused.

GitHub Actions + `vercel deploy --prebuilt` is the only automatic deploy path.
Vercel must not cold-build Flutter (no Flutter SDK on the default image).

To use this fallback after installing Flutter in a custom build image:
  ALLOW_VERCEL_NATIVE_FLUTTER_BUILD=1 bash scripts/build-vercel-web.sh

See docs/deployment/vercel-scope.md
EOF
  exit 1
fi

# Verified live staging API (2026-07-20): app.mkgtaxconsultants.com
# Intended finance.* API hosts are NOT wired as defaults until DNS exists —
# staging-api.finance.mkgtaxconsultants.com and api.finance.mkgtaxconsultants.com
# currently do not resolve.
API_BASE_URL="${API_BASE_URL:-https://app.mkgtaxconsultants.com/api/v1}"
LARAVEL_API_BASE_URL="${LARAVEL_API_BASE_URL:-https://app.mkgtaxconsultants.com}"
WEB_BASE_URL="${WEB_BASE_URL:-https://finance.mkgtaxconsultants.com}"
APP_NAME="${APP_NAME:-MKG Tax Consultants}"
APP_ENV="${APP_ENV:-production}"

for banned in DATABASE_URL NEON_DATABASE_URL PGPASSWORD IRS_MEF_PRIVATE_KEY \
  SSN_ENCRYPTION_KEY TAXPAYER_ENCRYPTION_KEY STRIPE_SECRET_KEY SENDGRID_API_KEY \
  JWT_PRIVATE_KEY APP_KEY; do
  if [[ -n "${!banned:-}" ]]; then
    echo "build-vercel-web: refusing to build — prohibited env is set: $banned" >&2
    exit 1
  fi
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "build-vercel-web: flutter not on PATH." >&2
  exit 1
fi

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="LARAVEL_API_BASE_URL=${LARAVEL_API_BASE_URL}" \
  --dart-define="WEB_BASE_URL=${WEB_BASE_URL}" \
  --dart-define="APP_NAME=${APP_NAME}" \
  --dart-define="APP_ENV=${APP_ENV}"

echo "build-vercel-web: wrote ${ROOT}/build/web"
