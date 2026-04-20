#!/bin/bash
###############################################################################
# Local Install - Install WordPress, plugins, and themes from manifest
# Usage: ./bin/local-install.sh [--force] [--source-env=dev]
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$SCRIPT_DIR/manifest.json"
EXCLUDE_FILE="$SCRIPT_DIR/manifest-exclude.txt"

# Load exclusions from file (skip comments and empty lines)
if [ -f "$EXCLUDE_FILE" ]; then
    EXCLUDED_ITEMS=$(grep -v '^#' "$EXCLUDE_FILE" | grep -v '^[[:space:]]*$')
else
    EXCLUDED_ITEMS=""
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
FORCE=false
SOURCE_ENV="dev"

for arg in "$@"; do
    case $arg in
        --force)
            FORCE=true
            shift
            ;;
        --source-env=*)
            SOURCE_ENV="${arg#*=}"
            shift
            ;;
        *)
            ;;
    esac
done

# Check if manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}Error: Manifest file not found at $MANIFEST_FILE${NC}"
    echo "Run ./bin/sync-manifest.sh first to create the manifest"
    exit 1
fi

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
echo -e "${BLUE}║  Installing from Manifest (Local)         ║${NC}"
echo -e "${BLUE}║  Source Environment: ${SOURCE_ENV}${NC}"
echo -e "${BLUE}║  Force Mode: ${FORCE}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Extract environment data from manifest
ENV_DATA=$(jq -r ".environments.$SOURCE_ENV" "$MANIFEST_FILE")

if [ "$ENV_DATA" == "null" ] || [ "$ENV_DATA" == "{}" ]; then
    echo -e "${RED}Error: Environment '$SOURCE_ENV' not found in manifest${NC}"
    echo "Available environments:"
    jq -r '.environments | keys[]' "$MANIFEST_FILE"
    exit 1
fi

# Get versions
WP_VERSION=$(echo "$ENV_DATA" | jq -r '.wordpress.version // "unknown"')
ACTIVE_THEME=$(echo "$ENV_DATA" | jq -r '.active_theme // "unknown"')

echo -e "${YELLOW}Target WordPress version: ${WP_VERSION}${NC}"
echo -e "${YELLOW}Active theme: ${ACTIVE_THEME}${NC}"
echo ""

# Install/Update WordPress Core
if [ "$WP_VERSION" != "unknown" ]; then
    CURRENT_WP_VERSION=$(wp core version 2>/dev/null || echo "not-installed")

    if [ "$CURRENT_WP_VERSION" != "$WP_VERSION" ] || [ "$FORCE" = true ]; then
        echo -e "${BLUE}→ Installing WordPress ${WP_VERSION}...${NC}"

        if [ "$FORCE" = true ]; then
            wp core download --version="$WP_VERSION" --force
        else
            wp core update --version="$WP_VERSION" || wp core download --version="$WP_VERSION" --force
        fi

        echo -e "${GREEN}  ✓ WordPress ${WP_VERSION} installed${NC}"
    else
        echo -e "${GREEN}✓ WordPress ${WP_VERSION} already installed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ WordPress version unknown, skipping core installation${NC}"
fi

echo ""

# Install Plugins
echo -e "${BLUE}→ Installing plugins...${NC}"
PLUGIN_COUNT=$(echo "$ENV_DATA" | jq -r '.plugins | length')
SKIPPED_COUNT=0

if [ "$PLUGIN_COUNT" -gt 0 ]; then
    echo "$ENV_DATA" | jq -r '.plugins | to_entries[] | "\(.key)|\(.value.version)|\(.value.status)"' | while IFS='|' read -r PLUGIN_SLUG PLUGIN_VERSION PLUGIN_STATUS; do
        # Skip if plugin is in exclusion list
        if echo "$EXCLUDED_ITEMS" | grep -q "^${PLUGIN_SLUG}$"; then
            echo -e "  ${YELLOW}Skipping excluded plugin: ${PLUGIN_SLUG}${NC}"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        INSTALLED_VERSION=$(wp plugin get "$PLUGIN_SLUG" --field=version 2>/dev/null || echo "not-installed")

        if [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ] || [ "$FORCE" = true ]; then
            echo -e "  Installing ${PLUGIN_SLUG} ${PLUGIN_VERSION}..."

            # Install or update the plugin
            if [ "$INSTALLED_VERSION" = "not-installed" ]; then
                wp plugin install "$PLUGIN_SLUG" --version="$PLUGIN_VERSION" 2>/dev/null || echo -e "    ${YELLOW}⚠ Could not install ${PLUGIN_SLUG}${NC}"
            else
                wp plugin update "$PLUGIN_SLUG" --version="$PLUGIN_VERSION" 2>/dev/null || wp plugin install "$PLUGIN_SLUG" --version="$PLUGIN_VERSION" --force 2>/dev/null || echo -e "    ${YELLOW}⚠ Could not update ${PLUGIN_SLUG}${NC}"
            fi
        fi

        # Activate or deactivate based on manifest status
        if [ "$PLUGIN_STATUS" = "active" ]; then
            wp plugin activate "$PLUGIN_SLUG" 2>/dev/null || true
        elif [ "$PLUGIN_STATUS" = "inactive" ]; then
            wp plugin deactivate "$PLUGIN_SLUG" 2>/dev/null || true
        fi
    done
    echo -e "${GREEN}  ✓ ${PLUGIN_COUNT} plugins processed${NC}"
else
    echo -e "${YELLOW}  No plugins in manifest${NC}"
fi

echo ""

# Install Themes
echo -e "${BLUE}→ Installing themes...${NC}"
THEME_COUNT=$(echo "$ENV_DATA" | jq -r '.themes | length')

if [ "$THEME_COUNT" -gt 0 ]; then
    echo "$ENV_DATA" | jq -r '.themes | to_entries[] | "\(.key)|\(.value.version)|\(.value.status)"' | while IFS='|' read -r THEME_SLUG THEME_VERSION THEME_STATUS; do
        # Skip if theme is in exclusion list
        if echo "$EXCLUDED_ITEMS" | grep -q "^${THEME_SLUG}$"; then
            echo -e "  ${YELLOW}Skipping excluded theme: ${THEME_SLUG}${NC}"
            continue
        fi
        INSTALLED_VERSION=$(wp theme get "$THEME_SLUG" --field=version 2>/dev/null || echo "not-installed")

        if [ "$INSTALLED_VERSION" != "$THEME_VERSION" ] || [ "$FORCE" = true ]; then
            echo -e "  Installing ${THEME_SLUG} ${THEME_VERSION}..."

            # Install or update the theme
            if [ "$INSTALLED_VERSION" = "not-installed" ]; then
                wp theme install "$THEME_SLUG" --version="$THEME_VERSION" 2>/dev/null || echo -e "    ${YELLOW}⚠ Could not install ${THEME_SLUG}${NC}"
            else
                wp theme update "$THEME_SLUG" --version="$THEME_VERSION" 2>/dev/null || wp theme install "$THEME_SLUG" --version="$THEME_VERSION" --force 2>/dev/null || echo -e "    ${YELLOW}⚠ Could not update ${THEME_SLUG}${NC}"
            fi
        fi
    done
    echo -e "${GREEN}  ✓ ${THEME_COUNT} themes processed${NC}"
else
    echo -e "${YELLOW}  No themes in manifest${NC}"
fi

echo ""

# Activate the active theme
if [ "$ACTIVE_THEME" != "unknown" ]; then
    CURRENT_THEME=$(wp theme list --status=active --field=name 2>/dev/null || echo "unknown")

    if [ "$CURRENT_THEME" != "$ACTIVE_THEME" ] || [ "$FORCE" = true ]; then
        echo -e "${BLUE}→ Activating theme: ${ACTIVE_THEME}${NC}"
        wp theme activate "$ACTIVE_THEME" 2>/dev/null || echo -e "${YELLOW}⚠ Could not activate theme ${ACTIVE_THEME}${NC}"
        echo -e "${GREEN}  ✓ Theme activated${NC}"
    else
        echo -e "${GREEN}✓ Theme ${ACTIVE_THEME} already active${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Installation complete!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  WordPress: ${WP_VERSION}"
echo -e "  Plugins: ${PLUGIN_COUNT}"
echo -e "  Themes: ${THEME_COUNT}"
echo -e "  Active Theme: ${ACTIVE_THEME}"
echo ""
echo -e "${YELLOW}Note: Custom themes in wp-content/themes/ are managed by git${NC}"
echo -e "${YELLOW}Note: MU plugins are not managed by this script${NC}"
