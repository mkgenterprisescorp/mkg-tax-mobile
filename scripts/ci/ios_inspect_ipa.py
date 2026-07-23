#!/usr/bin/env python3
"""Inspect a signed IPA without Xcode (Linux-friendly).

Validates:
  - CFBundleIdentifier == com.mkgenterprises.mkgTaxMobile (override via IOS_BUNDLE_ID)
  - CFBundleShortVersionString / CFBundleVersion present
  - embedded.mobileprovision present; get-task-allow must not be true
  - forbidden-content scan over Payload/*.app

Does not require codesign(1). Codemagic macOS workflows additionally assert
Apple Distribution Authority.
"""

from __future__ import annotations

import os
import plistlib
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

EXPECTED_BUNDLE_ID = os.environ.get("IOS_BUNDLE_ID", "com.mkgenterprises.mkgTaxMobile")
FORBIDDEN = re.compile(
    rb"neon\.tech|DATABASE_URL|HMAC_SECRET|identity_assertion_secret|"
    rb"MOCK_PASSWORD|/internal/mobile|localhost|127\.0\.0\.1|"
    rb"http://app\.mkgtaxconsultants\.com|sk_live_|"
    rb"BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY"
)


def _read_plist(path: Path) -> dict:
    with path.open("rb") as fh:
        return plistlib.load(fh)


def _decode_mobileprovision(path: Path) -> dict:
    raw = path.read_bytes()
    start = raw.find(b"<?xml")
    end = raw.find(b"</plist>")
    if start < 0 or end < 0:
        raise RuntimeError("embedded.mobileprovision missing plist payload")
    return plistlib.loads(raw[start : end + len(b"</plist>")])


def inspect(ipa_path: Path) -> int:
    if not ipa_path.is_file():
        print(f"ERROR: IPA not found: {ipa_path}", file=sys.stderr)
        return 2

    work = Path(tempfile.mkdtemp(prefix="ipa_inspect_"))
    try:
        with zipfile.ZipFile(ipa_path) as zf:
            zf.extractall(work)
        apps = list((work / "Payload").glob("*.app"))
        if not apps:
            print("ERROR: No Payload/*.app in IPA", file=sys.stderr)
            return 2
        app = apps[0]
        info = _read_plist(app / "Info.plist")
        bid = info.get("CFBundleIdentifier")
        ver = info.get("CFBundleShortVersionString")
        bn = info.get("CFBundleVersion")
        display = info.get("CFBundleDisplayName")
        print("=== IPA inspection ===")
        print(f"CFBundleIdentifier={bid}")
        print(f"CFBundleShortVersionString={ver}")
        print(f"CFBundleVersion={bn}")
        print(f"CFBundleDisplayName={display}")
        print(f"MinimumOSVersion={info.get('MinimumOSVersion')}")
        if bid != EXPECTED_BUNDLE_ID:
            print(
                f"ERROR: Bundle ID mismatch. IPA has {bid!r}, expected {EXPECTED_BUNDLE_ID!r}",
                file=sys.stderr,
            )
            return 1

        profile_path = app / "embedded.mobileprovision"
        if not profile_path.is_file():
            print("ERROR: embedded.mobileprovision missing", file=sys.stderr)
            return 1
        profile = _decode_mobileprovision(profile_path)
        entitlements = profile.get("Entitlements") or {}
        print(f"ProfileName={profile.get('Name')}")
        print(f"TeamName={profile.get('TeamName')}")
        print(f"application-identifier={entitlements.get('application-identifier')}")
        print(f"get-task-allow={entitlements.get('get-task-allow')}")
        # Development profiles set get-task-allow true; App Store / TF must not.
        if entitlements.get("get-task-allow") is True:
            print(
                "ERROR: provisioning profile looks like development (get-task-allow=true)",
                file=sys.stderr,
            )
            return 1
        prov_app_id = str(entitlements.get("application-identifier") or "")
        if EXPECTED_BUNDLE_ID not in prov_app_id:
            print(
                f"ERROR: provision application-identifier {prov_app_id!r} "
                f"does not include {EXPECTED_BUNDLE_ID!r}",
                file=sys.stderr,
            )
            return 1

        print("=== forbidden-content scan ===")
        for path in app.rglob("*"):
            if not path.is_file():
                continue
            try:
                data = path.read_bytes()
            except OSError:
                continue
            if FORBIDDEN.search(data):
                print(f"ERROR: Forbidden pattern in {path.relative_to(app)}", file=sys.stderr)
                return 1
        print("IPA inspection and secret scan passed.")
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {argv[0]} <path-to-ipa>", file=sys.stderr)
        return 2
    return inspect(Path(argv[1]))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
