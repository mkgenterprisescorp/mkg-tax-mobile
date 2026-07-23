# Codemagic iOS / TestFlight (mkg-tax-mobile)

Source of truth for signed iOS builds after the first successful Codemagic IPA
(`build 6a620ddaf44974f6fb95f192` on `main` @ `2f36b7c`).

## Identity (do not change)

| Item | Value |
| --- | --- |
| Repository | `mkgenterprisescorp/mkg-tax-mobile` |
| App display (ASC) | MKG Tax Consultants Pro Filer |
| Device display name | `MKG Tax` (`CFBundleDisplayName`) |
| iOS bundle ID | `com.mkgenterprises.mkgTaxMobile` |
| Android package (unchanged) | `com.mkgtaxconsultants.mobile` |
| Production API | `https://app.mkgtaxconsultants.com/api/v1` |

Do **not** register another App ID, rename the bundle ID, or create another
Codemagic application for this product.

## Workflows (`codemagic.yaml`)

| Workflow ID | Purpose | ASC upload |
| --- | --- | --- |
| `ios_signed_prepare` | Analyze, test, signed IPA, private artifacts | **No** |
| `ios_testflight` | Same gates + TestFlight submit | **Yes** (`submit_to_testflight: true`) |

Both are **manual / API only** (`triggering.events: []`). Never start
`ios_testflight` without explicit owner approval. `submit_to_app_store` is
always `false`.

Pinned toolchain: Flutter **3.44.6**, Xcode **16.4**, `mac_mini_m2`.

## Codemagic UI prerequisites

1. **Developer Portal integration** — key label must match
   `integrations.app_store_connect` in `codemagic.yaml` (default string:
   `App Store Connect`). Use the same API key that signed build
   `6a620ddaf44974f6fb95f192`.
2. **Encrypted group** `ios_appstore` with numeric **`APP_STORE_APPLE_ID`**
   (App Store Connect app record Apple ID — not the bundle ID).
3. Automatic App Store distribution signing for
   `com.mkgenterprises.mkgTaxMobile` (already proven on the first IPA).

## Build number policy

Scripts call `app-store-connect get-latest-testflight-build-number`, fall back
to App Store latest, then apply floor **`33`** (first signed prepare after the
`+32` Play/Codemagic baseline). `pubspec.yaml` stays at `1.0.0+32` so Android
versionCode is not altered by this iOS work.

## Approval gate

1. Merge / land `codemagic.yaml`.
2. Start **`ios_signed_prepare`** on `main` (or the release branch).
3. Download IPA + logs; confirm bundle ID, Apple Distribution identity, SHA-256.
4. **Stop** — request explicit approval.
5. Only after approval, start **`ios_testflight`** (internal TestFlight only).

## First successful signed IPA (reference)

| Field | Value |
| --- | --- |
| Build URL | https://codemagic.io/app/6a61fd1171826706ef5d191c/build/6a620ddaf44974f6fb95f192 |
| Build ID | `6a620ddaf44974f6fb95f192` |
| App ID | `6a61fd1171826706ef5d191c` |
| Commit | `2f36b7c` |
| Artifact | `mkg_tax_mobile.ipa` (~26.53 MB) |
| TestFlight upload | **Not performed** |

## Local IPA inspect (optional)

```bash
python3 scripts/ci/ios_inspect_ipa.py /path/to/mkg_tax_mobile.ipa
```

Runs on Linux without Xcode; validates plist identity, embedded provision
markers, and forbidden-content scan. Full codesign Authority checks require
macOS (`codesign`) — Codemagic workflows run those on the build machine.
