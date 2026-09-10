# Frontend CI/CD (GitHub Actions)

Deploys the Ops Console (`lib/admin_v2`) to Lightsail as static files under `/opt/oonsa/web-root/oons/admin/` → https://bo.oons.app

## Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | PR / push to `main` (app paths) | `flutter analyze`, `flutter test`, release web build |
| [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) | Push to `main` (app paths) or **Run workflow** | Build web → rsync to Lightsail → health-check `bo.oons.app` |

Flutter is pinned to **3.47.2** (stable) to match local builds.

## Required GitHub secrets

Same values as [be-oons](https://github.com/oons-app/be-oons) (copy from that repo’s Actions secrets / `production` environment):

| Secret | Example / notes |
|--------|-----------------|
| `LIGHTSAIL_HOST` | `52.57.207.110` |
| `LIGHTSAIL_USER` | `ubuntu` |
| `LIGHTSAIL_SSH_PRIVATE_KEY` | Full PEM private key, including `BEGIN`/`END` lines |
| `LIGHTSAIL_SSH_KNOWN_HOSTS` | Optional. `ssh-keyscan -H 52.57.207.110` |

Create a GitHub **Environment** named `production` on **fe-oons** (Settings → Environments).

One-shot setup (from a machine with `gh` auth + the PEM):

```bash
cd ~/oons-workspace/fe-oons
gh api -X PUT repos/oons-app/fe-oons/environments/production
PEM=~/Downloads/LightsailDefaultKey-eu-central-1.pem
gh secret set LIGHTSAIL_HOST -R oons-app/fe-oons -e production -b '52.57.207.110'
gh secret set LIGHTSAIL_USER -R oons-app/fe-oons -e production -b 'ubuntu'
gh secret set LIGHTSAIL_SSH_PRIVATE_KEY -R oons-app/fe-oons -e production < "$PEM"
gh secret set LIGHTSAIL_SSH_KNOWN_HOSTS -R oons-app/fe-oons -e production \
  -b "$(ssh-keyscan -H 52.57.207.110 2>/dev/null)"
# Also set as repository secrets (optional; environment secrets are what deploy uses)
```

## Server prerequisites

- SSH with the deploy key
- Write access to `/opt/oonsa/web-root/oons/admin/`
- nginx `web` service already bind-mounts `./web-root` (no container rebuild needed for FE deploys)

## Manual deploy

Actions → **Deploy Lightsail** → **Run workflow**.
