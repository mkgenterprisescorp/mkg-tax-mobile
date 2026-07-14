# Tax-year workspace & mobile navigation

## Navigation (SoT)
```text
Home | Tax Returns | Organizer | Documents | TESSA | More
```

Selected tax year is shared across Returns, Organizer, Documents, Tasks, and TESSA context.

## API boundary (critical)
- Flutter talks to **HTTP APIs only**.
- Flutter must **never** connect directly to Neon PostgreSQL.
- Tax-year workspace APIs live on **Laravel**: `/api/mobile/tax-years/*`
- Configure with `--dart-define=LARAVEL_API_BASE_URL=https://your-laravel-host`
- Portal cookie APIs on `API_BASE_URL` (default `https://financemkgtax.com`) remain transitional for login/TESSA/legacy uploads until Sanctum cutover is complete.

## Tax-year rule (server-authoritative)
```text
current_filing_tax_year = server_calendar_year - 1
standard_years = current_filing_tax_year … (current_filing_tax_year - 9)
```
Laravel `GET /api/mobile/tax-years` is the source of truth. Mobile falls back locally only if Laravel is unreachable.

## Laravel endpoints
See `mkg-tax-backend` `routes/api.php` under `Route::prefix('mobile')`.
Annual rollover: `php artisan tax-years:rollover`
