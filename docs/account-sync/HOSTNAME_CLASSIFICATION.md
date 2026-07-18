# Hostname occurrence classification (`mkg-tax-mobile`)

| Location | Occurrence | Classification | Action |
|---|---|---|---|
| `lib/core/config/app_config.dart` `API_BASE_URL` | required dart-define | MUST remain mobile API | `https://app.mkgtaxconsultants.com/api/v1` only |
| `lib/core/config/app_config.dart` `WEB_BASE_URL` | portal deep links | MUST_CHANGE (done) | `https://mkgtaxconsultants.com` |
| `lib/core/network/api_client.dart` `ApiClient.memory` default | was `api.financemkgtax.com` | MUST_CHANGE (done) | `app.mkgtaxconsultants.com/api/v1` |
| `README.md` / `docs/mobile/financemkgtaxpro-integration.md` | stale legacy hosts | MUST_CHANGE (done) | updated |
| Comments in theme/widgets | brand portal host | MUST_CHANGE (done) | `mkgtaxconsultants.com` only |
| Any `/internal/mobile/v1` | — | **PROHIBITED** | must not appear |
| Portal S2S secrets | — | **PROHIBITED** | must not appear |
| Cookie auth against portal apex | transitional history | DOCS_HISTORY | Sanctum/`/api/v1` is the staging path |
