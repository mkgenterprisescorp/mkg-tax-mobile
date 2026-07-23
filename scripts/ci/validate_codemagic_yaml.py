#!/usr/bin/env python3
"""Validate root codemagic.yaml guardrails for the prepare-only iOS release path."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pyyaml"])
    import yaml

ROOT = Path(__file__).resolve().parents[2]
YAML_PATH = ROOT / "codemagic.yaml"
EXPECTED_BUNDLE = "com.mkgenterprises.mkgTaxMobile"
EXPECTED_API = "https://app.mkgtaxconsultants.com/api/v1"
# Existing Codemagic Developer Portal key label used for automatic signing.
# Confirm in Team integrations before starting ios_signed_prepare.
EXPECTED_INTEGRATION_LABEL = "Codemagic CI"


def main() -> int:
    text = YAML_PATH.read_text(encoding="utf-8")
    data = yaml.safe_load(text)
    workflows = data.get("workflows") or {}
    if list(workflows.keys()) != ["ios_signed_prepare"]:
        print(
            "ERROR: root codemagic.yaml must contain only ios_signed_prepare "
            f"(found {list(workflows.keys())}). TestFlight belongs in a separate PR.",
            file=sys.stderr,
        )
        return 1

    w = workflows["ios_signed_prepare"]
    if w.get("triggering", {}).get("events") != []:
        print("ERROR: ios_signed_prepare must be manual-only (triggering.events: [])", file=sys.stderr)
        return 1

    label = (w.get("integrations") or {}).get("app_store_connect")
    if label != EXPECTED_INTEGRATION_LABEL:
        print(
            f"ERROR: integrations.app_store_connect={label!r}; "
            f"expected {EXPECTED_INTEGRATION_LABEL!r}",
            file=sys.stderr,
        )
        return 1

    env = w["environment"]
    if env.get("flutter") != "3.44.6" or env.get("xcode") != "16.4":
        print(f"ERROR: unexpected toolchain pins flutter={env.get('flutter')!r} xcode={env.get('xcode')!r}", file=sys.stderr)
        return 1
    signing = env.get("ios_signing") or {}
    if signing.get("distribution_type") != "app_store":
        print("ERROR: distribution_type must be app_store", file=sys.stderr)
        return 1
    if signing.get("bundle_identifier") != EXPECTED_BUNDLE:
        print(f"ERROR: bundle_identifier must be {EXPECTED_BUNDLE}", file=sys.stderr)
        return 1
    vars_ = env.get("vars") or {}
    if vars_.get("API_BASE_URL") != EXPECTED_API:
        print(f"ERROR: API_BASE_URL must be {EXPECTED_API}", file=sys.stderr)
        return 1
    if vars_.get("BUNDLE_ID") != EXPECTED_BUNDLE:
        print(f"ERROR: BUNDLE_ID must be {EXPECTED_BUNDLE}", file=sys.stderr)
        return 1
    if "ios_appstore" not in (env.get("groups") or []):
        print("ERROR: environment.groups must include ios_appstore", file=sys.stderr)
        return 1

    publishing = w.get("publishing") or {}
    if "app_store_connect" in publishing:
        print("ERROR: ios_signed_prepare must not publish to App Store Connect", file=sys.stderr)
        return 1
    if "submit_to_testflight: true" in text or "submit_to_app_store: true" in text:
        print("ERROR: root codemagic.yaml must not enable TestFlight/App Store submit", file=sys.stderr)
        return 1

    arts = w.get("artifacts") or []
    for required in ("build/ios/ipa/*.ipa", "/tmp/xcodebuild_logs/*.log"):
        if required not in arts:
            print(f"ERROR: missing artifact pattern {required}", file=sys.stderr)
            return 1

    for bad in ("BEGIN PRIVATE KEY", "DATABASE_URL=", "neon.tech"):
        if bad in text:
            print(f"ERROR: forbidden content in yaml: {bad}", file=sys.stderr)
            return 1

    print("codemagic.yaml prepare-only guardrails: PASS")
    print(f"  workflow: ios_signed_prepare")
    print(f"  integration label: {label}")
    print(f"  bundle: {EXPECTED_BUNDLE}")
    print(f"  api: {EXPECTED_API}")
    print("  publishing: none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
