#!/bin/bash
###############################################################################
# Sync Manifest - Pull environment state from Pantheon
# Usage: ./bin/sync-manifest.sh [site-name]
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$SCRIPT_DIR/manifest.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if terminus is installed
if ! command -v terminus &> /dev/null; then
    echo -e "${RED}Error: Terminus CLI not found. Install from https://pantheon.io/docs/terminus/install${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found. Install with: brew install jq${NC}"
    exit 1
fi

# Get site name from argument or prompt
if [ -z "$1" ]; then
    SITE_NAME=$(jq -r '.pantheon.site_name' "$MANIFEST_FILE")
    if [ "$SITE_NAME" == "your-site-name" ] || [ -z "$SITE_NAME" ]; then
        read -p "Enter Pantheon site name: " SITE_NAME
    fi
else
    SITE_NAME=$1
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Syncing Manifest from Pantheon           ║${NC}"
echo -e "${BLUE}║  Site: ${SITE_NAME}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Verify site exists
if ! terminus site:info "$SITE_NAME" &> /dev/null; then
    echo -e "${RED}Error: Site '$SITE_NAME' not found or you don't have access${NC}"
    exit 1
fi

# Get site UUID
SITE_UUID=$(terminus site:info "$SITE_NAME" --field=id)

# Function to get environment data
get_env_data() {
    local ENV=$1
    echo -e "${YELLOW}→ Fetching $ENV environment...${NC}"

    # Check if environment exists
    if ! terminus env:info "$SITE_NAME.$ENV" &> /dev/null; then
        echo -e "${RED}  ✗ Environment $ENV not accessible${NC}"
        return 1
    fi

    # Wake the environment
    terminus env:wake "$SITE_NAME.$ENV" &> /dev/null || true

    # Get WordPress version
    WP_VERSION=$(terminus wp "$SITE_NAME.$ENV" -- core version 2>/dev/null || echo "unknown")

    # Get DB version
    DB_VERSION=$(terminus wp "$SITE_NAME.$ENV" -- core version --extra 2>/dev/null | grep 'Database' | awk '{print $3}' || echo "unknown")

    # Get PHP version
    PHP_VERSION=$(terminus env:info "$SITE_NAME.$ENV" --field=php_version 2>/dev/null || echo "unknown")

    # Get plugins list with status and version
    PLUGINS_JSON=$(terminus wp "$SITE_NAME.$ENV" -- plugin list --format=json 2>/dev/null || echo "[]")

    # Get themes list with status and version
    THEMES_JSON=$(terminus wp "$SITE_NAME.$ENV" -- theme list --format=json 2>/dev/null || echo "[]")

    # Get active theme
    ACTIVE_THEME=$(terminus wp "$SITE_NAME.$ENV" -- theme list --status=active --field=name 2>/dev/null || echo "unknown")

    # Get MU plugins (they don't have WP-CLI status, so we list files)
    MU_PLUGINS_JSON=$(terminus wp "$SITE_NAME.$ENV" -- eval 'echo json_encode(get_mu_plugins());' 2>/dev/null || echo "{}")

    # Check if multisite
    IS_MULTISITE=$(terminus wp "$SITE_NAME.$ENV" -- eval 'echo is_multisite() ? "true" : "false";' 2>/dev/null || echo "false")

    # Build JSON structure
    cat <<EOF
{
  "wordpress": {
    "version": "$WP_VERSION",
    "db_version": "$DB_VERSION"
  },
  "php_version": "$PHP_VERSION",
  "plugins": $(echo "$PLUGINS_JSON" | jq 'map({(.name): {version: .version, status: .status, update: .update, update_version: .update_version}}) | add // {}'),
  "themes": $(echo "$THEMES_JSON" | jq 'map({(.name): {version: .version, status: .status, update: .update}}) | add // {}'),
  "mu_plugins": $(echo "$MU_PLUGINS_JSON" | jq 'to_entries | map({(.key): {version: .value.Version, name: .value.Name}}) | add // {}'),
  "active_theme": "$ACTIVE_THEME",
  "multisite": $IS_MULTISITE,
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    echo -e "${GREEN}  ✓ $ENV synced${NC}"
}

# Create temp file for building new manifest
TMP_MANIFEST=$(mktemp)

# Initialize manifest
jq -n \
    --arg site_name "$SITE_NAME" \
    --arg site_id "$SITE_UUID" \
    --arg last_sync "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
        pantheon: {
            site_name: $site_name,
            site_id: $site_id,
            last_sync: $last_sync
        },
        environments: {
            dev: {},
            test: {},
            live: {},
            multidevs: {}
        }
    }' > "$TMP_MANIFEST"

# Sync standard environments
for ENV in dev test live; do
    ENV_DATA=$(get_env_data "$ENV")
    if [ $? -eq 0 ]; then
        TMP_MANIFEST=$(jq --argjson data "$ENV_DATA" ".environments.$ENV = \$data" "$TMP_MANIFEST")
        echo "$TMP_MANIFEST" > "$TMP_MANIFEST.tmp" && mv "$TMP_MANIFEST.tmp" "$TMP_MANIFEST"
    fi
done

# Get multidev environments
echo -e "${YELLOW}→ Fetching multidev environments...${NC}"
MULTIDEVS=$(terminus multidev:list "$SITE_NAME" --format=json 2>/dev/null || echo "[]")
MULTIDEV_COUNT=$(echo "$MULTIDEVS" | jq 'length')

if [ "$MULTIDEV_COUNT" -gt 0 ]; then
    echo -e "${BLUE}  Found $MULTIDEV_COUNT multidev(s)${NC}"

    # Process each multidev
    echo "$MULTIDEVS" | jq -r '.[].id' | while read -r MULTIDEV_NAME; do
        MULTIDEV_DATA=$(get_env_data "$MULTIDEV_NAME")
        if [ $? -eq 0 ]; then
            TMP_MANIFEST=$(jq --arg name "$MULTIDEV_NAME" --argjson data "$MULTIDEV_DATA" \
                ".environments.multidevs[\$name] = \$data" "$TMP_MANIFEST")
            echo "$TMP_MANIFEST" > "$TMP_MANIFEST.tmp" && mv "$TMP_MANIFEST.tmp" "$TMP_MANIFEST"
        fi
    done
else
    echo -e "${BLUE}  No multidev environments found${NC}"
fi

# Save final manifest
cat "$TMP_MANIFEST" | jq '.' > "$MANIFEST_FILE"
rm -f "$TMP_MANIFEST" "$TMP_MANIFEST.tmp"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Manifest synced successfully!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Manifest saved to: $MANIFEST_FILE${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review bin/manifest.json"
echo -e "  2. Commit to git: git add bin/manifest.json && git commit -m 'Update environment manifest'"
echo -e "  3. Bootstrap local: ./bin/bootstrap-env.sh dev"
