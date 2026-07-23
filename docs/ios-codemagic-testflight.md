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
| TestFlight | `docs/deployment/codemagic-ios-testflight.workflow.yaml.example` (promote only after approval) | TestFlight only |

Password-reset / Laravel / portal / Android changes stay out of iOS release PRs.

## Codemagic prerequisites

1. **Developer Portal integration label** must exactly match:

   ```yaml
   integrations:
     app_store_connect: Codemagic CI
   ```

2. **`APP_STORE_APPLE_ID`** is configured at app level (`6793948043`). Yaml also sets a non-secret fallback; group `ios_appstore` may override.

3. **`CERTIFICATE_PRIVATE_KEY`** (Codemagic **Environment variables** group `ios_appstore`, not git): PEM RSA private key for the Apple Distribution certificate. Required by Codemagic CLI for `fetch-signing-files` even with integration label `Codemagic CI`.

   **Important:** Workflow Editor / Default Workflow application variables are **not** injected into `codemagic.yaml` builds. Putting `CERTIFICATE_PRIVATE_KEY` only on Default Workflow leaves yaml prepare empty (seen on `6a624dbf6f48bb1f5db01192`). Add it at:

   App settings → **Environment variables** → name `CERTIFICATE_PRIVATE_KEY` → group **`ios_appstore`** → Secret.

4. Manual starts only. No release tags.

5. **Signing model (yaml):** Codemagic automatic Apple signing — **no** `environment.ios_signing` profile matching:

   ```bash
   keychain initialize
   app-store-connect fetch-signing-files "$BUNDLE_ID" \
     --type IOS_APP_STORE \
     --create
   keychain add-certificates
   xcode-project use-profiles --project ios/Runner.xcodeproj
   ```

   Then `flutter build ipa --release` with production dart-defines. No `publishing:` section.

## Ordered release steps

1. Keep prepare PR clean (this path only).
2. Confirm integration label `Codemagic CI` + ASC app id `6793948043`.
3. Validate on the prepare branch, then merge only after checks pass.
4. Start **`ios_signed_prepare`** on the exact `main` merge commit (UI or API):

   ```bash
   curl -H "Content-Type: application/json" -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
     --data '{"appId":"6a61fd1171826706ef5d191c","workflowId":"ios_signed_prepare","branch":"main"}' \
     -X POST https://api.codemagic.io/builds
   ```

5. Validate bundle ID, version/build (≥33 floor), Apple Distribution signing, production API,
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

## Reference signed IPAs (Workflow Editor — not yaml prepare)

| Field | `6a620dda…` | `6a621d6c…` (post-#91) |
| --- | --- | --- |
| Build URL | https://codemagic.io/app/6a61fd1171826706ef5d191c/build/6a620ddaf44974f6fb95f192 | https://codemagic.io/app/6a61fd1171826706ef5d191c/build/6a621d6c2cac72f520799f7c |
| Commit | `2f36b7c` | `fce1acd` (main / #91) |
| Version / build | 1.0.0 / 32 | 1.0.0 / 32 |
| Bundle ID | `com.mkgenterprises.mkgTaxMobile` | same |
| TestFlight | Not uploaded | Not uploaded |
