# Codemagic iOS prepare / TestFlight (mkg-tax-mobile)

## Identity (do not change)

| Item | Value |
| --- | --- |
| Repository | `mkgenterprisescorp/mkg-tax-mobile` |
| Bundle ID | `com.mkgenterprises.mkgTaxMobile` |
| Device display name | `MKG Tax` |
| Production API | `https://app.mkgtaxconsultants.com/api/v1` |
| Android package (unchanged) | `com.mkgtaxconsultants.mobile` |

## Separation of concerns

| Stage | Where | Upload |
| --- | --- | --- |
| Signed prepare | root `codemagic.yaml` → `ios_signed_prepare` | **No** |
| TestFlight | `docs/deployment/codemagic-ios-testflight.workflow.yaml.example` (promote only after approval) | TestFlight only |

Password-reset / Laravel / portal / Android changes stay out of iOS release PRs.

## Codemagic prerequisites

1. **Developer Portal integration label** in Team settings must exactly match:

   ```yaml
   integrations:
     app_store_connect: App Store Connect
   ```

   Use the same API key that signed Codemagic build `6a620ddaf44974f6fb95f192`.
   If the UI label differs, update YAML to that exact string before starting a build.

2. Encrypted group **`ios_appstore`** with numeric **`APP_STORE_APPLE_ID`**
   (App Store Connect app record Apple ID for `com.mkgenterprises.mkgTaxMobile` —
   not the bundle ID string).

3. Manual starts only. No release tags.

## Ordered release steps

1. Keep prepare PR clean (this path only).
2. Confirm integration label + `APP_STORE_APPLE_ID`.
3. Merge prepare PR only after CI / local gates pass.
4. Start **`ios_signed_prepare`** on `main`.
5. Validate bundle ID, version/build, Apple Distribution signing, production API,
   IPA artifact + SHA-256.
6. **STOP** and report evidence.
7. Do **not** promote/run TestFlight until explicit approval.

## Local gates

```bash
python3 scripts/ci/validate_codemagic_yaml.py
flutter analyze --no-fatal-infos
flutter test --concurrency=1
```

After a prepare build, optional Linux IPA check:

```bash
python3 scripts/ci/ios_inspect_ipa.py /path/to/mkg_tax_mobile.ipa
```

## Reference signed IPA (pre-yaml UI build)

| Field | Value |
| --- | --- |
| Build URL | https://codemagic.io/app/6a61fd1171826706ef5d191c/build/6a620ddaf44974f6fb95f192 |
| Commit | `2f36b7c` |
| Artifact | `mkg_tax_mobile.ipa` |
| TestFlight | Not uploaded |
