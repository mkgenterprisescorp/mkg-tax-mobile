#!/usr/bin/env bash
# Fail closed if required ios-testflight environment secrets/vars are missing.
# Never prints secret values.
set -euo pipefail

missing=0
require_secret() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "::error::Missing required secret or variable: ${name}"
    missing=1
  else
    echo "Present: ${name} (value redacted)"
  fi
}

require_secret IOS_DISTRIBUTION_CERTIFICATE_BASE64
require_secret IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
require_secret IOS_PROVISIONING_PROFILE_BASE64
require_secret IOS_KEYCHAIN_PASSWORD
require_secret APP_STORE_CONNECT_API_KEY_BASE64
require_secret APP_STORE_CONNECT_KEY_ID
require_secret APP_STORE_CONNECT_ISSUER_ID
require_secret IOS_BUNDLE_ID
require_secret APPLE_TEAM_ID
require_secret STAGING_API_BASE_URL

if [ "${IOS_EXPORT_METHOD:-}" != "app-store-connect" ] && [ "${IOS_EXPORT_METHOD:-}" != "app-store" ]; then
  echo "::error::IOS_EXPORT_METHOD must be app-store-connect (or legacy app-store). Got: '${IOS_EXPORT_METHOD:-}'"
  missing=1
else
  echo "Present: IOS_EXPORT_METHOD=${IOS_EXPORT_METHOD}"
fi

if [ -z "${IOS_BUNDLE_ID:-}" ] || [[ "${IOS_BUNDLE_ID}" == *"PLACEHOLDER"* ]]; then
  echo "::error::IOS_BUNDLE_ID is missing or still a placeholder. Owner must confirm the App ID."
  missing=1
fi

if [ -z "${APPLE_TEAM_ID:-}" ] || [[ "${APPLE_TEAM_ID}" == *"PLACEHOLDER"* ]]; then
  echo "::error::APPLE_TEAM_ID is missing or still a placeholder. Owner must confirm the Team ID."
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo "::error::Signed iOS workflow cannot continue until ios-testflight environment is fully configured."
  exit 1
fi

echo "All required ios-testflight secrets/variables are present (values not printed)."
