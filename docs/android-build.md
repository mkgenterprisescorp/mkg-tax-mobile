# Android Build Guide (Windows)

This document describes how to set up a local Windows machine to build the
MKG Tax mobile app for Android, and how to produce a staging APK. It
contains no secrets — only tool locations, environment variable names, and
public staging endpoints. See [toolchain-versions.md](toolchain-versions.md)
for exact version numbers.

## 1. Install locations

Install all SDKs outside OneDrive and outside any git working directory, to
avoid sync conflicts and accidental commits of large binary toolchains:

| Tool | Recommended location |
|---|---|
| Flutter SDK | `C:\src\flutter` |
| Android SDK | `C:\Android\Sdk` |
| JDK 17 | `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` |

## 2. Environment variables

Set these as **User** environment variables:

| Variable | Value |
|---|---|
| `JAVA_HOME` | `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` |
| `ANDROID_HOME` | `C:\Android\Sdk` |
| `ANDROID_SDK_ROOT` | `C:\Android\Sdk` |

Add to `PATH`:

- `C:\src\flutter\bin`
- `%ANDROID_HOME%\platform-tools`
- `%ANDROID_HOME%\cmdline-tools\latest\bin`
- `%JAVA_HOME%\bin`

After setting these, close and reopen PowerShell so the new values are
picked up by new processes (registry updates via `setx`/`[Environment]::SetEnvironmentVariable`
do not propagate to already-running shells).

## 3. Accept Android licenses

```powershell
flutter doctor --android-licenses
```

Accept all prompts. Re-run `flutter doctor -v` afterward and confirm the
Android toolchain check passes with no outstanding license warnings.

## 4. Verify the toolchain

```powershell
flutter --version
flutter doctor -v
java -version
where.exe flutter
where.exe java
adb version
```

All commands should resolve to the install locations in section 1, and
`flutter doctor -v` should show no unresolved issues for the Android
toolchain.

## 5. Install project dependencies and validate

From the project root:

```powershell
flutter pub get
flutter analyze
flutter test --concurrency=1
```

These must all complete without modifying any source files. If `flutter
analyze` or `flutter test` fail, resolve the failure before proceeding to a
build — do not build a staging APK on top of a failing analyze/test run.

**Note on `--concurrency=1`:** when this project lives in a OneDrive-synced
folder on Windows, running `flutter test` with default concurrency can
silently drop some test files from the run (they never appear in the output
and are not counted, with no error and exit code 0) — most likely due to
file-lock contention between concurrently-started Dart VM test workers and
OneDrive's sync process. Running with `--concurrency=1` reliably runs every
file in `test/`. If the project is moved outside OneDrive, default
concurrency should be safe to use again.

## 6. Build a staging APK

Staging builds point at the live staging backend, `app.mkgtaxconsultants.com`,
via `--dart-define` flags (no secrets involved — this is a public API base
URL):

```powershell
flutter build apk --release `
  --build-name=1.0.0 `
  --build-number=11 `
  --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 `
  --dart-define=LARAVEL_API_BASE_URL=https://app.mkgtaxconsultants.com
```

Or use [`scripts/build-staging.ps1`](../scripts/build-staging.ps1), which
runs the same dependency/analyze/test/build sequence and prints a SHA-256
checksum of the resulting APK.

The output APK is written under `build/app/outputs/flutter-apk/`, which is
git-ignored. Do not copy the APK into the repository or commit it.

**Production signing is not configured here.** This build uses the default
Flutter debug/release signing config for staging verification only. A
production signing keystore and `android/key.properties` must be configured
separately, in an owner-approved step, and `android/key.properties` and any
`.jks`/`.keystore` files must never be committed (see `.gitignore`).

## 7. Verify a staging APK checksum

To confirm a staging APK matches an expected build (e.g. one produced by
CI or a cloud build agent), compute its SHA-256 and compare against the
value recorded for that build:

```powershell
Get-FileHash -Algorithm SHA256 -Path .\path\to\app-release.apk
```

A valid SHA-256 digest is always exactly 64 hexadecimal characters. If a
recorded "expected" hash does not match that length, treat it as unverified
and regenerate/reconcile it rather than trusting it at face value.

## 8. Distribution policy

Staging APKs are build artifacts, not source, and are distributed only via:

- Private GitHub Actions workflow artifacts (see
  [`.github/workflows/staging-apk.yml`](../.github/workflows/staging-apk.yml)), or
- A private/pre-release GitHub Release, only when explicitly owner-approved.

Staging APKs must never be committed into regular git history.
