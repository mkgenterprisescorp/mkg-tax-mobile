#!/usr/bin/env bash
# Stable Flutter Web → Vercel prebuilt deploy.
#
# Builds locally (or in CI), assembles Build Output API v3, then
# `vercel deploy --prebuilt`. Never relies on Vercel Git cold-builds.
#
# Required:
#   VERCEL_TOKEN
# Optional (defaults from deploy/vercel/project.json):
#   VERCEL_ORG_ID
#   VERCEL_PROJECT_ID
#
# Usage:
#   bash scripts/deploy-vercel-web.sh           # production
#   bash scripts/deploy-vercel-web.sh --preview # preview deployment
#   SKIP_BUILD=1 bash scripts/deploy-vercel-web.sh   # reuse build/web
#   SKIP_SMOKE=1 bash scripts/deploy-vercel-web.sh   # skip HTTP smoke

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PREVIEW=0
PROD_FLAG=(--prod)
for arg in "$@"; do
  case "$arg" in
    --preview) PREVIEW=1; PROD_FLAG=() ;;
    --prod) PREVIEW=0; PROD_FLAG=(--prod) ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "deploy-vercel-web: unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

PROJECT_JSON="$ROOT/deploy/vercel/project.json"
if [[ ! -f "$PROJECT_JSON" ]]; then
  echo "deploy-vercel-web: missing $PROJECT_JSON" >&2
  exit 1
fi

# Prefer env secrets; fall back to committed project link (org/project ids are not tokens).
if [[ -z "${VERCEL_ORG_ID:-}" ]]; then
  VERCEL_ORG_ID="$(python3 -c "import json; print(json.load(open('$PROJECT_JSON'))['orgId'])")"
  export VERCEL_ORG_ID
fi
if [[ -z "${VERCEL_PROJECT_ID:-}" ]]; then
  VERCEL_PROJECT_ID="$(python3 -c "import json; print(json.load(open('$PROJECT_JSON'))['projectId'])")"
  export VERCEL_PROJECT_ID
fi

if [[ -z "${VERCEL_TOKEN:-}" ]]; then
  echo "deploy-vercel-web: VERCEL_TOKEN is required" >&2
  exit 1
fi
if [[ -z "${VERCEL_ORG_ID:-}" || -z "${VERCEL_PROJECT_ID:-}" ]]; then
  echo "deploy-vercel-web: VERCEL_ORG_ID and VERCEL_PROJECT_ID are required" >&2
  exit 1
fi

# Persist link for Vercel CLI (gitignored .vercel/).
mkdir -p "$ROOT/.vercel"
python3 - <<PY
import json, os
link = {
  "orgId": os.environ["VERCEL_ORG_ID"],
  "projectId": os.environ["VERCEL_PROJECT_ID"],
}
with open("$ROOT/.vercel/project.json", "w") as f:
  json.dump(link, f, indent=2)
  f.write("\n")
print("deploy-vercel-web: linked orgId=%s projectId_len=%d" % (
  link["orgId"], len(link["projectId"])))
PY

# Verified live staging API (finance.* API DNS still pending).
API_BASE_URL="${API_BASE_URL:-https://app.mkgtaxconsultants.com/api/v1}"
LARAVEL_API_BASE_URL="${LARAVEL_API_BASE_URL:-https://app.mkgtaxconsultants.com}"
WEB_BASE_URL="${WEB_BASE_URL:-https://mkgtaxconsultants.com}"
APP_NAME="${APP_NAME:-MKG Tax Consultants}"
if [[ "$PREVIEW" -eq 1 ]]; then
  APP_ENV="${APP_ENV:-preview}"
else
  APP_ENV="${APP_ENV:-production}"
fi

# Cloud Agent / host shells often inject DATABASE_URL for unrelated Neon work.
# Unset banned vars for this process so they cannot leak into the browser build.
# Flutter only receives explicit --dart-define values below (public URLs only).
for banned in DATABASE_URL DB_URL NEON_DATABASE_URL NEON_SMOKE_DATABASE_URL \
  PORTAL_DATABASE_URL FINANCEMKGTAXPRO_DATABASE_URL PGPASSWORD IRS_MEF_PRIVATE_KEY \
  SSN_ENCRYPTION_KEY TAXPAYER_ENCRYPTION_KEY STRIPE_SECRET_KEY SENDGRID_API_KEY \
  JWT_PRIVATE_KEY APP_KEY DIGITALOCEAN_ACCESS_TOKEN; do
  if [[ -n "${!banned:-}" ]]; then
    echo "deploy-vercel-web: unsetting prohibited env for frontend build: $banned" >&2
    unset "$banned"
  fi
done

echo "deploy-vercel-web: verifying Vercel frontend scope"
bash "$ROOT/scripts/verify-vercel-scope.sh" "$ROOT"

if [[ "${SKIP_BUILD:-}" != "1" ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "deploy-vercel-web: flutter not on PATH" >&2
    exit 1
  fi
  echo "deploy-vercel-web: flutter analyze"
  # Info-level lints are pre-existing in this codebase; fail only on warnings/errors.
  flutter analyze --no-fatal-infos
  echo "deploy-vercel-web: flutter test"
  flutter test
  echo "deploy-vercel-web: flutter build web (APP_ENV=$APP_ENV)"
  flutter config --enable-web >/dev/null
  flutter pub get
  flutter build web --release \
    --dart-define="API_BASE_URL=${API_BASE_URL}" \
    --dart-define="LARAVEL_API_BASE_URL=${LARAVEL_API_BASE_URL}" \
    --dart-define="WEB_BASE_URL=${WEB_BASE_URL}" \
    --dart-define="APP_NAME=${APP_NAME}" \
    --dart-define="APP_ENV=${APP_ENV}"
else
  echo "deploy-vercel-web: SKIP_BUILD=1 — reusing existing build/web"
fi

if [[ ! -d "$ROOT/build/web" ]]; then
  echo "deploy-vercel-web: missing build/web" >&2
  exit 1
fi

echo "deploy-vercel-web: assembling .vercel/output"
rm -rf "$ROOT/.vercel/output"
mkdir -p "$ROOT/.vercel/output/static"
cp -a "$ROOT/build/web/." "$ROOT/.vercel/output/static/"
cp "$ROOT/deploy/vercel/config.json" "$ROOT/.vercel/output/config.json"

if ! command -v vercel >/dev/null 2>&1; then
  echo "deploy-vercel-web: installing vercel CLI via npx"
fi

echo "deploy-vercel-web: vercel deploy --prebuilt ${PROD_FLAG[*]:-}"
# Newer Vercel CLI may print JSON; prefer --format=url when available.
set +e
DEPLOY_RAW="$(npx --yes vercel@latest deploy --prebuilt "${PROD_FLAG[@]}" --token="$VERCEL_TOKEN" --yes --format=url 2>/tmp/vercel-deploy-stderr.log)"
deploy_rc=$?
set -e
if [[ "$deploy_rc" -ne 0 || -z "$DEPLOY_RAW" ]]; then
  DEPLOY_RAW="$(npx --yes vercel@latest deploy --prebuilt "${PROD_FLAG[@]}" --token="$VERCEL_TOKEN" --yes)"
fi
DEPLOY_URL="$(
  DEPLOY_RAW="$DEPLOY_RAW" python3 - <<'PY'
import json, os, re
raw = os.environ["DEPLOY_RAW"].strip()
url = None
if raw.startswith("http"):
    url = raw.split()[0]
else:
    try:
        data = json.loads(raw)
        url = (data.get("deployment") or {}).get("url") or data.get("url")
    except Exception:
        m = re.search(r"https://[^\s\"']+", raw)
        url = m.group(0) if m else None
if not url:
    raise SystemExit("deploy-vercel-web: could not parse deployment URL from CLI output")
if not url.startswith("http"):
    url = "https://" + url
print(url)
PY
)"
echo "deploy-vercel-web: deployed → $DEPLOY_URL"

# Prefer stable production alias when deploying prod (preview URLs may use SSO).
SMOKE_URL="$DEPLOY_URL"
if [[ "$PREVIEW" -eq 0 ]]; then
  SMOKE_URL="${PRODUCTION_ALIAS:-https://mkg-tax-mobile.vercel.app}"
fi

if [[ "${SKIP_SMOKE:-}" != "1" ]]; then
  # Alias DNS/edge can lag a few seconds after READY.
  for attempt in 1 2 3 4 5; do
    if bash "$ROOT/scripts/smoke-vercel-web.sh" "$SMOKE_URL"; then
      break
    fi
    if [[ "$attempt" -eq 5 ]]; then
      echo "deploy-vercel-web: smoke failed after retries" >&2
      exit 1
    fi
    echo "deploy-vercel-web: smoke not ready (attempt $attempt); retrying in 5s…"
    sleep 5
  done
fi

echo "deploy-vercel-web: OK"
echo "$DEPLOY_URL"
