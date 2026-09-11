# fe-oons

The Flutter frontend for **Oons** — a women-first home-services marketplace
(cleaning, beauty, chef, childcare) for Greater Cairo.

Companion repo: [be-oons](https://github.com/oons-app/be-oons) (Go API +
Lightsail infra).

Flutter is pinned to **3.47.2** (stable) — match this locally to avoid
build-output drift between your machine and CI.

## Two apps, one repo

This is a single Flutter project with **two separate web entry points**,
built and deployed independently:

| Entry point | Audience | Live at |
|---|---|---|
| `lib/main.dart` | Customers + providers (booking, provider profile/services/team, jobs) | https://lady.oons.app |
| `lib/admin_v2/main.dart` | Staff — the Ops Console | https://bo.oons.app |

They share `lib/core/` and `lib/data/` but otherwise don't import from each
other. `lib/admin/` is an earlier, now-frozen admin UI kept only for
reference — new admin work goes in `lib/admin_v2/`.

## Layout

```
lib/
  main.dart              customer/provider app entry point
  app/                   routing, theming, shared app shell
  core/                  shared widgets, tokens, formatting, analytics
  data/                  Repo/API client, models, Hive-backed local cache
  l10n/                  Copy — every user-visible string (ar/en)
  features/
    auth/ book/ bookings/ browse/ client/ home/ me/ pay/ profile/
    public/ reviews/ system/ visit/ wallet/
    pro/                 provider-facing: services, team/workers, jobs, earnings
  admin_v2/              Ops Console — entry point lib/admin_v2/main.dart
    app.dart             MaterialApp.router + route tree
    chrome/               shell, nav, modals/forms, toasts
    data/                 staff session, RBAC (permissions.dart), API client
    features/             one folder per admin screen (providers, bookings,
                           vetting, category/service requests, staff, ...)
    ui/                    shared atoms (status pills, buttons, grid table)
    l10n/copy.dart         admin-only strings (ar/en)
  admin/                 legacy admin UI — frozen, reference only
docs/                    CI/CD notes
DECISIONS.md             prototype-parity gap decisions (provider app)
test/                    widget + unit tests for both apps
```

## Local development

```bash
flutter pub get
flutter analyze
flutter test
```

Build the customer/provider app:

```bash
flutter build web -t lib/main.dart --release \
  --dart-define=API_BASE=https://api.oons.app \
  --dart-define=PUBLIC_WEB_BASE=https://lady.oons.app
```

Build the Ops Console:

```bash
flutter build web -t lib/admin_v2/main.dart --release --base-href / \
  --dart-define=API_BASE=https://api.oons.app \
  --dart-define=PUBLIC_WEB_BASE=https://lady.oons.app \
  --no-wasm-dry-run
```

Both targets need `--dart-define=API_BASE=...` to point at a real API —
without it they fall back to `https://api.oons.app` by default, so a plain
`flutter build web` still works for a quick local check, but won't reflect
an env override.

## CI/CD

See [docs/ci-cd.md](docs/ci-cd.md) for required secrets and manual-deploy
steps. Short version: pushing to `main` under app paths runs `flutter
analyze`/`flutter test`, builds both web targets, and deploys each to its
own path on Lightsail (`web-root/` for the main app, `web-root/oons/admin/`
for the Ops Console), verifying the live `main.dart.js` bundle actually
matches what was just built before calling the deploy healthy.

**Gotcha worth knowing:** Flutter doesn't content-hash `main.dart.js` — it's
the same filename on every deploy. The edge (Caddy, in be-oons) is
responsible for telling browsers never to cache it; if that policy is ever
wrong, a browser that already loaded the old bundle can keep silently
running it through several deploys. See be-oons's
[deploy/caddy/Caddyfile](https://github.com/oons-app/be-oons/blob/main/deploy/caddy/Caddyfile)
if you're chasing a "my fix isn't showing up" report that a hard refresh
doesn't fix.
