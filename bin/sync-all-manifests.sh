#!/usr/bin/env bash
#
# Sync manifests from Pantheon for specified environments
# Usage: sync-all-manifests.sh SITE_NAME ENVIRONMENTS
#   ENVIRONMENTS: "all" or comma-separated list like "dev,test,live"
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SITE_NAME="${1:?Site name required}"
SYNC_ENVS="${2:-all}"

echo "🔄 Syncing manifest from Pantheon..."

# Verify site exists and get UUID
echo "Verifying site access..."
if ! SITE_UUID=$(terminus site:info "$SITE_NAME" --field=id 2>&1); then
  echo "❌ ERROR: Cannot access site '$SITE_NAME'"
  echo "Terminus output:"
  terminus site:info "$SITE_NAME" 2>&1 | head -10
  exit 1
fi
echo "✓ Site UUID: $SITE_UUID"

# Determine which environments to sync
if [ "$SYNC_ENVS" = "all" ]; then
  ENVS_TO_SYNC="dev test live"
else
  ENVS_TO_SYNC=$(echo "$SYNC_ENVS" | tr ',' ' ')
fi

echo ""
echo "📋 Environments to sync: $ENVS_TO_SYNC"
echo ""

# Sync each environment to its own file
for ENV in $ENVS_TO_SYNC; do
  if [ "$ENV" = "dev" ] || [ "$ENV" = "test" ] || [ "$ENV" = "live" ]; then
    echo "→ Syncing $ENV to manifest.$ENV.json..." >&2
    ENV_DATA=$("$SCRIPT_DIR/fetch-pantheon-manifest.sh" "$SITE_NAME" "$ENV")
    echo "$ENV_DATA" | jq '.' > "bin/manifest.$ENV.json"
    echo "  ✅ Saved bin/manifest.$ENV.json" >&2
  fi
done

# Get multidevs (only if syncing "all")
if [ "$SYNC_ENVS" = "all" ]; then
  echo "→ Checking for multidev environments..." >&2
  MULTIDEVS=$(terminus multidev:list "$SITE_NAME" --format=json 2>/dev/null || echo "[]")
  MULTIDEV_COUNT=$(echo "$MULTIDEVS" | jq 'length')

  if [ "$MULTIDEV_COUNT" -gt 0 ]; then
    echo "  Found $MULTIDEV_COUNT multidev(s)" >&2
    echo "$MULTIDEVS" | jq -r '.[].id' | while read -r MULTIDEV_NAME; do
      echo "  → Syncing $MULTIDEV_NAME to manifest.$MULTIDEV_NAME.json..." >&2
      MULTIDEV_DATA=$("$SCRIPT_DIR/fetch-pantheon-manifest.sh" "$SITE_NAME" "$MULTIDEV_NAME")
      echo "$MULTIDEV_DATA" | jq '.' > "bin/manifest.$MULTIDEV_NAME.json"
      echo "    ✅ Saved bin/manifest.$MULTIDEV_NAME.json" >&2
    done
  else
    echo "  No multidev environments found" >&2
  fi
else
  echo "  Skipping multidev environments (not included in sync)" >&2
fi

echo "✅ Manifests synced successfully!" >&2
