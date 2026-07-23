#!/usr/bin/env python3
"""Validate root codemagic.yaml guardrails for iOS prepare + TestFlight paths."""

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
EXPECTED_INTEGRATION_LABEL = "Codemagic CI"
ALLOWED_WORKFLOWS = ("ios_signed_prepare", "ios_testflight")

REQUIRED_SIGNING_SNIPPETS = (
    "keychain initialize",
    'app-store-connect fetch-signing-files "$BUNDLE_ID"',
    "--type IOS_APP_STORE",
    "--create",
    "keychain add-certificates",
    "xcode-project use-profiles",
    "--project ios/Runner.xcodeproj",
)


def _scripts_blob(workflow: dict) -> str:
    return "\n".join(
        (s.get("script") if isinstance(s, dict) else str(s)) or ""
        for s in (workflow.get("scripts") or [])
    )


def _validate_common(name: str, w: dict) -> list[str]:
    errors: list[str] = []
    if w.get("triggering", {}).get("events") != []:
        errors.append(f"{name}: must be manual-only (triggering.events: [])")

    label = (w.get("integrations") or {}).get("app_store_connect")
    if label != EXPECTED_INTEGRATION_LABEL:
        errors.append(
            f"{name}: integrations.app_store_connect={label!r}; "
            f"expected {EXPECTED_INTEGRATION_LABEL!r}"
        )

    env = w.get("environment") or {}
    if env.get("flutter") != "3.44.6" or env.get("xcode") != "26.4":
        errors.append(
            f"{name}: unexpected toolchain pins flutter={env.get('flutter')!r} "
            f"xcode={env.get('xcode')!r} (ASC requires Xcode 26+ / iOS 26 SDK)"
        )
    if env.get("ios_signing"):
        errors.append(f"{name}: do not use environment.ios_signing; use ASC fetch sequence")

    scripts_blob = _scripts_blob(w)
    for required in REQUIRED_SIGNING_SNIPPETS:
        if required not in scripts_blob:
            errors.append(f"{name}: missing signing script requirement: {required}")

    positions = [scripts_blob.find(s) for s in REQUIRED_SIGNING_SNIPPETS]
    if any(p < 0 for p in positions) or positions != sorted(positions):
        errors.append(f"{name}: signing scripts must appear in Codemagic automatic order")

    vars_ = env.get("vars") or {}
    if vars_.get("API_BASE_URL") != EXPECTED_API:
        errors.append(f"{name}: API_BASE_URL must be {EXPECTED_API}")
    if vars_.get("BUNDLE_ID") != EXPECTED_BUNDLE:
        errors.append(f"{name}: BUNDLE_ID must be {EXPECTED_BUNDLE}")
    if not str(vars_.get("APP_STORE_APPLE_ID") or "").isdigit():
        errors.append(f"{name}: vars.APP_STORE_APPLE_ID must be numeric ASC app id")
    if "ios_appstore" not in (env.get("groups") or []):
        errors.append(f"{name}: environment.groups must include ios_appstore")

    arts = w.get("artifacts") or []
    for required in ("build/ios/ipa/*.ipa", "/tmp/xcodebuild_logs/*.log"):
        if required not in arts:
            errors.append(f"{name}: missing artifact pattern {required}")

    if (
        'BID" != "com.mkgenterprises.mkgTaxMobile"' not in scripts_blob
        and 'BID != "com.mkgenterprises.mkgTaxMobile"' not in scripts_blob
        and 'test "${BID}" = "com.mkgenterprises.mkgTaxMobile"' not in scripts_blob
        and 'test "${BID}" = "${BUNDLE_ID}"' not in scripts_blob
    ):
        errors.append(f"{name}: IPA inspect must fail closed on bundle ID")

    return errors


def main() -> int:
    text = YAML_PATH.read_text(encoding="utf-8")
    data = yaml.safe_load(text)
    workflows = data.get("workflows") or {}
    keys = list(workflows.keys())
    if keys != list(ALLOWED_WORKFLOWS):
        print(
            "ERROR: root codemagic.yaml workflows must be exactly "
            f"{list(ALLOWED_WORKFLOWS)} (found {keys}).",
            file=sys.stderr,
        )
        return 1

    errors: list[str] = []
    for name in ALLOWED_WORKFLOWS:
        errors.extend(_validate_common(name, workflows[name]))

    prepare = workflows["ios_signed_prepare"]
    if prepare.get("publishing"):
        errors.append("ios_signed_prepare must not include a publishing section")

    tf = workflows["ios_testflight"]
    publishing = tf.get("publishing") or {}
    asc = publishing.get("app_store_connect") or {}
    if not asc:
        errors.append("ios_testflight must publish via app_store_connect")
    else:
        if asc.get("auth") != "integration":
            errors.append("ios_testflight publishing.auth must be 'integration'")
        if asc.get("submit_to_testflight") is not True:
            errors.append("ios_testflight must set submit_to_testflight: true")
        if asc.get("submit_to_app_store") is not False:
            errors.append("ios_testflight must set submit_to_app_store: false")

    tf_scripts = _scripts_blob(tf)
    if "ensure_asc_testflight_test_info.py" not in tf_scripts:
        errors.append(
            "ios_testflight must run scripts/ci/ensure_asc_testflight_test_info.py"
        )
    tf_vars = (tf.get("environment") or {}).get("vars") or {}
    if tf_vars.get("TF_FEEDBACK_EMAIL") != "clientservices@mkgenterprisescorp.com":
        errors.append(
            "ios_testflight TF_FEEDBACK_EMAIL must be clientservices@mkgenterprisescorp.com"
        )

    if "submit_to_app_store: true" in text:
        errors.append("submit_to_app_store: true is forbidden")

    for bad in ("BEGIN PRIVATE KEY", "DATABASE_URL=", "neon.tech"):
        if bad in text:
            errors.append(f"forbidden content in yaml: {bad}")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1

    print("codemagic.yaml prepare+TestFlight guardrails: PASS")
    print(f"  workflows: {list(ALLOWED_WORKFLOWS)}")
    print(f"  integration label: {EXPECTED_INTEGRATION_LABEL}")
    print(f"  bundle: {EXPECTED_BUNDLE}")
    print(f"  api: {EXPECTED_API}")
    print("  ios_signed_prepare publishing: none")
    print("  ios_testflight: TestFlight only (no App Store)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
