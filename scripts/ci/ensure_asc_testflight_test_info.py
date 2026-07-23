#!/usr/bin/env python3
"""Ensure App Store Connect TestFlight Test Information is filled.

Required for Codemagic `submit_to_testflight` external beta review:
- Beta App Localization → feedbackEmail
- Beta App Review Detail → contact first/last/phone/email

Uses App Store Connect API credentials already available to Codemagic
(`APP_STORE_CONNECT_*` from the Apple Developer Portal integration).
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import jwt
except ImportError:
    import subprocess

    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "-q", "PyJWT", "cryptography"]
    )
    import jwt

from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePrivateKey
from cryptography.hazmat.primitives.serialization import Encoding
from cryptography.hazmat.primitives.serialization import NoEncryption
from cryptography.hazmat.primitives.serialization import PrivateFormat
from cryptography.hazmat.primitives.serialization import load_pem_private_key

ASC_BASE = "https://api.appstoreconnect.apple.com"
PRIVATE_KEY_DIRS = (
    Path("./private_keys"),
    Path.home() / "private_keys",
    Path.home() / ".private_keys",
    Path.home() / ".appstoreconnect" / "private_keys",
)


def _require_env(*names: str) -> dict[str, str]:
    out: dict[str, str] = {}
    missing = []
    for name in names:
        value = (os.environ.get(name) or "").strip()
        if not value:
            missing.append(name)
        else:
            out[name] = value
    if missing:
        raise SystemExit(
            "Missing ASC API credentials: "
            + ", ".join(missing)
            + ". Codemagic integration `Codemagic CI` must inject APP_STORE_CONNECT_*."
        )
    return out


def _normalize_private_key(raw: str) -> str:
    """Codemagic/env secrets often store PEM with literal \\n or missing framing."""
    key = raw.strip().strip('"').strip("'")
    if "\\n" in key and "\n" not in key:
        key = key.replace("\\n", "\n")
    key = key.replace("\r\n", "\n").strip()
    if "BEGIN PRIVATE KEY" not in key and "BEGIN EC PRIVATE KEY" not in key:
        body = "".join(key.split())
        key = (
            "-----BEGIN PRIVATE KEY-----\n"
            + "\n".join(body[i : i + 64] for i in range(0, len(body), 64))
            + "\n-----END PRIVATE KEY-----"
        )
    if not key.endswith("\n"):
        key += "\n"
    return key


def _ec_pem_or_none(pem: str) -> str | None:
    """ASC API JWTs require an EC (ES256) key — skip RSA code-signing keys."""
    try:
        key = load_pem_private_key(pem.encode("utf-8"), password=None)
    except ValueError:
        return None
    if not isinstance(key, EllipticCurvePrivateKey):
        return None
    return key.private_bytes(
        Encoding.PEM, PrivateFormat.PKCS8, NoEncryption()
    ).decode("utf-8")


def _load_private_key(key_id: str, env_value: str | None) -> str:
    """Prefer AuthKey_*.p8 on disk; env may hold an RSA CERTIFICATE_PRIVATE_KEY by mistake."""
    candidates: list[tuple[str, str]] = []

    for directory in PRIVATE_KEY_DIRS:
        path = directory.expanduser() / f"AuthKey_{key_id}.p8"
        if path.is_file():
            candidates.append((str(path), path.read_text(encoding="utf-8")))

    for directory in PRIVATE_KEY_DIRS:
        root = directory.expanduser()
        if not root.is_dir():
            continue
        for path in sorted(root.glob("AuthKey_*.p8")):
            candidates.append((str(path), path.read_text(encoding="utf-8")))

    if env_value:
        candidates.append(("env:APP_STORE_CONNECT_PRIVATE_KEY", env_value))

    seen: set[str] = set()
    for label, raw in candidates:
        if label in seen:
            continue
        seen.add(label)
        pem = _normalize_private_key(raw)
        ec_pem = _ec_pem_or_none(pem)
        if ec_pem:
            print(f"Using ASC API EC private key from {label}")
            return ec_pem
        print(
            f"Skipping non-EC/invalid PEM candidate {label} "
            f"(len={len(raw)}, begin={'BEGIN' in raw}, nl={chr(10) in raw})"
        )

    raise SystemExit(
        "No valid ASC API EC private key found. Expected AuthKey_<KEY_ID>.p8 "
        "under Codemagic private_keys paths, or a PEM EC key in "
        "APP_STORE_CONNECT_PRIVATE_KEY."
    )


def _cached_jwt(key_id: str) -> str | None:
    """Reuse JWT written by earlier `app-store-connect` CLI steps on this builder."""
    cache = (
        Path(os.environ.get("TMPDIR") or "/tmp")
        / ".codemagic-cli-tools"
        / "cache"
        / "app_store_connect_jwt"
        / key_id
    )
    if not cache.is_file():
        return None
    token = cache.read_text(encoding="utf-8").strip()
    if not token or token.count(".") != 2:
        return None
    try:
        payload = jwt.decode(
            token,
            options={"verify_signature": False, "verify_exp": True},
            algorithms=["ES256"],
        )
    except Exception:
        return None
    if payload.get("iss") and payload.get("aud") == "appstoreconnect-v1":
        print(f"Using cached App Store Connect JWT for key {key_id}")
        return token
    return None


def _token(issuer_id: str, key_id: str, private_key: str | None) -> str:
    cached = _cached_jwt(key_id)
    if cached:
        return cached
    if not private_key:
        raise SystemExit("No cached JWT and no usable ASC private key")
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 16 * 60,
        "aud": "appstoreconnect-v1",
    }
    token = jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": key_id},
    )
    return token if isinstance(token, str) else token.decode("ascii")


def _request(token: str, method: str, path: str, body: dict | None = None) -> dict:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        f"{ASC_BASE}{path}", data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"ASC API {method} {path} failed HTTP {exc.code}: {detail}") from exc


def _patch_review_detail(token: str, app_id: str, attrs: dict[str, str]) -> None:
    detail = _request(token, "GET", f"/v1/apps/{urllib.parse.quote(app_id)}/betaAppReviewDetail")
    data = detail.get("data") or {}
    detail_id = data.get("id")
    if not detail_id:
        raise SystemExit("No betaAppReviewDetail found for app; create Test Info in ASC first.")
    current = data.get("attributes") or {}
    needed = {
        k: v
        for k, v in attrs.items()
        if (current.get(k) or "").strip() != v
    }
    if not needed:
        print("betaAppReviewDetail already up to date")
        return
    _request(
        token,
        "PATCH",
        f"/v1/betaAppReviewDetails/{urllib.parse.quote(detail_id)}",
        {
            "data": {
                "type": "betaAppReviewDetails",
                "id": detail_id,
                "attributes": needed,
            }
        },
    )
    print(f"Updated betaAppReviewDetail fields: {', '.join(sorted(needed))}")


def _ensure_feedback_email(token: str, app_id: str, feedback_email: str) -> None:
    locs = _request(
        token,
        "GET",
        f"/v1/apps/{urllib.parse.quote(app_id)}/betaAppLocalizations",
    )
    items = locs.get("data") or []
    preferred = None
    for item in items:
        locale = ((item.get("attributes") or {}).get("locale") or "").lower()
        if locale in ("en-us", "en"):
            preferred = item
            break
    if preferred is None and items:
        preferred = items[0]

    if preferred is None:
        created = _request(
            token,
            "POST",
            "/v1/betaAppLocalizations",
            {
                "data": {
                    "type": "betaAppLocalizations",
                    "attributes": {
                        "locale": "en-US",
                        "feedbackEmail": feedback_email,
                        "description": (
                            "MKG Tax Consultants Pro Filer beta for tax filing, "
                            "organizer intake, and advisor chat."
                        ),
                    },
                    "relationships": {
                        "app": {
                            "data": {"type": "apps", "id": app_id},
                        }
                    },
                }
            },
        )
        print(f"Created betaAppLocalization id={created.get('data', {}).get('id')}")
        return

    loc_id = preferred["id"]
    current_email = ((preferred.get("attributes") or {}).get("feedbackEmail") or "").strip()
    if current_email == feedback_email:
        print("betaAppLocalization feedbackEmail already up to date")
        return
    attrs: dict[str, str] = {"feedbackEmail": feedback_email}
    if not ((preferred.get("attributes") or {}).get("description") or "").strip():
        attrs["description"] = (
            "MKG Tax Consultants Pro Filer beta for tax filing, "
            "organizer intake, and advisor chat."
        )
    _request(
        token,
        "PATCH",
        f"/v1/betaAppLocalizations/{urllib.parse.quote(loc_id)}",
        {
            "data": {
                "type": "betaAppLocalizations",
                "id": loc_id,
                "attributes": attrs,
            }
        },
    )
    print(f"Updated betaAppLocalization feedbackEmail (+description if empty)")


def main() -> int:
    app_id = (os.environ.get("APP_STORE_APPLE_ID") or "").strip()
    if not app_id.isdigit():
        raise SystemExit("APP_STORE_APPLE_ID must be numeric ASC app id")

    feedback_email = (
        os.environ.get("TF_FEEDBACK_EMAIL") or "clientservices@mkgenterprisescorp.com"
    ).strip()
    contact_email = (os.environ.get("TF_CONTACT_EMAIL") or feedback_email).strip()
    contact_first = (os.environ.get("TF_CONTACT_FIRST_NAME") or "Marshawn").strip()
    contact_last = (os.environ.get("TF_CONTACT_LAST_NAME") or "Govan").strip()
    contact_phone = (os.environ.get("TF_CONTACT_PHONE") or "+1-559-412-7248").strip()

    creds = _require_env(
        "APP_STORE_CONNECT_ISSUER_ID",
        "APP_STORE_CONNECT_KEY_IDENTIFIER",
    )
    key_id = creds["APP_STORE_CONNECT_KEY_IDENTIFIER"]
    private_key: str | None = None
    try:
        private_key = _load_private_key(
            key_id,
            os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY"),
        )
    except SystemExit as exc:
        # Still OK if an earlier app-store-connect step cached a JWT.
        print(f"Private key load note: {exc}")
    token = _token(
        creds["APP_STORE_CONNECT_ISSUER_ID"],
        key_id,
        private_key,
    )

    print(f"Ensuring TestFlight Test Info for app {app_id}")
    print(f"FeedbackEmail={feedback_email}")
    print(f"Contact={contact_first} {contact_last} / {contact_phone} / {contact_email}")

    _ensure_feedback_email(token, app_id, feedback_email)
    _patch_review_detail(
        token,
        app_id,
        {
            "contactFirstName": contact_first,
            "contactLastName": contact_last,
            "contactPhone": contact_phone,
            "contactEmail": contact_email,
        },
    )
    print("ASC TestFlight Test Information ready for external beta submit.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
