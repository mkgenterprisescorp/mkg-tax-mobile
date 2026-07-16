<#
.SYNOPSIS
    Builds a staging Android APK for the MKG Tax mobile app.

.DESCRIPTION
    Runs flutter pub get, flutter analyze, flutter test, then builds a
    release APK pointed at the staging backend (app.mkgtaxconsultants.com).
    Prints the APK path, size, and SHA-256 checksum. Does not copy or
    commit the APK anywhere — distribution is handled separately via
    GitHub Actions artifacts or an owner-approved release.

    Contains no secrets. The staging API base URL is a public endpoint.
#>

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot

try {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutterCmd) {
        throw "flutter was not found on PATH. Install the Flutter SDK and add <flutter>\bin to PATH before running this script."
    }
    Write-Host "Using flutter at: $($flutterCmd.Source)"

    Write-Host "`n=== flutter pub get ==="
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE" }

    Write-Host "`n=== flutter analyze ==="
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed with exit code $LASTEXITCODE" }

    Write-Host "`n=== flutter test ==="
    # --concurrency=1: on a OneDrive-synced checkout, default concurrency can
    # silently drop test files due to file-lock contention between workers.
    flutter test --concurrency=1
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed with exit code $LASTEXITCODE" }

    Write-Host "`n=== flutter build apk --release (staging) ==="
    flutter build apk --release `
        --build-name=1.0.0 `
        --build-number=11 `
        --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 `
        --dart-define=LARAVEL_API_BASE_URL=https://app.mkgtaxconsultants.com
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed with exit code $LASTEXITCODE" }

    $apkPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        throw "Expected APK not found at $apkPath"
    }

    $apkFile = Get-Item $apkPath
    $hash = Get-FileHash -Algorithm SHA256 -Path $apkPath

    Write-Host "`n=== Build complete ==="
    Write-Host "APK path:   $($apkFile.FullName)"
    Write-Host "APK size:   $($apkFile.Length) bytes"
    Write-Host "SHA-256:    $($hash.Hash)"
    Write-Host "`nThis script does not copy or commit the APK. Distribute only via a private GitHub Actions artifact or an owner-approved release."
}
finally {
    Pop-Location
}
