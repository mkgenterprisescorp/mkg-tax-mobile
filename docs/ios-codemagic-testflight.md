# Codemagic iOS prepare / TestFlight (mkg-tax-mobile)

## Identity (do not change)

| Item | Value |
| --- | --- |
| Repository | `mkgenterprisescorp/mkg-tax-mobile` |
| Bundle ID | `com.mkgenterprises.mkgTaxMobile` |
| Device display name | `MKG Tax` |
| Production API | `https://app.mkgtaxconsultants.com/api/v1` |
| Android package (unchanged) | `com.mkgtaxconsultants.mobile` |
| ASC app record Apple ID | `6793948043` |

## Separation of concerns

| Stage | Where | Upload |
| --- | --- | --- |
| Signed prepare | root `codemagic.yaml` → `ios_signed_prepare` | **No** |
| TestFlight | root `codemagic.yaml` → `ios_testflight` | TestFlight only (`submit_to_app_store: false`) |

Password-reset / Laravel / portal / Android changes stay out of iOS release PRs.

## Codemagic prerequisites

1. **Developer Portal integration label** must exactly match:

   ```yaml
   integrations:
     app_store_connect: Codemagic CI
   ```

2. **`APP_STORE_APPLE_ID`** in Environment variables group `ios_appstore` (`6793948043`). Yaml also sets a non-secret fallback.

3. **`CERTIFICATE_PRIVATE_KEY`** in Environment variables group `ios_appstore` (encrypted Distribution cert PEM). Workflow Editor variables are **not** injected into yaml builds.

4. Manual starts only. No release tags. Codemagic `xcode: "26.4"` (iOS 26 SDK required by ASC).

5. App Store marketing icon must be opaque RGB (no alpha) — `Icon-App-1024x1024@1x.png`.

5. **Signing model (yaml):** Codemagic automatic Apple signing — **no** `environment.ios_signing`:

   ```bash
   keychain initialize
   app-store-connect fetch-signing-files "$BUNDLE_ID" \
     --type IOS_APP_STORE \
     --create
   keychain add-certificates
   xcode-project use-profiles --project ios/Runner.xcodeproj
   ```

   `ios_testflight` uses the same App Store export (not Internal Testing Only) so
   `submit_to_testflight: true` can request external TestFlight beta review.

6. **TestFlight Test Information (required for external beta submit):**

   `ios_testflight` runs `scripts/ci/ensure_asc_testflight_test_info.py` before
   the IPA build so Codemagic post-processing can submit for beta review.

   Defaults (overridable via workflow vars):
   - Feedback / contact email: `clientservices@mkgenterprisescorp.com`
   - Contact: Marshawn Govan / `+1-559-412-7248` (public portal phone)

   ASC UI (manual fallback):
   https://appstoreconnect.apple.com/apps/6793948043/testflight/test-info

   Missing these previously caused post-processing failure after upload
   (`Complete test information is required to submit … for external testing`).

## Ordered release steps

1. Confirm integration label `Codemagic CI` + group `ios_appstore`.
2. Optional: run **`ios_signed_prepare`** on `main` (no upload) to validate IPA.
3. After explicit approval, start **`ios_testflight`** on `main`:

   ```bash
   curl -H "Content-Type: application/json" -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
     --data '{"appId":"6a61fd1171826706ef5d191c","workflowId":"ios_testflight","branch":"main"}' \
     -X POST https://api.codemagic.io/builds
   ```

4. Validate bundle ID, version/build (≥33 floor), Apple Distribution signing, production API,
   IPA SHA-256, and TestFlight processing in App Store Connect.
5. Do **not** submit to App Store production from this workflow.

## Local gates

```bash
python3 scripts/ci/validate_codemagic_yaml.py
flutter analyze --no-fatal-infos
flutter test --concurrency=1
```

## Reference signed prepare (main, no TF upload)

| Field | Value |
| --- | --- |
| Build URL | https://codemagic.io/app/6a61fd1171826706ef5d191c/build/6a625310da2a1416199b72bd |
| Commit | `74cf97f` |
| Version / build | 1.0.0 / 33 |
| Bundle ID | `com.mkgenterprises.mkgTaxMobile` |
| IPA SHA-256 | `8907a98ef8c5a2f4eac908c7a5fc1057f0328d5b05fc06da283c2ce1ff22d784` |
| TestFlight | Not uploaded (prepare-only) |
