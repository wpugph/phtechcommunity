#!/bin/bash
###############################################################################
# Local Install - Install WordPress, plugins, and themes from manifest
#
# This script compares your local WordPress installation with the manifest
# and only installs/updates what's different. It's fast and efficient by default.
#
# Usage: ./bin/local-install.sh [--force] [--source-env=dev] [--yes]
#
# Arguments:
#   --source-env=ENV   Environment to sync from (dev, test, live, local)
#   --force            Force reinstall even if versions match
#   --yes              Skip confirmation prompt
#
# Examples:
#   ./bin/local-install.sh                    # Interactive, sync from dev
#   ./bin/local-install.sh --yes              # Auto-confirm
#   ./bin/local-install.sh --source-env=live  # Sync from live
#   ./bin/local-install.sh --force            # Force reinstall everything
#
###############################################################################

# Ensure script is run with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires bash. Please run with:"
    echo "  ./bin/local-install.sh"
    echo "or:"
    echo "  bash bin/local-install.sh"
    exit 1
fi

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
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
FORCE=false
SOURCE_ENV="dev"
AUTO_CONFIRM=false

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
        --yes|-y)
            AUTO_CONFIRM=true
            shift
            ;;
        *)
            ;;
    esac
done

# Check if manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}Error: Manifest file not found at $MANIFEST_FILE${NC}"
    echo "Run ./bin/save-pantheon-to-manifest.sh first to create the manifest"
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

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Sync Local from Manifest                                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Extract environment data from manifest
ENV_DATA=$(jq -r ".environments.$SOURCE_ENV" "$MANIFEST_FILE")

if [ "$ENV_DATA" == "null" ] || [ "$ENV_DATA" == "{}" ]; then
    echo -e "${RED}Error: Environment '$SOURCE_ENV' not found in manifest${NC}"
    echo "Available environments:"
    jq -r '.environments | keys[]' "$MANIFEST_FILE"
    exit 1
fi

# Get versions from manifest
WP_VERSION=$(echo "$ENV_DATA" | jq -r '.wordpress.version // "unknown"')
ACTIVE_THEME=$(echo "$ENV_DATA" | jq -r '.active_theme // "unknown"')
PLUGIN_COUNT=$(echo "$ENV_DATA" | jq -r '.plugins | length')
THEME_COUNT=$(echo "$ENV_DATA" | jq -r '.themes | length')

echo -e "${BLUE}Comparing local installation with manifest...${NC}"
echo ""

# Check current WordPress version
CURRENT_WP_VERSION=$(wp core version 2>/dev/null || echo "not-installed")
CURRENT_THEME=$(wp theme list --status=active --field=name 2>/dev/null || echo "unknown")

# Initialize counters
WP_ACTION=""
PLUGINS_TO_INSTALL=()
PLUGINS_TO_UPDATE=()
PLUGINS_TO_ACTIVATE=()
PLUGINS_TO_DEACTIVATE=()
PLUGINS_SKIPPED=0
THEMES_TO_INSTALL=()
THEMES_TO_UPDATE=()
THEMES_SKIPPED=0
THEME_TO_ACTIVATE=""

# Check WordPress core
if [ "$WP_VERSION" != "unknown" ]; then
    if [ "$CURRENT_WP_VERSION" = "not-installed" ]; then
        WP_ACTION="install"
    elif [ "$CURRENT_WP_VERSION" != "$WP_VERSION" ] || [ "$FORCE" = true ]; then
        WP_ACTION="update"
    else
        WP_ACTION="skip"
    fi
fi

# Check plugins
if [ "$PLUGIN_COUNT" -gt 0 ]; then
    while IFS='|' read -r PLUGIN_SLUG PLUGIN_VERSION PLUGIN_STATUS; do
        # Skip if plugin is in exclusion list
        if echo "$EXCLUDED_ITEMS" | grep -q "^${PLUGIN_SLUG}$"; then
            PLUGINS_SKIPPED=$((PLUGINS_SKIPPED + 1))
            continue
        fi

        INSTALLED_VERSION=$(wp plugin get "$PLUGIN_SLUG" --field=version 2>/dev/null || echo "not-installed")
        INSTALLED_STATUS=$(wp plugin get "$PLUGIN_SLUG" --field=status 2>/dev/null || echo "not-installed")

        # Check if needs install/update
        if [ "$INSTALLED_VERSION" = "not-installed" ]; then
            PLUGINS_TO_INSTALL+=("$PLUGIN_SLUG|$PLUGIN_VERSION|$PLUGIN_STATUS")
        elif [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ] || [ "$FORCE" = true ]; then
            PLUGINS_TO_UPDATE+=("$PLUGIN_SLUG|$PLUGIN_VERSION|$PLUGIN_STATUS")
        else
            # Check activation status
            if [ "$PLUGIN_STATUS" = "active" ] && [ "$INSTALLED_STATUS" != "active" ]; then
                PLUGINS_TO_ACTIVATE+=("$PLUGIN_SLUG")
            elif [ "$PLUGIN_STATUS" = "inactive" ] && [ "$INSTALLED_STATUS" = "active" ]; then
                PLUGINS_TO_DEACTIVATE+=("$PLUGIN_SLUG")
            fi
        fi
    done < <(echo "$ENV_DATA" | jq -r '.plugins | to_entries[] | "\(.key)|\(.value.version)|\(.value.status)"')
fi

# Check themes
if [ "$THEME_COUNT" -gt 0 ]; then
    while IFS='|' read -r THEME_SLUG THEME_VERSION THEME_STATUS; do
        # Skip if theme is in exclusion list
        if echo "$EXCLUDED_ITEMS" | grep -q "^${THEME_SLUG}$"; then
            THEMES_SKIPPED=$((THEMES_SKIPPED + 1))
            continue
        fi

        INSTALLED_VERSION=$(wp theme get "$THEME_SLUG" --field=version 2>/dev/null || echo "not-installed")

        # Check if needs install/update
        if [ "$INSTALLED_VERSION" = "not-installed" ]; then
            THEMES_TO_INSTALL+=("$THEME_SLUG|$THEME_VERSION")
        elif [ "$INSTALLED_VERSION" != "$THEME_VERSION" ] || [ "$FORCE" = true ]; then
            THEMES_TO_UPDATE+=("$THEME_SLUG|$THEME_VERSION")
        fi
    done < <(echo "$ENV_DATA" | jq -r '.themes | to_entries[] | "\(.key)|\(.value.version)"')
fi

# Check active theme
if [ "$ACTIVE_THEME" != "unknown" ] && [ "$CURRENT_THEME" != "$ACTIVE_THEME" ]; then
    THEME_TO_ACTIVATE="$ACTIVE_THEME"
fi

# Calculate totals
TOTAL_ACTIONS=0
[ "$WP_ACTION" != "" ] && [ "$WP_ACTION" != "skip" ] && TOTAL_ACTIONS=$((TOTAL_ACTIONS + 1))
TOTAL_ACTIONS=$((TOTAL_ACTIONS + ${#PLUGINS_TO_INSTALL[@]} + ${#PLUGINS_TO_UPDATE[@]}))
TOTAL_ACTIONS=$((TOTAL_ACTIONS + ${#PLUGINS_TO_ACTIVATE[@]} + ${#PLUGINS_TO_DEACTIVATE[@]}))
TOTAL_ACTIONS=$((TOTAL_ACTIONS + ${#THEMES_TO_INSTALL[@]} + ${#THEMES_TO_UPDATE[@]}))
[ -n "$THEME_TO_ACTIVATE" ] && TOTAL_ACTIONS=$((TOTAL_ACTIONS + 1))

# Display comparison summary
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Comparison Summary                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Source:${NC} $SOURCE_ENV environment from manifest"
echo -e "${BLUE}Mode:${NC} $([ "$FORCE" = true ] && echo "Force reinstall" || echo "Smart sync (only changed items)")"
echo ""

# WordPress Core
echo -e "${YELLOW}WordPress Core:${NC}"
if [ "$WP_ACTION" = "install" ]; then
    echo -e "  ${CYAN}→${NC} Install WordPress $WP_VERSION"
elif [ "$WP_ACTION" = "update" ]; then
    echo -e "  ${CYAN}→${NC} Update WordPress $CURRENT_WP_VERSION → $WP_VERSION"
elif [ "$WP_ACTION" = "skip" ]; then
    echo -e "  ${GREEN}✓${NC} WordPress $WP_VERSION (up to date)"
fi
echo ""

# Plugins
echo -e "${YELLOW}Plugins:${NC}"
if [ ${#PLUGINS_TO_INSTALL[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Install (${#PLUGINS_TO_INSTALL[@]}):${NC}"
    for plugin in "${PLUGINS_TO_INSTALL[@]}"; do
        SLUG=$(echo "$plugin" | cut -d'|' -f1)
        VERSION=$(echo "$plugin" | cut -d'|' -f2)
        echo -e "    • $SLUG ($VERSION)"
    done
fi
if [ ${#PLUGINS_TO_UPDATE[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Update (${#PLUGINS_TO_UPDATE[@]}):${NC}"
    for plugin in "${PLUGINS_TO_UPDATE[@]}"; do
        SLUG=$(echo "$plugin" | cut -d'|' -f1)
        VERSION=$(echo "$plugin" | cut -d'|' -f2)
        CURRENT=$(wp plugin get "$SLUG" --field=version 2>/dev/null)
        echo -e "    • $SLUG ($CURRENT → $VERSION)"
    done
fi
if [ ${#PLUGINS_TO_ACTIVATE[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Activate (${#PLUGINS_TO_ACTIVATE[@]}):${NC} ${PLUGINS_TO_ACTIVATE[*]}"
fi
if [ ${#PLUGINS_TO_DEACTIVATE[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Deactivate (${#PLUGINS_TO_DEACTIVATE[@]}):${NC} ${PLUGINS_TO_DEACTIVATE[*]}"
fi
PLUGINS_UPTODATE=$((PLUGIN_COUNT - ${#PLUGINS_TO_INSTALL[@]} - ${#PLUGINS_TO_UPDATE[@]} - PLUGINS_SKIPPED))
if [ $PLUGINS_UPTODATE -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Up to date: $PLUGINS_UPTODATE plugins"
fi
if [ $PLUGINS_SKIPPED -gt 0 ]; then
    echo -e "  ${YELLOW}⊘${NC} Excluded: $PLUGINS_SKIPPED plugins"
fi
echo ""

# Themes
echo -e "${YELLOW}Themes:${NC}"
if [ ${#THEMES_TO_INSTALL[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Install (${#THEMES_TO_INSTALL[@]}):${NC}"
    for theme in "${THEMES_TO_INSTALL[@]}"; do
        SLUG=$(echo "$theme" | cut -d'|' -f1)
        VERSION=$(echo "$theme" | cut -d'|' -f2)
        echo -e "    • $SLUG ($VERSION)"
    done
fi
if [ ${#THEMES_TO_UPDATE[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Update (${#THEMES_TO_UPDATE[@]}):${NC}"
    for theme in "${THEMES_TO_UPDATE[@]}"; do
        SLUG=$(echo "$theme" | cut -d'|' -f1)
        VERSION=$(echo "$theme" | cut -d'|' -f2)
        CURRENT=$(wp theme get "$SLUG" --field=version 2>/dev/null)
        echo -e "    • $SLUG ($CURRENT → $VERSION)"
    done
fi
if [ -n "$THEME_TO_ACTIVATE" ]; then
    echo -e "  ${CYAN}→${NC} Activate: $THEME_TO_ACTIVATE (currently: $CURRENT_THEME)"
fi
THEMES_UPTODATE=$((THEME_COUNT - ${#THEMES_TO_INSTALL[@]} - ${#THEMES_TO_UPDATE[@]} - THEMES_SKIPPED))
if [ $THEMES_UPTODATE -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Up to date: $THEMES_UPTODATE themes"
fi
if [ $THEMES_SKIPPED -gt 0 ]; then
    echo -e "  ${YELLOW}⊘${NC} Excluded: $THEMES_SKIPPED themes"
fi
echo ""

# Summary
echo -e "${BLUE}Total actions needed:${NC} $TOTAL_ACTIONS"
echo ""

# Exit early if nothing to do
if [ $TOTAL_ACTIONS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ Everything is already up to date!       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Tip: Use --force to reinstall everything${NC}"
    exit 0
fi

# Confirmation prompt (unless --yes flag is used)
if [ "$AUTO_CONFIRM" = false ]; then
    read -p "$(echo -e ${YELLOW}Proceed with these changes? [y/N]:${NC} )" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

# Execute changes
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Executing Changes                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Install/Update WordPress Core
if [ "$WP_ACTION" = "install" ]; then
    echo -e "${BLUE}→ Installing WordPress ${WP_VERSION}...${NC}"
    wp core download --version="$WP_VERSION" --force
    echo -e "${GREEN}  ✓ WordPress installed${NC}"
elif [ "$WP_ACTION" = "update" ]; then
    echo -e "${BLUE}→ Updating WordPress to ${WP_VERSION}...${NC}"
    wp core update --version="$WP_VERSION" || wp core download --version="$WP_VERSION" --force
    echo -e "${GREEN}  ✓ WordPress updated${NC}"
fi

# Install plugins
if [ ${#PLUGINS_TO_INSTALL[@]} -gt 0 ]; then
    echo -e "${BLUE}→ Installing ${#PLUGINS_TO_INSTALL[@]} plugins...${NC}"
    for plugin in "${PLUGINS_TO_INSTALL[@]}"; do
        SLUG=$(echo "$plugin" | cut -d'|' -f1)
        VERSION=$(echo "$plugin" | cut -d'|' -f2)
        STATUS=$(echo "$plugin" | cut -d'|' -f3)
        echo -e "  • $SLUG ($VERSION)..."
        wp plugin install "$SLUG" --version="$VERSION" 2>/dev/null || echo -e "    ${YELLOW}⚠ Failed${NC}"
        [ "$STATUS" = "active" ] && wp plugin activate "$SLUG" 2>/dev/null || true
    done
    echo -e "${GREEN}  ✓ Plugins installed${NC}"
fi

# Update plugins
if [ ${#PLUGINS_TO_UPDATE[@]} -gt 0 ]; then
    echo -e "${BLUE}→ Updating ${#PLUGINS_TO_UPDATE[@]} plugins...${NC}"
    for plugin in "${PLUGINS_TO_UPDATE[@]}"; do
        SLUG=$(echo "$plugin" | cut -d'|' -f1)
        VERSION=$(echo "$plugin" | cut -d'|' -f2)
        STATUS=$(echo "$plugin" | cut -d'|' -f3)
        echo -e "  • $SLUG ($VERSION)..."
        wp plugin update "$SLUG" --version="$VERSION" 2>/dev/null || wp plugin install "$SLUG" --version="$VERSION" --force 2>/dev/null || echo -e "    ${YELLOW}⚠ Failed${NC}"
        [ "$STATUS" = "active" ] && wp plugin activate "$SLUG" 2>/dev/null || true
        [ "$STATUS" = "inactive" ] && wp plugin deactivate "$SLUG" 2>/dev/null || true
    done
    echo -e "${GREEN}  ✓ Plugins updated${NC}"
fi

# Activate plugins
if [ ${#PLUGINS_TO_ACTIVATE[@]} -gt 0 ]; then
    echo -e "${BLUE}→ Activating ${#PLUGINS_TO_ACTIVATE[@]} plugins...${NC}"
    for plugin in "${PLUGINS_TO_ACTIVATE[@]}"; do
        wp plugin activate "$plugin" 2>/dev/null || echo -e "  ${YELLOW}⚠ Could not activate $plugin${NC}"
    done
    echo -e "${GREEN}  ✓ Plugins activated${NC}"
fi

# Deactivate plugins
if [ ${#PLUGINS_TO_DEACTIVATE[@]} -gt 0 ]; then
    echo -e "${BLUE}→ Deactivating ${#PLUGINS_TO_DEACTIVATE[@]} plugins...${NC}"
    for plugin in "${PLUGINS_TO_DEACTIVATE[@]}"; do
        wp plugin deactivate "$plugin" 2>/dev/null || echo -e "  ${YELLOW}⚠ Could not deactivate $plugin${NC}"
    done
    echo -e "${GREEN}  ✓ Plugins deactivated${NC}"
fi

# Install themes
if [ ${#THEMES_TO_INSTALL[@]} -gt 0 ]; then
    echo -e "${BLUE}→ Installing ${#THEMES_TO_INSTALL[@]} themes...${NC}"
    for theme in "${THEMES_TO_INSTALL[@]}"; do
        SLUG=$(echo "$theme" | cut -d'|' -f1)
        VERSION=$(echo "$theme" | cut -d'|' -f2)
        echo -e "  • $SLUG ($VERSION)..."
        wp theme install "$SLUG" --version="$VERSION" 2>/dev/null || echo -e "    ${YELLOW}⚠ Failed${NC}"
    done
    echo -e "${GREEN}  ✓ Themes installed${NC}"
fi

# Update themes
if [ ${#THEMES_TO_UPDATE[@]} -gt 0 ]; then
    echo -e "${BLUE}→ Updating ${#THEMES_TO_UPDATE[@]} themes...${NC}"
    for theme in "${THEMES_TO_UPDATE[@]}"; do
        SLUG=$(echo "$theme" | cut -d'|' -f1)
        VERSION=$(echo "$theme" | cut -d'|' -f2)
        echo -e "  • $SLUG ($VERSION)..."
        wp theme update "$SLUG" --version="$VERSION" 2>/dev/null || wp theme install "$SLUG" --version="$VERSION" --force 2>/dev/null || echo -e "    ${YELLOW}⚠ Failed${NC}"
    done
    echo -e "${GREEN}  ✓ Themes updated${NC}"
fi

# Activate theme
if [ -n "$THEME_TO_ACTIVATE" ]; then
    echo -e "${BLUE}→ Activating theme: ${THEME_TO_ACTIVATE}${NC}"
    wp theme activate "$THEME_TO_ACTIVATE" 2>/dev/null || echo -e "${YELLOW}⚠ Could not activate theme${NC}"
    echo -e "${GREEN}  ✓ Theme activated${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Sync complete!                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  Source: ${SOURCE_ENV} environment"
echo -e "  WordPress: ${WP_VERSION}"
echo -e "  Active Theme: ${ACTIVE_THEME}"
echo -e "  Total actions executed: ${TOTAL_ACTIONS}"
echo ""
