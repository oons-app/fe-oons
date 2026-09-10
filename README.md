# fe-oons

Flutter app + Ops Console v2 (`lib/admin_v2`). Live staff UI: https://bo.oons.app

Remote: https://github.com/oons-app/fe-oons

## CI/CD

See [docs/ci-cd.md](docs/ci-cd.md). Push to `main` (app paths) builds and deploys the Ops Console to Lightsail. Requires the same Lightsail secrets as `be-oons` on the **production** environment.

## Local Ops Console build

```bash
flutter build web -t lib/admin_v2/main.dart --release --base-href / \
  --dart-define=API_BASE=https://api.oons.app \
  --dart-define=PUBLIC_WEB_BASE=https://lady.oons.app \
  --no-wasm-dry-run
```
