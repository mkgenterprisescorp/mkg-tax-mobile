#!/usr/bin/env bash
# Inspect a signed IPA and fail if forbidden strings appear in extracted contents.
# Never prints signing secrets. Arguments: <path-to-ipa>
set -euo pipefail

IPA="${1:?IPA path required}"
BUNDLE_ID_EXPECTED="${IOS_BUNDLE_ID:?IOS_BUNDLE_ID required}"

if [ ! -f "${IPA}" ]; then
  echo "::error::IPA not found: ${IPA}"
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

unzip -q "${IPA}" -d "${WORKDIR}"
APP="$(find "${WORKDIR}/Payload" -maxdepth 1 -name '*.app' -type d | head -n 1)"
if [ -z "${APP}" ]; then
  echo "::error::No Payload/*.app inside IPA"
  exit 1
fi

PLIST="${APP}/Info.plist"
echo "=== IPA inspection ==="
BID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${PLIST}")"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}")"
BN="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PLIST}")"
MIN_IOS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "${PLIST}" 2>/dev/null || echo unknown)"
echo "CFBundleIdentifier=${BID}"
echo "CFBundleShortVersionString=${VER}"
echo "CFBundleVersion=${BN}"
echo "MinimumOSVersion=${MIN_IOS}"

if [ "${BID}" != "${BUNDLE_ID_EXPECTED}" ]; then
  echo "::error::Bundle ID mismatch. IPA has '${BID}', environment expects '${BUNDLE_ID_EXPECTED}'."
  exit 1
fi

CODESIGN_OUT="$(codesign -dvvv "${APP}" 2>&1 || true)"
echo "=== codesign (identity lines only) ==="
echo "${CODESIGN_OUT}" | grep -E 'Authority=|TeamIdentifier=|Identifier=' || true

echo "=== entitlements ==="
codesign -d --entitlements :- "${APP}" 2>/dev/null | plutil -p - || echo "(no entitlements or unreadable)"

EMBED_PROFILE="${APP}/embedded.mobileprovision"
if [ -f "${EMBED_PROFILE}" ]; then
  echo "=== embedded provisioning profile (safe fields) ==="
  security cms -D -i "${EMBED_PROFILE}" 2>/dev/null \
    | plutil -extract Name raw -o - - 2>/dev/null \
    | sed 's/^/ProfileName=/'
  security cms -D -i "${EMBED_PROFILE}" 2>/dev/null \
    | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null \
    | sed 's/^/application-identifier=/' || true
else
  echo "::error::embedded.mobileprovision missing"
  exit 1
fi

echo "=== forbidden-content scan ==="
# Binary-safe ripgrep; fail on any match.
PATTERN='neon\.tech|DATABASE_URL|HMAC_SECRET|identity_assertion_secret|service[_-]?client|MOCK_PASSWORD|mock[_-]?password|/internal/mobile|localhost|127\.0\.0\.1|http://app\.mkgtaxconsultants\.com|sk_live_|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
if command -v rg >/dev/null 2>&1; then
  if rg -a -n -e "${PATTERN}" "${APP}" ; then
    echo "::error::Forbidden pattern found inside IPA payload"
    exit 1
  fi
else
  if grep -R -a -n -E "${PATTERN}" "${APP}" ; then
    echo "::error::Forbidden pattern found inside IPA payload"
    exit 1
  fi
fi

echo "IPA inspection and secret scan passed."
echo "BUILD_NAME=${VER}" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "BUILD_NUMBER=${BN}" >> "${GITHUB_OUTPUT:-/dev/null}"
