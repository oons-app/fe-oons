#!/usr/bin/env bash
# Build a signed App Store IPA for TestFlight (com.oons.oons).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE="${API_BASE:-https://api.oons.app}"
PUBLIC_WEB_BASE="${PUBLIC_WEB_BASE:-https://lady.oons.app}"
EXPORT_PLIST="${EXPORT_PLIST:-ios/ExportOptions-AppStore.plist}"

echo "→ pod install"
(cd ios && pod install --silent)

echo "→ flutter build ipa (App Store / TestFlight)"
flutter build ipa --release \
  --export-options-plist="$EXPORT_PLIST" \
  --dart-define="API_BASE=$API_BASE" \
  --dart-define="PUBLIC_WEB_BASE=$PUBLIC_WEB_BASE"

IPA=$(ls -1 build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)
echo ""
echo "IPA: ${IPA:-not found}"
echo "Upload with Transporter or:"
echo "  xcrun altool --upload-app -f \"$IPA\" -t ios --apiKey KEY --apiIssuer ISSUER"
echo "Or: open -a Transporter \"$IPA\""
