#!/bin/bash
###############################################################################
# Save Local to Manifest - Capture local WordPress state and save to manifest
# Usage: ./bin/save-local-to-manifest.sh [--env=dev|local]
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXCLUDE_FILE="$SCRIPT_DIR/manifest-exclude.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
TARGET_ENV="local"
for arg in "$@"; do
    case $arg in
        --env=*)
            TARGET_ENV="${arg#*=}"
            shift
            ;;
        *)
            ;;
    esac
done

# Set manifest file based on target environment
MANIFEST_FILE="$SCRIPT_DIR/manifest.${TARGET_ENV}.json"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found. Install with: brew install jq${NC}"
    exit 1
fi

# Check if WP-CLI is available
if ! command -v wp &> /dev/null; then
    echo -e "${RED}Error: WP-CLI not found. Install from https://wp-cli.org${NC}"
    exit 1
fi

# Change to WordPress root
cd "$PROJECT_ROOT"

# Verify WordPress is installed
if [ ! -f "wp-config.php" ]; then
    echo -e "${RED}Error: wp-config.php not found. Is WordPress installed?${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Save Local State to Manifest             ║${NC}"
echo -e "${BLUE}║  Target Environment: ${TARGET_ENV}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Load exclusions from file (skip comments and empty lines)
if [ -f "$EXCLUDE_FILE" ]; then
    EXCLUDED_ITEMS=$(grep -v '^#' "$EXCLUDE_FILE" | grep -v '^[[:space:]]*$' | tr '\n' ',' | sed 's/,$//')
else
    EXCLUDED_ITEMS=""
fi

# Get WordPress version
echo -e "${YELLOW}→ Reading WordPress core version...${NC}"
WP_VERSION=$(wp core version 2>&1 | grep -E '^[0-9]' | head -1 || echo "unknown")
DB_VERSION=$(wp core version --extra 2>&1 | grep 'Database' | awk '{print $3}' || echo "unknown")

# Get PHP version
PHP_VERSION=$(php -r "echo PHP_VERSION;" 2>&1 | grep -E '^[0-9]' | head -1 || echo "unknown")

# Get plugins list
echo -e "${YELLOW}→ Reading plugins...${NC}"
PLUGINS_JSON=$(wp plugin list --format=json 2>&1 | grep -E '^\[' || echo "[]")

# Get themes list
echo -e "${YELLOW}→ Reading themes...${NC}"
THEMES_JSON=$(wp theme list --format=json 2>&1 | grep -E '^\[' || echo "[]")

# Get active theme
ACTIVE_THEME=$(wp theme list --status=active --field=name 2>&1 | grep -v '^Warning:' | grep -v '^Failed' | grep -v 'Xdebug' | grep -v 'API version' | grep -v 'These options' | grep -v 'Notice:' | grep -v 'Undefined index' | grep -v 'Module compiled' | grep -v 'PHP    compiled' | grep -v 'in Unknown' | grep -v 'symbol not found' | grep -v 'dlopen' | grep -v '^$' | head -1 || echo "unknown")

# Get MU plugins
MU_PLUGINS_JSON=$(wp eval 'echo json_encode(get_mu_plugins());' 2>&1 | grep -E '^\{' || echo "{}")

# Check if multisite
IS_MULTISITE=$(wp eval 'echo is_multisite() ? "true" : "false";' 2>&1 | grep -E '^(true|false)' || echo "false")

# Process JSON data and filter exclusions
if [ -n "$EXCLUDED_ITEMS" ]; then
    EXCLUDED_FILTER=$(echo "$EXCLUDED_ITEMS" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
    PLUGINS_OBJ=$(echo "$PLUGINS_JSON" | jq --argjson excluded "[$EXCLUDED_FILTER]" 'map(select(.name as $name | $excluded | index($name) | not)) | map({(.name): {version: .version, status: .status, update: .update, update_version: .update_version}}) | add // {}' 2>/dev/null || echo "{}")
    THEMES_OBJ=$(echo "$THEMES_JSON" | jq --argjson excluded "[$EXCLUDED_FILTER]" 'map(select(.name as $name | $excluded | index($name) | not)) | map({(.name): {version: .version, status: .status, update: .update}}) | add // {}' 2>/dev/null || echo "{}")
else
    PLUGINS_OBJ=$(echo "$PLUGINS_JSON" | jq 'map({(.name): {version: .version, status: .status, update: .update, update_version: .update_version}}) | add // {}' 2>/dev/null || echo "{}")
    THEMES_OBJ=$(echo "$THEMES_JSON" | jq 'map({(.name): {version: .version, status: .status, update: .update}}) | add // {}' 2>/dev/null || echo "{}")
fi
MU_PLUGINS_OBJ=$(echo "$MU_PLUGINS_JSON" | jq 'to_entries | map({(.key): {version: .value.Version, name: .value.Name}}) | add // {}' 2>/dev/null || echo "{}")

# Build environment data
ENV_DATA=$(jq -n \
    --arg site_name "local" \
    --arg site_id "local-dev" \
    --arg environment "$TARGET_ENV" \
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
        site_name: $site_name,
        site_id: $site_id,
        environment: $environment,
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
    }')

# Update manifest file - store environment data directly
echo "$ENV_DATA" | jq '.' > "$MANIFEST_FILE"

# Get counts
PLUGIN_COUNT=$(echo "$PLUGINS_OBJ" | jq 'length')
THEME_COUNT=$(echo "$THEMES_OBJ" | jq 'length')

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Local state saved to manifest!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  Environment: ${TARGET_ENV}"
echo -e "  WordPress: ${WP_VERSION}"
echo -e "  PHP: ${PHP_VERSION}"
echo -e "  Plugins: ${PLUGIN_COUNT}"
echo -e "  Themes: ${THEME_COUNT}"
echo -e "  Active Theme: ${ACTIVE_THEME}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review bin/manifest.${TARGET_ENV}.json"
echo -e "  2. Commit to git: git add bin/manifest.${TARGET_ENV}.json && git commit -m 'Update ${TARGET_ENV} manifest'"
echo ""
