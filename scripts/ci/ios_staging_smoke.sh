#!/usr/bin/env bash
# Live staging API smoke gates before signing / TestFlight upload.
# Uses only public staging HTTPS endpoints. Never prints tokens or passwords.
set -euo pipefail

API_BASE="${STAGING_API_BASE_URL:-https://app.mkgtaxconsultants.com/api/v1}"
API_BASE="${API_BASE%/}"

echo "Staging smoke against: ${API_BASE}"

if [[ "${API_BASE}" != https://* ]]; then
  echo "::error::STAGING_API_BASE_URL must be https://"
  exit 1
fi

code="$(curl -sS -o /tmp/ios-smoke-health.json -w '%{http_code}' \
  --max-time 30 "${API_BASE}/health")"
echo "GET /health -> ${code}"
if [ "${code}" != "200" ]; then
  echo "::error::Expected /health 200, got ${code}"
  exit 1
fi

code="$(curl -sS -o /tmp/ios-smoke-app-version.json -w '%{http_code}' \
  --max-time 30 "${API_BASE}/app-version")"
echo "GET /app-version -> ${code}"
if [ "${code}" != "200" ]; then
  echo "::error::Expected /app-version 200, got ${code}"
  exit 1
fi

# Invalid login must be a controlled 401 (not 500).
code="$(curl -sS -o /tmp/ios-smoke-login.json -w '%{http_code}' \
  --max-time 30 \
  -X POST "${API_BASE}/auth/login" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"identifier":"ios-ci-invalid@example.invalid","password":"definitely-not-a-real-password"}')"
echo "POST /auth/login (invalid) -> ${code}"
if [ "${code}" != "401" ]; then
  echo "::error::Expected invalid login 401, got ${code}"
  if [ "${code}" = "500" ]; then
    echo "::error::Unexpected HTTP 500 on invalid login"
  fi
  exit 1
fi

# Light 429 probe — stop after first 429 or after a small bounded set of attempts.
got_429=0
for i in 1 2 3 4 5 6; do
  code="$(curl -sS -o /tmp/ios-smoke-rl.json -w '%{http_code}' \
    --max-time 30 \
    -X POST "${API_BASE}/auth/login" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "{\"identifier\":\"ios-ci-rate-${i}@example.invalid\",\"password\":\"definitely-not-a-real-password\"}")"
  echo "rate-probe ${i} -> ${code}"
  if [ "${code}" = "500" ]; then
    echo "::error::Unexpected HTTP 500 during rate probe"
    exit 1
  fi
  if [ "${code}" = "429" ]; then
    got_429=1
    break
  fi
done
if [ "${got_429}" -ne 1 ]; then
  echo "::warning::Did not observe 429 within bounded probes (environment rate limits may differ). Continuing after controlled 401 check."
fi

# TLS validity for the API host.
export API_BASE
host="$(python3 - <<'PY'
import os
from urllib.parse import urlparse
print(urlparse(os.environ["API_BASE"]).hostname)
PY
)"
export host
python3 - <<'PY'
import os, socket, ssl
host = os.environ["host"]
ctx = ssl.create_default_context()
with socket.create_connection((host, 443), timeout=30) as sock:
    with ctx.wrap_socket(sock, server_hostname=host) as ssock:
        cert = ssock.getpeercert()
        assert cert, "missing peer cert"
print(f"TLS OK for {host}")
PY

# Optional authenticated smoke — only when owner-provided synthetic account secrets exist.
if [ -n "${IOS_STAGING_TEST_IDENTIFIER:-}" ] && [ -n "${IOS_STAGING_TEST_PASSWORD:-}" ]; then
  echo "Running authenticated login/me/logout with synthetic test account (credentials redacted)."
  code="$(curl -sS -o /tmp/ios-smoke-auth-login.json -w '%{http_code}' \
    --max-time 45 \
    -X POST "${API_BASE}/auth/login" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "$(python3 - <<'PY'
import json, os
print(json.dumps({
  "identifier": os.environ["IOS_STAGING_TEST_IDENTIFIER"],
  "password": os.environ["IOS_STAGING_TEST_PASSWORD"],
}))
PY
)")"
  echo "POST /auth/login (synthetic) -> ${code}"
  if [ "${code}" != "200" ]; then
    echo "::error::Synthetic login failed with ${code}"
    exit 1
  fi
  token="$(python3 - <<'PY'
import json
data=json.load(open("/tmp/ios-smoke-auth-login.json"))
token=(data.get("token") or (data.get("data") or {}).get("token") or "")
if not token:
    raise SystemExit("token missing in login response")
print(token)
PY
)"
  code="$(curl -sS -o /tmp/ios-smoke-me.json -w '%{http_code}' \
    --max-time 30 \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/json' \
    "${API_BASE}/me")"
  echo "GET /me -> ${code}"
  if [ "${code}" != "200" ]; then
    echo "::error::GET /me failed with ${code}"
    exit 1
  fi
  code="$(curl -sS -o /tmp/ios-smoke-logout.json -w '%{http_code}' \
    --max-time 30 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/json' \
    "${API_BASE}/auth/logout")"
  echo "POST /auth/logout -> ${code}"
  if [ "${code}" != "200" ] && [ "${code}" != "204" ]; then
    echo "::error::logout failed with ${code}"
    exit 1
  fi
else
  echo "Skipping authenticated login/me/logout (IOS_STAGING_TEST_IDENTIFIER / IOS_STAGING_TEST_PASSWORD not set)."
fi

echo "Staging smoke gates passed."
