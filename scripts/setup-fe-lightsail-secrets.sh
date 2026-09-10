#!/usr/bin/env bash
# Wire Lightsail deploy secrets on oons-app/fe-oons (production environment).
# Requires: gh auth login  OR  GH_TOKEN with repo admin + secrets write
# Usage: ./scripts/setup-fe-lightsail-secrets.sh [path-to.pem]
set -euo pipefail
PEM="${1:-$HOME/Downloads/LightsailDefaultKey-eu-central-1.pem}"
REPO=oons-app/fe-oons
HOST=52.57.207.110

if [[ ! -f "$PEM" ]]; then
  echo "PEM not found: $PEM" >&2
  exit 1
fi

gh api -X PUT "repos/${REPO}/environments/production" >/dev/null
gh secret set LIGHTSAIL_HOST -R "$REPO" -e production -b "$HOST"
gh secret set LIGHTSAIL_USER -R "$REPO" -e production -b 'ubuntu'
gh secret set LIGHTSAIL_SSH_PRIVATE_KEY -R "$REPO" -e production < "$PEM"
gh secret set LIGHTSAIL_SSH_KNOWN_HOSTS -R "$REPO" -e production \
  -b "$(ssh-keyscan -H "$HOST" 2>/dev/null)"

# Repo-level copies (handy if a job forgets environment:)
gh secret set LIGHTSAIL_HOST -R "$REPO" -b "$HOST"
gh secret set LIGHTSAIL_USER -R "$REPO" -b 'ubuntu'
gh secret set LIGHTSAIL_SSH_PRIVATE_KEY -R "$REPO" < "$PEM"
gh secret set LIGHTSAIL_SSH_KNOWN_HOSTS -R "$REPO" \
  -b "$(ssh-keyscan -H "$HOST" 2>/dev/null)"

echo "OK: secrets set on ${REPO} (production + repo)."
