#!/usr/bin/env bash
# Build the Flutter Web artifact for Vercel (Framework preset: Other).
#
# Prefer GitHub Actions + `vercel deploy --prebuilt` when possible — Vercel
# does not ship a Flutter SDK. This script is for the Vercel Git-integration
# path when Flutter has been installed in the build environment.
#
# Public dart-defines only. Never pass Neon, MeF, encryption, or S2S secrets.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://api.finance.mkgtaxconsultants.com/api/v1}"
LARAVEL_API_BASE_URL="${LARAVEL_API_BASE_URL:-https://api.finance.mkgtaxconsultants.com}"
WEB_BASE_URL="${WEB_BASE_URL:-https://finance.mkgtaxconsultants.com}"
APP_NAME="${APP_NAME:-MKG Tax Consultants}"
APP_ENV="${APP_ENV:-production}"

# Guard: refuse known secret env names if someone accidentally exports them.
for banned in DATABASE_URL NEON_DATABASE_URL PGPASSWORD IRS_MEF_PRIVATE_KEY \
  SSN_ENCRYPTION_KEY TAXPAYER_ENCRYPTION_KEY STRIPE_SECRET_KEY SENDGRID_API_KEY \
  JWT_PRIVATE_KEY APP_KEY; do
  if [[ -n "${!banned:-}" ]]; then
    echo "build-vercel-web: refusing to build — prohibited env is set: $banned" >&2
    exit 1
  fi
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "build-vercel-web: flutter not on PATH. Install Flutter or use GitHub Actions prebuilt deploy." >&2
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
