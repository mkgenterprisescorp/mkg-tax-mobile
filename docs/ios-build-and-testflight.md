# iOS build and TestFlight (GitHub Actions)

This document describes unsigned iOS CI versus signed TestFlight IPA builds for
`mkg-tax-mobile`. It contains **no credentials**, certificates, or base64 blobs.

## Source-control gate

- PR #58 (Home/Organizer performance) and PR #61 (Flutter web App Platform) must
  be on `main` before iOS CI work is based on that combined Flutter source.
- Branch for this automation: `cursor/ios-github-actions-f489`.
- Do not modify, merge, or force-push PR #58 / PR #61 feature branches.
- Do not deploy DigitalOcean / change DNS / CORS / Neon from iOS CI work.


## Installing workflow YAML into `.github/workflows/`

The automation token used for some agent pushes lacks the GitHub `workflow`
scope, so the canonical workflow sources ship as:

- `docs/deployment/flutter-ios-ci.workflow.yml.example`
- `docs/deployment/flutter-ios-testflight.workflow.yml.example`

Owner/admin (with `workflow` scope) must copy them once:

```bash
mkdir -p .github/workflows
cp docs/deployment/flutter-ios-ci.workflow.yml.example .github/workflows/flutter-ios-ci.yml
cp docs/deployment/flutter-ios-testflight.workflow.yml.example .github/workflows/flutter-ios-testflight.yml
# Remove the leading INSTALL comment lines if desired, then commit & push.
```

Until that copy lands on the branch/PR, GitHub will not execute the workflows.

## Why GitHub macOS still uses Xcode

Ordinary developers do **not** need a local Mac for CI builds. GitHub-hosted
`macos-14` runners provide Xcode. Flutter’s iOS toolchain invokes `xcodebuild`
on that runner. Claiming “no Xcode” would be incorrect — Xcode is required; a
**local** Mac is optional for CI.

## Unsigned CI vs signed IPA

| | Unsigned CI | Signed TestFlight |
|---|---|---|
| Workflow | `.github/workflows/flutter-ios-ci.yml` | `.github/workflows/flutter-ios-testflight.yml` |
| Triggers | `pull_request`, `workflow_dispatch` | `workflow_dispatch` only |
| Environment | none | `ios-testflight` (required reviewers) |
| Command | `flutter build ios --release --no-codesign` | `flutter build ipa --release` |
| Artifact | Unsigned `Runner.app` (compile proof only) | Signed `.ipa` |
| App Store Connect | Never | Only if `upload_to_testflight=true` |
| Fork PRs | Allowed (no secrets) | Impossible (manual + environment) |

The unsigned workflow **does not** produce a device-installable or
TestFlight-installable app.

## Phase 1 audit snapshot (repo facts)

| Item | Value |
|---|---|
| Flutter | **3.44.6** stable (`docs/toolchain-versions.md`, CI pin) |
| Dart | **3.12.2** (`pubspec` `sdk: ^3.12.2`) |
| `ios/Runner` | Present (`Runner.xcodeproj` / `.xcworkspace`) |
| CocoaPods | **Not used** (no `Podfile`; Flutter SPM plugins) |
| Deployment target | **iOS 13.0** |
| Bundle ID (Xcode today) | `com.mkgenterprises.mkgTaxMobile` |
| Suggested future ID | `com.mkgtaxconsultants.mobile` (**owner confirmation required; not registered by CI**) |
| Display name | `MKG Tax` |
| Version source | `pubspec.yaml` `version: 1.0.0+29` → name/build via Flutter |
| Signing / Team ID in project | **Missing** (`DEVELOPMENT_TEAM` unset) |
| Entitlements / privacy manifest | **Missing** |
| Info.plist usage descriptions | **Missing** (camera/photo/etc.) |
| URL schemes / associated domains / push / Firebase | **Missing** |
| Real Apple credentials in git | **None** |
| Tracked Pods / IPA / profiles / certs / keys | **None** |

Signed builds **fail closed** until `IOS_BUNDLE_ID` and `APPLE_TEAM_ID` are set
in the `ios-testflight` environment and match the Xcode project bundle ID.

## Workflows

### Unsigned — `flutter-ios-ci.yml`

- Permissions: `contents: read`
- Concurrency cancellation per PR
- Actions pinned to immutable commit SHAs
- Staging dart-defines only (public HTTPS API host)
- Uploads unsigned `Runner.app` artifact (7-day retention)
- Refuses if signing / DB / HMAC secret names appear in the job environment

### Signed — `flutter-ios-testflight.yml`

- `environment: ios-testflight`
- Inputs: `release_notes`, `api_environment` (staging only),
  `upload_to_testflight` (default `false`), optional `build_name`,
  `build_number_offset`
- Validates secrets without printing values
- Imports distribution cert into a temporary keychain
- Installs provisioning profile to the runner
- Runs analyze + tests + staging API smoke gates before IPA build
- Builds with staging API configuration only
- Inspects IPA (bundle ID, version, build, signing, profile, entitlements, min iOS)
- Scans IPA payload for neon/DB/HMAC/mock/internal/localhost/cleartext patterns
- Uploads IPA artifact (7-day retention)
- Uploads to TestFlight only when explicitly enabled
- Always cleans keychain / cert / profile / API key files

## GitHub Environment: `ios-testflight`

Create the Environment in the repository settings and enable **required
reviewers** (owner approval) before secrets are available to jobs.

### Environment secrets (names only — never commit values)

| Name | Purpose |
|---|---|
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded `.p12` distribution certificate |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store `.mobileprovision` |
| `IOS_KEYCHAIN_PASSWORD` | Random password for the temporary CI keychain |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded `.p8` private key |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID |
| `IOS_STAGING_TEST_IDENTIFIER` | Optional synthetic staging login |
| `IOS_STAGING_TEST_PASSWORD` | Optional synthetic staging password |

### Environment variables

| Name | Example / notes |
|---|---|
| `IOS_BUNDLE_ID` | Must match Xcode (`com.mkgenterprises.mkgTaxMobile` today) |
| `APPLE_TEAM_ID` | Owner-confirmed Team ID (no placeholder) |
| `IOS_EXPORT_METHOD` | `app-store-connect` |
| `STAGING_API_BASE_URL` | `https://app.mkgtaxconsultants.com/api/v1` |
| `IOS_PROVISIONING_PROFILE_NAME` | Exact profile **Name** as shown in Apple portal (optional if resolvable from the profile blob) |

Use the narrowest App Store Connect API role that can upload TestFlight builds
(e.g. **App Manager** or a custom role with “Upload builds”). Do **not** create
an Admin key merely for convenience.

Apple lets you download a given `.p8` private key **only once**. Store it in a
password manager / hardware vault immediately.

## Encoding files safely (local owner machine)

```bash
# Certificate (.p12) → secret value
base64 -i ios_distribution.p12 | pbcopy   # macOS
# or: base64 -w0 ios_distribution.p12

# Provisioning profile → secret value
base64 -i profile.mobileprovision | pbcopy

# App Store Connect .p8 → secret value
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Paste only into the GitHub Environment secret fields. Never commit the outputs.

## ExportOptions

- Template (safe): `ios/ExportOptions.example.plist`
- Runtime file is generated on the runner from environment values
- `method: app-store-connect`, `signingStyle: manual`, `uploadSymbols: true`
- `manageAppVersionAndBuildNumber: false` (CI supplies `--build-name` / `--build-number`)

## Build numbering

- `--build-name`: `pubspec.yaml` version name (e.g. `1.0.0`) or workflow input
- `--build-number`: `github.run_number + build_number_offset`
- Confirm `CFBundleShortVersionString` / `CFBundleVersion` in the inspect step
- Never reuse a build number already uploaded to TestFlight; increase the offset
  if you reset workflow run numbers

## Staging-only client configuration

Initial TestFlight builds must use:

```text
API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1
```

Do **not** enable for these builds:

- production registration
- mock authentication
- production banking
- live Stripe activity
- direct Neon access
- embedded portal / S2S credentials

### Pre-upload staging smoke (automated)

The signed workflow runs `scripts/ci/ios_staging_smoke.sh`:

1. `GET /health` → 200  
2. `GET /app-version` → 200  
3. Invalid login → controlled 401 (not 500)  
4. Bounded rate probes (429 expected when limits engage)  
5. TLS valid for the API host  
6. Optional login/me/logout when synthetic account secrets are set  

## Owner TestFlight preparation checklist

Complete in Apple Developer / App Store Connect **before** running the signed workflow:

- [ ] Active Apple Developer Program membership  
- [ ] App Store Connect application created  
- [ ] Final bundle ID registered (confirm whether to keep
      `com.mkgenterprises.mkgTaxMobile` or move to
      `com.mkgtaxconsultants.mobile`)  
- [ ] Apple Team ID confirmed → set `APPLE_TEAM_ID`  
- [ ] App name + SKU confirmed  
- [ ] Apple Distribution certificate created → encode to
      `IOS_DISTRIBUTION_CERTIFICATE_BASE64`  
- [ ] App Store provisioning profile created → encode to
      `IOS_PROVISIONING_PROFILE_BASE64`  
- [ ] App Store Connect API key created; `.p8` downloaded once and stored safely  
- [ ] Encryption / export compliance answered  
- [ ] Privacy policy URL + support URL  
- [ ] TestFlight beta description + feedback email  
- [ ] Internal tester group  
- [ ] Camera / photo / document permission strings added to `Info.plist` when those
      features ship  
- [ ] Privacy manifest + collected-data disclosures reviewed  
- [ ] GitHub Environment `ios-testflight` created with required reviewers  

Do **not** create Apple resources with guessed identifiers.

## Manual TestFlight procedure

1. Ensure unsigned CI is green on the target commit.  
2. Confirm `ios-testflight` secrets/vars are set (no placeholders).  
3. Align Xcode `PRODUCT_BUNDLE_IDENTIFIER` with `IOS_BUNDLE_ID`.  
4. Run **Flutter iOS TestFlight (signed)** via `workflow_dispatch`.  
5. Approve the Environment gate when prompted.  
6. Leave `upload_to_testflight=false` for the first signed IPA; download the
   artifact and spot-check.  
7. Re-run with `upload_to_testflight=true` only after owner approval.  
8. Process the build in App Store Connect → TestFlight → internal testers.

## Downloading the IPA artifact

GitHub Actions → workflow run → Artifacts →
`mkg-tax-mobile-ios-staging-ipa` (7-day retention).

## Rollback / revocation

- **Bad TestFlight build:** expire the build in App Store Connect; notify
  testers; upload a fixed build with a higher build number.  
- **Suspected API key exposure:** revoke the key in App Store Connect
  immediately; create a new key; update `APP_STORE_CONNECT_*` secrets; rotate
  any other material that may have been exposed.  
- **Certificate compromise:** revoke the distribution certificate in Apple
  Developer; create a new cert + profile; update GitHub secrets.  
- **CI rollback:** re-run unsigned CI on the last known-good commit; do not
  re-upload a known-bad IPA.

## Certificate expiration monitoring

Distribution certificates and provisioning profiles expire. Calendar-remind
before expiry; rebuild profiles after cert rotation; keep at least one
valid backup cert in the owner vault (not in git).

## Common signing failures

| Symptom | Likely cause |
|---|---|
| Bundle ID mismatch error | `IOS_BUNDLE_ID` ≠ Xcode `PRODUCT_BUNDLE_IDENTIFIER` |
| Missing secret | Environment not configured / approval skipped |
| `No signing certificate` | Wrong/expired `.p12` or keychain import failed |
| Profile doesn’t match | Profile bundle ID / team / cert mismatch |
| altool upload rejected | API key role, agreement, or build-number reuse |
| Smoke `/app-version` ≠ 200 | Staging API regression — stop; do not upload |

## Security rules

- Never commit certificates, profiles, `.p8` keys, IPA files, passwords, or
  temporary keychains.  
- Never print secret values in logs.  
- Never place Neon URLs, `DATABASE_URL`, HMAC secrets, S2S URLs, or mock
  passwords in Flutter dart-defines or IPA contents.  
- Never enable automatic TestFlight upload on `push` without a separate
  owner-approved change.
