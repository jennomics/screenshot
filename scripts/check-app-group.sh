#!/bin/bash
# check-app-group.sh
# Verifies the App Group identifier is IDENTICAL across the three places it must
# match, so the app and the Share Extension actually share one store:
#   1. App/Screenshot.entitlements
#   2. ShareExtension/ShareExtension.entitlements
#   3. ScreenshotKit/.../Store/DataStore.swift  (appGroupID constant)
#
# Xcode's automatic capability management sometimes rewrites the extension's
# group id (e.g. to "group.<team>.ShareExtension"), which silently breaks the
# shared store. Run this to catch that:
#
#     ./scripts/check-app-group.sh
#
# Exit code 0 = all match. Non-zero = mismatch (details printed). Suitable for a
# Run Script build phase or a pre-commit hook.

set -euo pipefail

# Resolve repo root relative to this script so it works from any CWD.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_ENT="$ROOT/App/Screenshot.entitlements"
EXT_ENT="$ROOT/ShareExtension/ShareExtension.entitlements"
STORE="$ROOT/ScreenshotKit/Sources/ScreenshotKit/Store/DataStore.swift"

fail() { echo "❌ App Group check: $1" >&2; exit 1; }

for f in "$APP_ENT" "$EXT_ENT" "$STORE"; do
  [ -f "$f" ] || fail "missing file: $f"
done

# Pull the group.* id from each source.
# Entitlements: the <string> inside the application-groups array.
extract_ent() {
  # grep the first group.* token from the file.
  grep -oE 'group\.[A-Za-z0-9._-]+' "$1" | head -1
}
# DataStore.swift: the appGroupID = "group...." literal.
extract_store() {
  grep -oE 'group\.[A-Za-z0-9._-]+' "$1" | head -1
}

APP_ID="$(extract_ent "$APP_ENT" || true)"
EXT_ID="$(extract_ent "$EXT_ENT" || true)"
STORE_ID="$(extract_store "$STORE" || true)"

[ -n "$APP_ID" ]   || fail "no group id found in App/Screenshot.entitlements"
[ -n "$EXT_ID" ]   || fail "no group id found in ShareExtension/ShareExtension.entitlements"
[ -n "$STORE_ID" ] || fail "no appGroupID found in DataStore.swift"

if [ "$APP_ID" = "$EXT_ID" ] && [ "$APP_ID" = "$STORE_ID" ]; then
  echo "✅ App Group consistent: $APP_ID"
  exit 0
fi

echo "❌ App Group MISMATCH — the app and extension will NOT share a store:" >&2
echo "   App entitlement:        $APP_ID" >&2
echo "   Extension entitlement:  $EXT_ID" >&2
echo "   DataStore.swift:        $STORE_ID" >&2
echo "" >&2
echo "   Fix: make all three identical (usually the app's value). This often" >&2
echo "   happens when Xcode auto-manages the extension's App Groups capability." >&2
exit 1
