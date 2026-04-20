#!/bin/bash
###############################################################################
# Setup - First-time setup for manifest-based deployment
# Usage: ./bin/setup.sh
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Pantheon Manifest Deployment Setup       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check dependencies
echo -e "${YELLOW}→ Checking dependencies...${NC}"

MISSING_DEPS=0

if ! command -v terminus &> /dev/null; then
    echo -e "  ✗ Terminus CLI not found"
    echo -e "    Install: https://pantheon.io/docs/terminus/install"
    MISSING_DEPS=1
else
    echo -e "  ✓ Terminus CLI installed"
fi

if ! command -v wp &> /dev/null; then
    echo -e "  ✗ WP-CLI not found"
    echo -e "    Install: brew install wp-cli"
    MISSING_DEPS=1
else
    echo -e "  ✓ WP-CLI installed"
fi

if ! command -v jq &> /dev/null; then
    echo -e "  ✗ jq not found"
    echo -e "    Install: brew install jq"
    MISSING_DEPS=1
else
    echo -e "  ✓ jq installed"
fi

if ! command -v git &> /dev/null; then
    echo -e "  ✗ Git not found"
    MISSING_DEPS=1
else
    echo -e "  ✓ Git installed"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Please install missing dependencies and run this script again${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}→ Configuring Pantheon...${NC}"

# Check if Terminus is authenticated
if ! terminus auth:whoami &> /dev/null; then
    echo -e "${YELLOW}  You need to authenticate with Terminus${NC}"
    echo ""
    echo -e "  Get a machine token from: ${BLUE}https://dashboard.pantheon.io/users/#account/tokens/${NC}"
    echo ""
    read -p "  Enter your Terminus machine token: " TERMINUS_TOKEN
    terminus auth:login --machine-token="$TERMINUS_TOKEN"
    echo ""
fi

TERMINUS_USER=$(terminus auth:whoami)
echo -e "  ✓ Authenticated as: $TERMINUS_USER"

# Get site name
echo ""
read -p "Enter your Pantheon site name: " SITE_NAME

# Verify site exists
if ! terminus site:info "$SITE_NAME" &> /dev/null; then
    echo -e "${RED}Error: Site '$SITE_NAME' not found or you don't have access${NC}"
    exit 1
fi

echo -e "  ✓ Site found: $SITE_NAME"

# Sync manifest
echo ""
echo -e "${YELLOW}→ Syncing environment manifest from Pantheon...${NC}"
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/sync-manifest.sh" "$SITE_NAME"

# Setup git remote
echo ""
echo -e "${YELLOW}→ Setting up Pantheon git remote...${NC}"

if git remote get-url pantheon &> /dev/null; then
    echo -e "  ℹ Pantheon remote already exists"
else
    PANTHEON_GIT_URL=$(terminus connection:info "$SITE_NAME.dev" --field=git_url)
    git remote add pantheon "$PANTHEON_GIT_URL"
    echo -e "  ✓ Added Pantheon remote"
fi

# Create .gitkeep files if they don't exist
if [ ! -f "$PROJECT_ROOT/wp-content/plugins/.gitkeep" ]; then
    touch "$PROJECT_ROOT/wp-content/plugins/.gitkeep"
    echo -e "  ✓ Created wp-content/plugins/.gitkeep"
fi

if [ ! -f "$PROJECT_ROOT/wp-content/themes/.gitkeep" ]; then
    touch "$PROJECT_ROOT/wp-content/themes/.gitkeep"
    echo -e "  ✓ Created wp-content/themes/.gitkeep"
fi

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Setup complete!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo -e "1. Review bin/manifest.json to see your environment state"
echo -e "2. Commit the manifest to git:"
echo -e "   ${YELLOW}git add bin/ .gitignore${NC}"
echo -e "   ${YELLOW}git commit -m 'Setup manifest-based deployment'${NC}"
echo -e "   ${YELLOW}git push${NC}"
echo ""
echo -e "3. Setup GitHub Actions secrets:"
echo -e "   - Go to: https://github.com/YOUR_REPO/settings/secrets/actions"
echo -e "   - Add secret: ${YELLOW}PANTHEON_MACHINE_TOKEN${NC} = (your terminus token)"
echo -e "   - Add secret: ${YELLOW}PANTHEON_SITE_NAME${NC} = ${YELLOW}$SITE_NAME${NC}"
echo ""
echo -e "4. Bootstrap your local environment:"
echo -e "   ${YELLOW}./bin/bootstrap-env.sh dev${NC}"
echo ""
echo -e "${BLUE}📚 Read DEPLOYMENT.md for full documentation${NC}"
