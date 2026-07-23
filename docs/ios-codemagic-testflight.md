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
     app_store_connect: Codemagic CI
   ```

   Same API key that signed Codemagic build `6a620ddaf44974f6fb95f192`.

2. Application-level encrypted **`APP_STORE_APPLE_ID`**
   (App Store Connect app record Apple ID for `com.mkgenterprises.mkgTaxMobile` —
   currently configured as `6793948043`; not the bundle ID string).
   Group `ios_appstore` may also expose the same variable.

3. Manual starts only. No release tags.

4. **Yaml Code signing identities** (required; Workflow Editor does not share these):

   Team settings → codemagic.yaml settings → **Code signing identities**:

   - Fetch/upload an **Apple Distribution** certificate (private key must be in Codemagic).
   - Fetch/upload an **App Store** provisioning profile for `com.mkgenterprises.mkgTaxMobile`.
   - Profile must show a matching certificate (green check).

   Without this, `ios_signed_prepare` fails immediately with:
   `No matching profiles found for bundle identifier "…" and distribution type "app_store"`
   (seen on build `6a621b81a9e9b4ffb8ddd6fb`).

## Ordered release steps

1. Keep prepare PR clean (this path only).
2. Confirm integration label + `APP_STORE_APPLE_ID` + Code signing identities (above).
3. Merge prepare PR only after CI / local gates pass.
4. Start **`ios_signed_prepare`** on `main` (UI or API):

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

## Reference signed IPA (pre-yaml UI build)

| Field | Value |
| --- | --- |
| Build URL | https://codemagic.io/app/6a61fd1171826706ef5d191c/build/6a620ddaf44974f6fb95f192 |
| Commit | `2f36b7c` |
| Artifact | `mkg_tax_mobile.ipa` |
| TestFlight | Not uploaded |
