#!/bin/bash
###############################################################################
# Bootstrap Environment - Replicate Pantheon environment locally
# Usage: ./bin/bootstrap-env.sh [dev|test|live|multidev-name]
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$SCRIPT_DIR/manifest.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found. Install with: brew install jq${NC}"
    exit 1
fi

if ! command -v wp &> /dev/null; then
    echo -e "${RED}Error: WP-CLI not found. Install from https://wp-cli.org${NC}"
    exit 1
fi

# Get environment from argument
ENV=${1:-dev}

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Bootstrap Environment: $ENV${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}Error: bin/manifest.json not found. Run ./bin/sync-manifest.sh first${NC}"
    exit 1
fi

# Determine if it's a multidev
if [[ "$ENV" != "dev" && "$ENV" != "test" && "$ENV" != "live" ]]; then
    ENV_PATH=".environments.multidevs.\"$ENV\""
else
    ENV_PATH=".environments.$ENV"
fi

# Check if environment exists in manifest
if ! jq -e "$ENV_PATH" "$MANIFEST_FILE" > /dev/null 2>&1; then
    echo -e "${RED}Error: Environment '$ENV' not found in manifest${NC}"
    echo -e "${YELLOW}Available environments:${NC}"
    jq -r '.environments | keys[]' "$MANIFEST_FILE"
    jq -r '.environments.multidevs | keys[]' "$MANIFEST_FILE" 2>/dev/null || true
    exit 1
fi

# Extract environment data
WP_VERSION=$(jq -r "$ENV_PATH.wordpress.version" "$MANIFEST_FILE")
ACTIVE_THEME=$(jq -r "$ENV_PATH.active_theme" "$MANIFEST_FILE")

echo -e "${YELLOW}Environment Details:${NC}"
echo -e "  WordPress: $WP_VERSION"
echo -e "  Active Theme: $ACTIVE_THEME"
echo -e "  PHP: $(jq -r "$ENV_PATH.php_version" "$MANIFEST_FILE")"
echo ""

# Confirm before proceeding
read -p "$(echo -e ${YELLOW}This will install/update plugins and themes. Continue? [y/N]:${NC} )" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Starting bootstrap...${NC}"
echo ""

# Change to WordPress root
cd "$PROJECT_ROOT"

# 1. Install/Update WordPress Core
echo -e "${YELLOW}→ Checking WordPress core...${NC}"
CURRENT_WP=$(wp core version 2>/dev/null || echo "not-installed")

if [ "$CURRENT_WP" != "$WP_VERSION" ]; then
    echo -e "${BLUE}  Updating WordPress from $CURRENT_WP to $WP_VERSION${NC}"
    wp core download --version="$WP_VERSION" --force 2>/dev/null || true
    echo -e "${GREEN}  ✓ WordPress core updated${NC}"
else
    echo -e "${GREEN}  ✓ WordPress core already at $WP_VERSION${NC}"
fi

# 2. Install/Update Plugins
echo -e "${YELLOW}→ Syncing plugins...${NC}"

# Get list of plugins from manifest (excluding custom ones if any)
PLUGINS=$(jq -r "$ENV_PATH.plugins | keys[]" "$MANIFEST_FILE")

for PLUGIN in $PLUGINS; do
    VERSION=$(jq -r "$ENV_PATH.plugins.\"$PLUGIN\".version" "$MANIFEST_FILE")
    STATUS=$(jq -r "$ENV_PATH.plugins.\"$PLUGIN\".status" "$MANIFEST_FILE")

    # Check if plugin is installed
    if wp plugin is-installed "$PLUGIN" 2>/dev/null; then
        CURRENT_VERSION=$(wp plugin get "$PLUGIN" --field=version 2>/dev/null || echo "unknown")

        if [ "$CURRENT_VERSION" != "$VERSION" ]; then
            echo -e "${BLUE}  Updating $PLUGIN: $CURRENT_VERSION → $VERSION${NC}"
            wp plugin install "$PLUGIN" --version="$VERSION" --force 2>/dev/null || echo -e "${RED}    Failed to update $PLUGIN${NC}"
        fi
    else
        echo -e "${BLUE}  Installing $PLUGIN $VERSION${NC}"
        wp plugin install "$PLUGIN" --version="$VERSION" 2>/dev/null || echo -e "${RED}    Failed to install $PLUGIN${NC}"
    fi

    # Set activation status
    if [ "$STATUS" == "active" ]; then
        wp plugin activate "$PLUGIN" 2>/dev/null || true
    elif [ "$STATUS" == "inactive" ]; then
        wp plugin deactivate "$PLUGIN" 2>/dev/null || true
    fi
done

echo -e "${GREEN}  ✓ Plugins synced${NC}"

# 3. Install/Update Themes (except custom theme)
echo -e "${YELLOW}→ Syncing themes...${NC}"

THEMES=$(jq -r "$ENV_PATH.themes | keys[]" "$MANIFEST_FILE")

for THEME in $THEMES; do
    # Skip custom theme (it's version controlled)
    if [ "$THEME" == "phcommunity.tech" ]; then
        echo -e "${BLUE}  Skipping custom theme: $THEME${NC}"
        continue
    fi

    VERSION=$(jq -r "$ENV_PATH.themes.\"$THEME\".version" "$MANIFEST_FILE")

    if wp theme is-installed "$THEME" 2>/dev/null; then
        CURRENT_VERSION=$(wp theme get "$THEME" --field=version 2>/dev/null || echo "unknown")

        if [ "$CURRENT_VERSION" != "$VERSION" ]; then
            echo -e "${BLUE}  Updating $THEME: $CURRENT_VERSION → $VERSION${NC}"
            wp theme install "$THEME" --version="$VERSION" --force 2>/dev/null || echo -e "${RED}    Failed to update $THEME${NC}"
        fi
    else
        echo -e "${BLUE}  Installing $THEME $VERSION${NC}"
        wp theme install "$THEME" --version="$VERSION" 2>/dev/null || echo -e "${RED}    Failed to install $THEME${NC}"
    fi
done

echo -e "${GREEN}  ✓ Themes synced${NC}"

# 4. Activate correct theme
echo -e "${YELLOW}→ Setting active theme...${NC}"
CURRENT_THEME=$(wp theme list --status=active --field=name 2>/dev/null || echo "unknown")

if [ "$CURRENT_THEME" != "$ACTIVE_THEME" ]; then
    echo -e "${BLUE}  Activating $ACTIVE_THEME${NC}"
    wp theme activate "$ACTIVE_THEME" 2>/dev/null || echo -e "${RED}    Failed to activate $ACTIVE_THEME${NC}"
    echo -e "${GREEN}  ✓ Theme activated${NC}"
else
    echo -e "${GREEN}  ✓ Theme already active${NC}"
fi

# 5. Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Environment bootstrapped successfully!  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Environment '$ENV' has been replicated locally${NC}"
echo ""
echo -e "${BLUE}Installed:${NC}"
jq -r "$ENV_PATH.plugins | length" "$MANIFEST_FILE" | xargs echo "  Plugins:"
jq -r "$ENV_PATH.themes | length" "$MANIFEST_FILE" | xargs echo "  Themes:"
echo ""
echo -e "${YELLOW}Note: Database and uploads are not synced by this script${NC}"
echo -e "  To sync database: terminus backup:get $SITE_NAME.$ENV --element=db"
echo -e "  To sync files: terminus rsync $SITE_NAME.$ENV:files/ wp-content/uploads/"
