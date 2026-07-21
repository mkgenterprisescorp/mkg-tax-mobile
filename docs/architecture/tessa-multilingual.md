# Tessa Multilingual (Flutter)

See backend SoT: `mkg-tax-backend-2/docs/architecture/tessa-multilingual.md`.

## Phase 1 (this PR)

- ARB: `lib/l10n/app_en.arb`, `app_es.arb`
- Locale controller + SharedPreferences persistence (explicit user choice only)
- Language setup screen: `/language-setup`
- Tessa chat sends `preferred_language` to Laravel
- Voice stubs call Laravel STT/TTS — no Gemini/Speech keys in the app

## Hard rules

- Do not put API keys for Gemini / STT / TTS in Flutter
- Do not infer language from device locale for tax preferences
- Do not silently switch language
- IRS form numbers and monetary values stay English / unchanged
