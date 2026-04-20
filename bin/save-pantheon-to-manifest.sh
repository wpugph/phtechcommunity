#!/bin/bash
###############################################################################
# Save Pantheon to Manifest - Capture Pantheon environment state to manifest
#
# This script fetches WordPress, plugin, and theme versions from Pantheon
# environments (dev, test, live) and saves them to bin/manifest.json
#
# Usage: ./bin/save-pantheon-to-manifest.sh [site-name] [--yes]
#
# Arguments:
#   site-name    Pantheon site name (default: from existing manifest)
#   --yes        Skip confirmation prompt and run immediately
#
# Examples:
#   ./bin/save-pantheon-to-manifest.sh                    # Interactive mode
#   ./bin/save-pantheon-to-manifest.sh eventsph           # Specify site
#   ./bin/save-pantheon-to-manifest.sh eventsph --yes     # Auto-confirm
#
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$SCRIPT_DIR/manifest.json"
EXCLUDE_FILE="$SCRIPT_DIR/manifest-exclude.txt"

# Load exclusions from file (skip comments and empty lines)
if [ -f "$EXCLUDE_FILE" ]; then
    EXCLUDED_ITEMS=$(grep -v '^#' "$EXCLUDE_FILE" | grep -v '^[[:space:]]*$' | tr '\n' ',' | sed 's/,$//')
else
    EXCLUDED_ITEMS=""
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Parse arguments
AUTO_CONFIRM=false
SITE_NAME=""

for arg in "$@"; do
    case $arg in
        --yes|-y)
            AUTO_CONFIRM=true
            shift
            ;;
        *)
            if [ -z "$SITE_NAME" ]; then
                SITE_NAME=$arg
            fi
            shift
            ;;
    esac
done

# Get site name from argument or prompt
if [ -z "$SITE_NAME" ]; then
    if [ -f "$MANIFEST_FILE" ]; then
        SITE_NAME=$(jq -r '.pantheon.site_name' "$MANIFEST_FILE" 2>/dev/null)
    fi
    if [ "$SITE_NAME" == "your-site-name" ] || [ -z "$SITE_NAME" ] || [ "$SITE_NAME" == "null" ]; then
        read -p "Enter Pantheon site name: " SITE_NAME
    fi
fi

# Verify site exists
if ! terminus site:info "$SITE_NAME" &> /dev/null; then
    echo -e "${RED}Error: Site '$SITE_NAME' not found or you don't have access${NC}"
    echo -e "${YELLOW}Tip: Run 'terminus site:list' to see available sites${NC}"
    exit 1
fi

# Get site UUID
SITE_UUID=$(terminus site:info "$SITE_NAME" --field=id)

# Display what will happen
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Save Pantheon Environments to Manifest                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}What this script will do:${NC}"
echo ""
echo -e "  1. Connect to Pantheon site: ${YELLOW}${SITE_NAME}${NC}"
echo -e "  2. Fetch state from environments: ${YELLOW}dev, test, live${NC}"
echo -e "  3. Capture for each environment:"
echo -e "     • WordPress core version"
echo -e "     • PHP version"
echo -e "     • All plugins (versions, status, updates)"
echo -e "     • All themes (versions, status, updates)"
echo -e "     • MU plugins"
echo -e "     • Active theme"
echo -e "  4. Save all data to: ${YELLOW}bin/manifest.json${NC}"
echo ""

# Show exclusions if any
if [ -n "$EXCLUDED_ITEMS" ]; then
    EXCLUSION_COUNT=$(echo "$EXCLUDED_ITEMS" | tr ',' '\n' | wc -l | xargs)
    echo -e "${BLUE}Exclusions (from bin/manifest-exclude.txt):${NC}"
    echo -e "  ${EXCLUSION_COUNT} plugin(s)/theme(s) will be excluded:"
    echo "$EXCLUDED_ITEMS" | tr ',' '\n' | sed 's/^/    • /'
    echo ""
fi

echo -e "${BLUE}Note:${NC}"
echo -e "  • Multidev environments will be ${YELLOW}skipped${NC} (only dev, test, live)"
echo -e "  • This will ${YELLOW}overwrite${NC} existing manifest data"
echo -e "  • The process takes ${YELLOW}~2-3 minutes${NC} depending on environment size"
echo ""

# Confirmation prompt (unless --yes flag is used)
if [ "$AUTO_CONFIRM" = false ]; then
    read -p "$(echo -e ${YELLOW}Continue? [y/N]:${NC} )" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Starting Pantheon Sync                    ║${NC}"
echo -e "${BLUE}║  Site: ${SITE_NAME}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Function to get environment data
get_env_data() {
    local ENV=$1
    echo -e "${YELLOW}→ Fetching $ENV environment...${NC}" >&2

    # Check if environment exists
    if ! terminus env:info "$SITE_NAME.$ENV" &> /dev/null; then
        echo -e "${RED}  ✗ Environment $ENV not accessible${NC}" >&2
        return 1
    fi

    # Wake the environment
    terminus env:wake "$SITE_NAME.$ENV" &> /dev/null || true

    # Get WordPress version (filter out Terminus noise)
    WP_VERSION=$(terminus wp "$SITE_NAME.$ENV" -- core version 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep -E "^[0-9]" || echo "unknown")

    # Get DB version
    DB_VERSION=$(terminus wp "$SITE_NAME.$ENV" -- core version --extra 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep 'Database' | awk '{print $3}' || echo "unknown")

    # Get PHP version
    PHP_VERSION=$(terminus env:info "$SITE_NAME.$ENV" --field=php_version 2>/dev/null || echo "unknown")

    # Get plugins list with status and version (filter Terminus output noise)
    PLUGINS_JSON=$(terminus wp "$SITE_NAME.$ENV" -- plugin list --format=json 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep -v "^Fatal" | grep "^\[" || echo "[]")

    # Get themes list with status and version (filter Terminus output noise)
    THEMES_JSON=$(terminus wp "$SITE_NAME.$ENV" -- theme list --format=json 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep -v "^Fatal" | grep "^\[" || echo "[]")

    # Get active theme (filter Terminus noise)
    ACTIVE_THEME=$(terminus wp "$SITE_NAME.$ENV" -- theme list --status=active --field=name 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep -v "^Fatal" | head -1 || echo "unknown")

    # Get MU plugins (filter Terminus noise)
    MU_PLUGINS_JSON=$(terminus wp "$SITE_NAME.$ENV" -- eval 'echo json_encode(get_mu_plugins());' 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep -v "^Fatal" | grep "^{" || echo "{}")

    # Check if multisite (filter Terminus noise)
    IS_MULTISITE=$(terminus wp "$SITE_NAME.$ENV" -- eval 'echo is_multisite() ? "true" : "false";' 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | grep -v "^Fatal" | grep -E "^(true|false)" || echo "false")

    # Process JSON data before building output (to catch errors)
    # Filter out excluded plugins and themes
    if [ -n "$EXCLUDED_ITEMS" ]; then
        EXCLUDED_FILTER=$(echo "$EXCLUDED_ITEMS" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
        PLUGINS_OBJ=$(echo "$PLUGINS_JSON" | jq --argjson excluded "[$EXCLUDED_FILTER]" 'map(select(.name as $name | $excluded | index($name) | not)) | map({(.name): {version: .version, status: .status, update: .update, update_version: .update_version}}) | add // {}' 2>/dev/null || echo "{}")
        THEMES_OBJ=$(echo "$THEMES_JSON" | jq --argjson excluded "[$EXCLUDED_FILTER]" 'map(select(.name as $name | $excluded | index($name) | not)) | map({(.name): {version: .version, status: .status, update: .update}}) | add // {}' 2>/dev/null || echo "{}")
    else
        PLUGINS_OBJ=$(echo "$PLUGINS_JSON" | jq 'map({(.name): {version: .version, status: .status, update: .update, update_version: .update_version}}) | add // {}' 2>/dev/null || echo "{}")
        THEMES_OBJ=$(echo "$THEMES_JSON" | jq 'map({(.name): {version: .version, status: .status, update: .update}}) | add // {}' 2>/dev/null || echo "{}")
    fi
    MU_PLUGINS_OBJ=$(echo "$MU_PLUGINS_JSON" | jq 'to_entries | map({(.key): {version: .value.Version, name: .value.Name}}) | add // {}' 2>/dev/null || echo "{}")

    # Build JSON structure using jq (cleaner and safer than heredoc)
    jq -n \
        --arg wp_version "$WP_VERSION" \
        --arg db_version "$DB_VERSION" \
        --arg php_version "$PHP_VERSION" \
        --argjson plugins "$PLUGINS_OBJ" \
        --argjson themes "$THEMES_OBJ" \
        --argjson mu_plugins "$MU_PLUGINS_OBJ" \
        --arg active_theme "$ACTIVE_THEME" \
        --argjson multisite "$IS_MULTISITE" \
        --arg last_updated "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            wordpress: {
                version: $wp_version,
                db_version: $db_version
            },
            php_version: $php_version,
            plugins: $plugins,
            themes: $themes,
            mu_plugins: $mu_plugins,
            active_theme: $active_theme,
            multisite: $multisite,
            last_updated: $last_updated
        }'

    echo -e "${GREEN}  ✓ $ENV synced${NC}" >&2
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
        jq --argjson data "$ENV_DATA" ".environments.$ENV = \$data" "$TMP_MANIFEST" > "$TMP_MANIFEST.tmp"
        mv "$TMP_MANIFEST.tmp" "$TMP_MANIFEST"
    fi
done

# Skip multidev environments for now (can be added manually if needed)
# Multidevs add significant time and complexity to the sync process
echo -e "${BLUE}  Skipping multidev environments (focusing on dev, test, live)${NC}" >&2

# Save final manifest
cat "$TMP_MANIFEST" | jq '.' > "$MANIFEST_FILE"
rm -f "$TMP_MANIFEST" "$TMP_MANIFEST.tmp"

echo "" >&2
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}" >&2
echo -e "${GREEN}║  ✓ Manifest saved successfully!            ║${NC}" >&2
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}" >&2
echo -e "${BLUE}Manifest saved to: $MANIFEST_FILE${NC}" >&2
echo "" >&2
echo -e "${YELLOW}Next steps:${NC}" >&2
echo -e "  1. Review bin/manifest.json" >&2
echo -e "  2. Commit to git: git add bin/manifest.json && git commit -m 'Update manifest from Pantheon'" >&2
echo -e "  3. Sync local: ./bin/local-install-from-manifest.sh" >&2
echo "" >&2
