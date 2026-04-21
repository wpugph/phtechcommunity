#!/usr/bin/env bash
#
# Sync Pantheon environment from a manifest file
# Usage: sync-pantheon-from-manifest.sh [OPTIONS]
#
# Environment variables required:
#   TERMINUS_TOKEN        Pantheon machine token
#   PANTHEON_SITE_NAME    Pantheon site name
#
# Environment variables optional:
#   PANTHEON_SSH_KEY      SSH private key (if not already configured)
#
# Options:
#   --source-env ENV      Source environment in manifest (dev, test, live, local) [default: dev]
#   --force               Force full reinstall (slow, reinstalls everything)
#   --commit              Commit changes to Pantheon dev
#   --deploy-test         Deploy to test environment after dev
#   --deploy-live         Deploy to live environment after test
#   --debug               Enable verbose debug output
#   --skip-ssh-setup      Skip SSH setup (use if already configured)
#   --skip-auth           Skip Terminus authentication (use if already authenticated)
#   --help                Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
SOURCE_ENV="dev"
FORCE_REINSTALL=false
COMMIT_CHANGES=false
DEPLOY_TO_TEST=false
DEPLOY_TO_LIVE=false
DEBUG_MODE=false
SKIP_SSH_SETUP=false
SKIP_AUTH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --source-env)
      SOURCE_ENV="$2"
      shift 2
      ;;
    --force)
      FORCE_REINSTALL=true
      shift
      ;;
    --commit)
      COMMIT_CHANGES=true
      shift
      ;;
    --deploy-test)
      DEPLOY_TO_TEST=true
      shift
      ;;
    --deploy-live)
      DEPLOY_TO_LIVE=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --skip-ssh-setup)
      SKIP_SSH_SETUP=true
      shift
      ;;
    --skip-auth)
      SKIP_AUTH=true
      shift
      ;;
    --help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Validate required environment variables
if [ -z "${TERMINUS_TOKEN:-}" ]; then
  echo "❌ ERROR: TERMINUS_TOKEN environment variable is required" >&2
  exit 1
fi

if [ -z "${PANTHEON_SITE_NAME:-}" ]; then
  echo "❌ ERROR: PANTHEON_SITE_NAME environment variable is required" >&2
  exit 1
fi

SITE_NAME="$PANTHEON_SITE_NAME"
MANIFEST_FILE="$SCRIPT_DIR/manifest.${SOURCE_ENV}.json"

echo "╔═══════════════════════════════════════════╗"
echo "║  Sync Pantheon from Manifest              ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Site:         $SITE_NAME"
echo "Source:       $SOURCE_ENV (manifest)"
echo "Force:        $FORCE_REINSTALL"
echo "Commit:       $COMMIT_CHANGES"
echo "Deploy Test:  $DEPLOY_TO_TEST"
echo "Deploy Live:  $DEPLOY_TO_LIVE"
echo "Debug:        $DEBUG_MODE"
echo ""

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
  echo "❌ ERROR: Manifest file not found: $MANIFEST_FILE" >&2
  echo "" >&2
  echo "Available manifest files:" >&2
  ls -1 "$SCRIPT_DIR"/manifest.*.json 2>/dev/null || echo "  (none found)" >&2
  echo "" >&2
  exit 1
fi

# Authenticate with Pantheon (unless skipped)
if [ "$SKIP_AUTH" = false ]; then
  echo "→ Authenticating with Pantheon..."
  if ! terminus auth:login --machine-token="$TERMINUS_TOKEN" 2>&1 | head -1; then
    echo "❌ ERROR: Failed to authenticate with Pantheon" >&2
    exit 1
  fi
fi

# Setup SSH for Pantheon (unless skipped)
if [ "$SKIP_SSH_SETUP" = false ] && [ -n "${PANTHEON_SSH_KEY:-}" ]; then
  echo "→ Setting up SSH for Pantheon..."

  # Setup SSH directory
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  # Add SSH private key from environment variable
  echo "$PANTHEON_SSH_KEY" > ~/.ssh/id_rsa_pantheon
  chmod 600 ~/.ssh/id_rsa_pantheon

  # Update SSH config
  if ! grep -q "Host \*.drush.in" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config <<EOF

Host *.drush.in
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    IdentityFile ~/.ssh/id_rsa_pantheon
EOF
    chmod 600 ~/.ssh/config
  fi
fi

# Switch dev to SFTP mode
echo "→ Switching dev environment to SFTP mode..."
terminus connection:set "$SITE_NAME.dev" sftp 2>&1 | head -1 || echo "  (already in SFTP mode or switch failed)"

# Load exclusions
if [ -f "$SCRIPT_DIR/manifest-exclude.txt" ]; then
  EXCLUDED=$(grep -v '^#' "$SCRIPT_DIR/manifest-exclude.txt" | grep -v '^[[:space:]]*$' | tr '\n' '|' | sed 's/|$//')
else
  EXCLUDED=""
fi

# Initialize tracking files
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

touch "$TMP_DIR/changes_made.txt"
touch "$TMP_DIR/plugins_installed.txt"
touch "$TMP_DIR/plugins_updated.txt"
touch "$TMP_DIR/plugins_activated.txt"
touch "$TMP_DIR/plugins_deactivated.txt"
touch "$TMP_DIR/plugins_uninstalled.txt"
touch "$TMP_DIR/themes_installed.txt"
touch "$TMP_DIR/themes_updated.txt"

echo ""
echo "═══════════════════════════════════════════"
echo "  Phase 1: Compare with Manifest"
echo "═══════════════════════════════════════════"
echo ""

# Wake dev environment
echo "→ Waking dev environment..."
terminus env:wake "$SITE_NAME.dev" 2>&1 | head -1 || true
sleep 2

# Test WP-CLI connectivity
echo "→ Testing WP-CLI connection..."
if ! terminus wp "$SITE_NAME.dev" -- core version --quiet 2>/dev/null; then
  echo "❌ ERROR: Cannot connect to WordPress via WP-CLI" >&2
  echo "This usually means:" >&2
  echo "  - Environment is not in SFTP mode" >&2
  echo "  - SSH keys are not configured" >&2
  echo "  - WordPress is not installed" >&2
  exit 1
fi
echo "  ✓ WP-CLI connection successful"

# Get target versions from manifest
WP_TARGET=$(jq -r ".wordpress.version // \"unknown\"" "$MANIFEST_FILE")
THEME_TARGET=$(jq -r ".active_theme // \"unknown\"" "$MANIFEST_FILE")

# Get current WordPress version and active theme
WP_CURRENT=$(terminus wp "$SITE_NAME.dev" -- core version 2>/dev/null | grep -oE "^[0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 || echo "unknown")
THEME_CURRENT=$(terminus wp "$SITE_NAME.dev" -- theme list --status=active --field=name 2>/dev/null | grep -v "^\[" | grep -v "^Command:" | head -1 || echo "unknown")

if [ "$DEBUG_MODE" = true ]; then
  echo "DEBUG: WordPress - Target: $WP_TARGET, Current: $WP_CURRENT" >&2
  echo "DEBUG: Theme - Target: $THEME_TARGET, Current: $THEME_CURRENT" >&2
fi

# Determine if WP core needs update
if [ "$FORCE_REINSTALL" = true ] || [ "$WP_CURRENT" != "$WP_TARGET" ]; then
  WP_ACTION="update"
else
  WP_ACTION="skip"
fi

# Get plugins from manifest and current state
jq -r ".plugins | to_entries[] | \"\(.key)|\(.value.version)|\(.value.status)\"" "$MANIFEST_FILE" > "$TMP_DIR/manifest_plugins.txt"

# Get current plugins from Pantheon dev
echo "→ Fetching current plugin list from Pantheon dev..."
terminus wp "$SITE_NAME.dev" -- plugin list --format=json > "$TMP_DIR/plugin_raw.txt" 2>&1

# Extract and parse JSON
if cat "$TMP_DIR/plugin_raw.txt" | jq -e '. | type' >/dev/null 2>&1; then
  cat "$TMP_DIR/plugin_raw.txt" | jq -r 'if type == "array" then .[] else . end | "\(.name)|\(.version)|\(.status)"' > "$TMP_DIR/current_plugins.txt" 2>/dev/null || echo "" > "$TMP_DIR/current_plugins.txt"
else
  echo "" > "$TMP_DIR/current_plugins.txt"
fi

if [ "$DEBUG_MODE" = true ]; then
  echo ""
  echo "=== DEBUG: Plugin Comparison ==="
  echo "Plugins in manifest ($SOURCE_ENV): $(wc -l < "$TMP_DIR/manifest_plugins.txt" | xargs)"
  echo "Plugins currently in dev: $(wc -l < "$TMP_DIR/current_plugins.txt" | xargs)"
  echo ""
fi

# Fallback to CSV if JSON failed
if [ ! -s "$TMP_DIR/current_plugins.txt" ]; then
  echo "  ⚠️  No plugins found in dev via JSON format, trying CSV fallback..."
  terminus wp "$SITE_NAME.dev" -- plugin list --format=csv 2>&1 | tail -n +2 | awk -F',' '{print $1"|"$4"|"$2}' > "$TMP_DIR/current_plugins.txt" || echo "" > "$TMP_DIR/current_plugins.txt"
  if [ ! -s "$TMP_DIR/current_plugins.txt" ]; then
    echo "❌ ERROR: No plugins found in dev!" >&2
    if [ "$DEBUG_MODE" = true ]; then
      echo "Raw terminus output:" >&2
      cat "$TMP_DIR/plugin_raw.txt" >&2
    fi
    exit 1
  fi
fi

if [ "$DEBUG_MODE" = true ]; then
  echo "First 5 manifest plugins:"
  head -5 "$TMP_DIR/manifest_plugins.txt" || echo "  (none)"
  echo ""
  echo "First 5 current plugins:"
  head -5 "$TMP_DIR/current_plugins.txt" || echo "  (none)"
  echo "================================"
  echo ""
fi

# Sanity check
if [ ! -f "$TMP_DIR/manifest_plugins.txt" ] || [ ! -s "$TMP_DIR/manifest_plugins.txt" ]; then
  echo "❌ ERROR: Manifest plugins list is empty for environment '$SOURCE_ENV'!" >&2
  echo "" >&2
  echo "Manifest file: $MANIFEST_FILE" >&2
  count=$(jq -r ".plugins | length" "$MANIFEST_FILE" 2>/dev/null || echo "0")
  echo "Plugins in manifest: $count" >&2
  echo "" >&2
  exit 1
fi

if [ ! -f "$TMP_DIR/current_plugins.txt" ] || [ ! -s "$TMP_DIR/current_plugins.txt" ]; then
  echo "⚠️  WARNING: Current plugins list is empty - will treat all as new installs"
fi

# Initialize comparison result files
> "$TMP_DIR/plugins_to_install.txt"
> "$TMP_DIR/plugins_to_update.txt"
> "$TMP_DIR/plugins_to_activate.txt"
> "$TMP_DIR/plugins_to_deactivate.txt"
> "$TMP_DIR/plugins_to_uninstall.txt"
> "$TMP_DIR/plugins_unchanged.txt"

echo "→ Comparing plugins between manifest and dev..."

# Compare manifest plugins with current state
while IFS='|' read -r slug version status; do
  # Skip excluded plugins
  if [ -n "$EXCLUDED" ] && echo "$EXCLUDED" | grep -qE "(^|\\|)${slug}(\\||$)"; then
    continue
  fi

  current_line=$(grep "^${slug}|" "$TMP_DIR/current_plugins.txt" 2>/dev/null || echo "")

  if [ -z "$current_line" ]; then
    # Plugin not installed
    echo "${slug}|${version}|${status}" >> "$TMP_DIR/plugins_to_install.txt"
  else
    current_version=$(echo "$current_line" | cut -d'|' -f2)
    current_status=$(echo "$current_line" | cut -d'|' -f3)

    # Check if version AND status match
    if [ "$current_version" = "$version" ] && [ "$current_status" = "$status" ] && [ "$FORCE_REINSTALL" != true ]; then
      # Perfect match - no action needed
      echo "${slug}|${version}|${status}" >> "$TMP_DIR/plugins_unchanged.txt"
    elif [ "$FORCE_REINSTALL" = true ] || [ "$current_version" != "$version" ]; then
      # Version mismatch - needs update/downgrade
      echo "${slug}|${version}|${current_version}|${status}" >> "$TMP_DIR/plugins_to_update.txt"
    elif [ "$status" = "active" ] && [ "$current_status" != "active" ]; then
      # Only activation status differs
      echo "$slug" >> "$TMP_DIR/plugins_to_activate.txt"
    elif [ "$status" = "inactive" ] && [ "$current_status" = "active" ]; then
      # Only activation status differs
      echo "$slug" >> "$TMP_DIR/plugins_to_deactivate.txt"
    fi
  fi
done < "$TMP_DIR/manifest_plugins.txt"

# Check for plugins in dev that are NOT in manifest (need to uninstall)
while IFS='|' read -r slug version status; do
  # Skip excluded plugins
  if [ -n "$EXCLUDED" ] && echo "$EXCLUDED" | grep -qE "(^|\\|)${slug}(\\||$)"; then
    continue
  fi

  # Check if plugin exists in manifest
  if ! grep -q "^${slug}|" "$TMP_DIR/manifest_plugins.txt"; then
    echo "${slug}|${version}" >> "$TMP_DIR/plugins_to_uninstall.txt"
  fi
done < "$TMP_DIR/current_plugins.txt"

# Get themes from manifest and current state
jq -r ".themes | to_entries[] | \"\(.key)|\(.value.version)\"" "$MANIFEST_FILE" > "$TMP_DIR/manifest_themes.txt" || echo "" > "$TMP_DIR/manifest_themes.txt"

# Get current themes from Pantheon dev
terminus wp "$SITE_NAME.dev" -- theme list --format=json > "$TMP_DIR/theme_raw.txt" 2>&1
cat "$TMP_DIR/theme_raw.txt" | jq -r '.[]? | "\(.name)|\(.version)"' > "$TMP_DIR/current_themes.txt" 2>/dev/null || echo "" > "$TMP_DIR/current_themes.txt"

echo "  Themes in manifest: $(wc -l < "$TMP_DIR/manifest_themes.txt" | xargs)"
echo "  Themes in dev: $(wc -l < "$TMP_DIR/current_themes.txt" | xargs)"

# Compare themes
> "$TMP_DIR/themes_to_install.txt"
> "$TMP_DIR/themes_to_update.txt"

while IFS='|' read -r slug version; do
  # Skip excluded themes
  if [ -n "$EXCLUDED" ] && echo "$EXCLUDED" | grep -qE "(^|\\|)${slug}(\\||$)"; then
    continue
  fi

  current_line=$(grep "^${slug}|" "$TMP_DIR/current_themes.txt" || echo "")

  if [ -z "$current_line" ]; then
    # Theme not installed
    echo "${slug}|${version}" >> "$TMP_DIR/themes_to_install.txt"
  else
    current_version=$(echo "$current_line" | cut -d'|' -f2)

    if [ "$FORCE_REINSTALL" = true ] || [ "$current_version" != "$version" ]; then
      echo "${slug}|${version}|${current_version}" >> "$TMP_DIR/themes_to_update.txt"
    fi
  fi
done < "$TMP_DIR/manifest_themes.txt"

# Count all actions
INSTALL_COUNT=$(wc -l < "$TMP_DIR/plugins_to_install.txt" | xargs)
UPDATE_COUNT=$(wc -l < "$TMP_DIR/plugins_to_update.txt" | xargs)
ACTIVATE_COUNT=$(wc -l < "$TMP_DIR/plugins_to_activate.txt" | xargs)
DEACTIVATE_COUNT=$(wc -l < "$TMP_DIR/plugins_to_deactivate.txt" | xargs)
UNINSTALL_COUNT=$(wc -l < "$TMP_DIR/plugins_to_uninstall.txt" | xargs)
UNCHANGED_COUNT=$(wc -l < "$TMP_DIR/plugins_unchanged.txt" | xargs)
THEME_INSTALL_COUNT=$(wc -l < "$TMP_DIR/themes_to_install.txt" | xargs)
THEME_UPDATE_COUNT=$(wc -l < "$TMP_DIR/themes_to_update.txt" | xargs)

# Calculate total actions
TOTAL_ACTIONS=0
[ "$WP_CURRENT" != "$WP_TARGET" ] && TOTAL_ACTIONS=$((TOTAL_ACTIONS + 1))
TOTAL_ACTIONS=$((TOTAL_ACTIONS + INSTALL_COUNT + UPDATE_COUNT + ACTIVATE_COUNT + DEACTIVATE_COUNT + UNINSTALL_COUNT + THEME_INSTALL_COUNT + THEME_UPDATE_COUNT))

# Summary of comparison
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║  Plugin Comparison Summary                ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "✓ Unchanged (already match):     $UNCHANGED_COUNT"
echo "↓ Install (not present):         $INSTALL_COUNT"
echo "↑ Update/Downgrade (version):    $UPDATE_COUNT"
echo "⚡ Activate (inactive):           $ACTIVATE_COUNT"
echo "⚠ Deactivate (active):           $DEACTIVATE_COUNT"
echo "✗ Uninstall (not in manifest):   $UNINSTALL_COUNT"
echo ""

# Show details if there are changes
if [ "$UNINSTALL_COUNT" -gt 0 ]; then
  echo "⚠️  Plugins to be REMOVED:"
  cat "$TMP_DIR/plugins_to_uninstall.txt"
  echo ""
fi

# Check if anything needs to be done
if [ "$TOTAL_ACTIONS" -eq 0 ]; then
  echo ""
  echo "╔═══════════════════════════════════════════╗"
  echo "║  ✅ Everything is already in sync!        ║"
  echo "╚═══════════════════════════════════════════╝"
  echo ""
  echo "No changes needed. Dev environment matches the manifest perfectly."
  echo ""
  echo "📊 Summary:"
  echo "  - Plugins in sync: $UNCHANGED_COUNT"
  echo "  - WordPress: $WP_CURRENT ✓"
  echo "  - Active theme: $THEME_CURRENT ✓"
  echo ""
  exit 0
else
  echo "📋 Proceeding with $TOTAL_ACTIONS actions..."
  echo ""
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  Phase 2: Apply Changes"
echo "═══════════════════════════════════════════"
echo ""

# Update WordPress Core
if [ "$WP_ACTION" = "update" ]; then
  echo "→ Updating WordPress from $WP_CURRENT to $WP_TARGET..."

  if terminus wp "$SITE_NAME.dev" -- core update --version="$WP_TARGET" || \
     terminus wp "$SITE_NAME.dev" -- core download --version="$WP_TARGET" --force; then
    echo "  ✅ WordPress updated: $WP_CURRENT → $WP_TARGET"
    echo "WordPress: $WP_CURRENT → $WP_TARGET" > "$TMP_DIR/changes_made.txt"
  else
    echo "  ❌ WordPress update failed"
    touch "$TMP_DIR/changes_made.txt"
  fi
  echo ""
fi

# Install new plugins
if [ "$INSTALL_COUNT" -gt 0 ]; then
  echo "→ Installing $INSTALL_COUNT plugins..."
  > "$TMP_DIR/plugins_installed.txt"
  COUNTER=0
  while IFS='|' read -r slug version status; do
    [ -z "$slug" ] && continue
    COUNTER=$((COUNTER + 1))
    echo "  [$COUNTER/$INSTALL_COUNT] Installing $slug $version..."

    if terminus wp "$SITE_NAME.dev" -- plugin install "$slug" --version="$version" --force </dev/null 2>/dev/null; then
      echo "$slug $version" >> "$TMP_DIR/plugins_installed.txt"
      [ "$status" = "active" ] && terminus wp "$SITE_NAME.dev" -- plugin activate "$slug" </dev/null 2>/dev/null || true
      echo "    ✅ Success"
    else
      echo "    ❌ Failed"
    fi
  done < "$TMP_DIR/plugins_to_install.txt"
  echo ""
  echo "  Total: $(wc -l < "$TMP_DIR/plugins_installed.txt" | xargs)/$INSTALL_COUNT installed successfully"
  echo ""
fi

# Update existing plugins
if [ "$UPDATE_COUNT" -gt 0 ]; then
  echo "→ Updating/downgrading $UPDATE_COUNT plugins..."

  > "$TMP_DIR/plugins_updated.txt"
  COUNTER=0
  while IFS='|' read -r slug version current_version status; do
    [ -z "$slug" ] && continue

    COUNTER=$((COUNTER + 1))
    echo "  [$COUNTER/$UPDATE_COUNT] $slug: $current_version → $version"

    if terminus wp "$SITE_NAME.dev" -- plugin install "$slug" --version="$version" --force </dev/null 2>/dev/null; then
      echo "$slug: $current_version → $version" >> "$TMP_DIR/plugins_updated.txt"
      # Apply activation status from manifest
      if [ "$status" = "active" ]; then
        terminus wp "$SITE_NAME.dev" -- plugin activate "$slug" </dev/null 2>/dev/null || true
      elif [ "$status" = "inactive" ]; then
        terminus wp "$SITE_NAME.dev" -- plugin deactivate "$slug" </dev/null 2>/dev/null || true
      fi
      echo "    ✅ Success"
    else
      echo "    ❌ Failed"
    fi
  done < "$TMP_DIR/plugins_to_update.txt"

  echo ""
  echo "  Total: $COUNTER processed, $(wc -l < "$TMP_DIR/plugins_updated.txt" | xargs) succeeded"
  echo ""
fi

# Activate plugins
if [ "$ACTIVATE_COUNT" -gt 0 ]; then
  echo "→ Activating $ACTIVATE_COUNT plugins..."

  > "$TMP_DIR/plugins_activated.txt"
  COUNTER=0
  while read -r slug; do
    [ -z "$slug" ] && continue
    COUNTER=$((COUNTER + 1))
    echo "  [$COUNTER/$ACTIVATE_COUNT] Activating $slug..."
    if terminus wp "$SITE_NAME.dev" -- plugin activate "$slug" </dev/null 2>/dev/null; then
      echo "$slug" >> "$TMP_DIR/plugins_activated.txt"
      echo "    ✅ Success"
    else
      echo "    ❌ Failed"
    fi
  done < "$TMP_DIR/plugins_to_activate.txt"
  echo ""
  echo "  Total: $(wc -l < "$TMP_DIR/plugins_activated.txt" | xargs)/$ACTIVATE_COUNT activated"
  echo ""
fi

# Deactivate plugins
if [ "$DEACTIVATE_COUNT" -gt 0 ]; then
  echo "→ Deactivating $DEACTIVATE_COUNT plugins..."

  > "$TMP_DIR/plugins_deactivated.txt"
  COUNTER=0
  while read -r slug; do
    [ -z "$slug" ] && continue
    COUNTER=$((COUNTER + 1))
    echo "  [$COUNTER/$DEACTIVATE_COUNT] Deactivating $slug..."
    if terminus wp "$SITE_NAME.dev" -- plugin deactivate "$slug" </dev/null 2>/dev/null; then
      echo "$slug" >> "$TMP_DIR/plugins_deactivated.txt"
      echo "    ✅ Success"
    else
      echo "    ❌ Failed"
    fi
  done < "$TMP_DIR/plugins_to_deactivate.txt"
  echo ""
  echo "  Total: $(wc -l < "$TMP_DIR/plugins_deactivated.txt" | xargs)/$DEACTIVATE_COUNT deactivated"
  echo ""
fi

# Uninstall plugins not in manifest
if [ "$UNINSTALL_COUNT" -gt 0 ]; then
  echo "→ Uninstalling $UNINSTALL_COUNT plugins not in manifest..."

  > "$TMP_DIR/plugins_uninstalled.txt"
  COUNTER=0
  while IFS='|' read -r slug version; do
    [ -z "$slug" ] && continue
    COUNTER=$((COUNTER + 1))
    echo "  [$COUNTER/$UNINSTALL_COUNT] Uninstalling $slug $version..."
    # Deactivate first if active, then uninstall
    terminus wp "$SITE_NAME.dev" -- plugin deactivate "$slug" </dev/null 2>/dev/null || true
    if terminus wp "$SITE_NAME.dev" -- plugin uninstall "$slug" --deactivate </dev/null 2>/dev/null; then
      echo "$slug $version" >> "$TMP_DIR/plugins_uninstalled.txt"
      echo "    ✅ Success"
    else
      echo "    ❌ Failed"
    fi
  done < "$TMP_DIR/plugins_to_uninstall.txt"
  echo ""
  echo "  Total: $(wc -l < "$TMP_DIR/plugins_uninstalled.txt" | xargs)/$UNINSTALL_COUNT uninstalled"
  echo ""
fi

# Install new themes
if [ "$THEME_INSTALL_COUNT" -gt 0 ]; then
  echo "→ Installing $THEME_INSTALL_COUNT themes..."
  > "$TMP_DIR/themes_installed.txt"
  while IFS='|' read -r slug version; do
    [ -z "$slug" ] && continue
    echo "  Installing ${slug} ${version}..."
    if terminus wp "$SITE_NAME.dev" -- theme install "$slug" --version="$version" </dev/null; then
      echo "$slug $version" >> "$TMP_DIR/themes_installed.txt"
      echo "    ✅ Installed: $slug $version"
    else
      echo "    ❌ Failed to install $slug"
    fi
  done < "$TMP_DIR/themes_to_install.txt"
  echo "  Total installed: $(wc -l < "$TMP_DIR/themes_installed.txt" | xargs)"
  echo ""
fi

# Update existing themes
if [ "$THEME_UPDATE_COUNT" -gt 0 ]; then
  echo "→ Updating $THEME_UPDATE_COUNT themes..."
  > "$TMP_DIR/themes_updated.txt"
  while IFS='|' read -r slug version current_version; do
    [ -z "$slug" ] && continue
    echo "  Updating ${slug}: ${current_version} → ${version}..."
    if terminus wp "$SITE_NAME.dev" -- theme update "$slug" --version="$version" </dev/null || \
       terminus wp "$SITE_NAME.dev" -- theme install "$slug" --version="$version" --force </dev/null; then
      echo "$slug: $current_version → $version" >> "$TMP_DIR/themes_updated.txt"
      echo "    ✅ Updated: $slug $current_version → $version"
    else
      echo "    ❌ Failed to update $slug"
    fi
  done < "$TMP_DIR/themes_to_update.txt"
  echo "  Total updated: $(wc -l < "$TMP_DIR/themes_updated.txt" | xargs)"
  echo ""
fi

# Activate theme
if [ "$THEME_CURRENT" != "$THEME_TARGET" ]; then
  echo "→ Activating theme: $THEME_TARGET"
  terminus wp "$SITE_NAME.dev" -- theme activate "$THEME_TARGET" </dev/null || echo "  ⚠️ Could not activate theme"
  echo ""
fi

# Commit changes to Pantheon dev
if [ "$COMMIT_CHANGES" = true ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  Phase 3: Commit Changes"
  echo "═══════════════════════════════════════════"
  echo ""

  echo "→ Building commit message with changes..."

  # Build detailed commit message
  cat > "$TMP_DIR/commit_message.txt" <<EOF
Sync from manifest ($SOURCE_ENV) via automated script

EOF

  # Add WordPress core changes
  if [ -f "$TMP_DIR/changes_made.txt" ] && [ -s "$TMP_DIR/changes_made.txt" ]; then
    cat "$TMP_DIR/changes_made.txt" >> "$TMP_DIR/commit_message.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add plugin installations
  if [ -f "$TMP_DIR/plugins_installed.txt" ] && [ -s "$TMP_DIR/plugins_installed.txt" ]; then
    echo "Plugins installed:" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/plugins_installed.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add plugin updates
  if [ -f "$TMP_DIR/plugins_updated.txt" ] && [ -s "$TMP_DIR/plugins_updated.txt" ]; then
    echo "Plugins updated:" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/plugins_updated.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add theme installations
  if [ -f "$TMP_DIR/themes_installed.txt" ] && [ -s "$TMP_DIR/themes_installed.txt" ]; then
    echo "Themes installed:" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/themes_installed.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add theme updates
  if [ -f "$TMP_DIR/themes_updated.txt" ] && [ -s "$TMP_DIR/themes_updated.txt" ]; then
    echo "Themes updated:" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/themes_updated.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add plugin activations
  if [ -f "$TMP_DIR/plugins_activated.txt" ] && [ -s "$TMP_DIR/plugins_activated.txt" ]; then
    echo "Plugins activated:" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/plugins_activated.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add plugin deactivations
  if [ -f "$TMP_DIR/plugins_deactivated.txt" ] && [ -s "$TMP_DIR/plugins_deactivated.txt" ]; then
    echo "Plugins deactivated:" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/plugins_deactivated.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Add plugin uninstalls
  if [ -f "$TMP_DIR/plugins_uninstalled.txt" ] && [ -s "$TMP_DIR/plugins_uninstalled.txt" ]; then
    echo "Plugins uninstalled (not in manifest):" >> "$TMP_DIR/commit_message.txt"
    while read line; do
      echo "  - $line" >> "$TMP_DIR/commit_message.txt"
    done < "$TMP_DIR/plugins_uninstalled.txt"
    echo "" >> "$TMP_DIR/commit_message.txt"
  fi

  # Show commit message
  echo "Commit message:"
  cat "$TMP_DIR/commit_message.txt"
  echo ""

  # Commit with detailed message
  terminus env:commit "$SITE_NAME.dev" --message="$(cat "$TMP_DIR/commit_message.txt")" || echo "  ⚠️ No changes to commit or commit failed"
fi

# Switch dev back to Git mode
echo "→ Switching dev environment back to Git mode..."
terminus connection:set "$SITE_NAME.dev" git 2>&1 | head -1 || echo "  ⚠️ Could not switch to Git mode"

# Clear cache
echo "→ Clearing cache on dev..."
terminus env:clear-cache "$SITE_NAME.dev" 2>&1 | head -1

# Deploy to test
if [ "$DEPLOY_TO_TEST" = true ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  Phase 4: Deploy to Test"
  echo "═══════════════════════════════════════════"
  echo ""

  echo "→ Deploying to test environment..."
  terminus env:deploy "$SITE_NAME.test" --sync-content --note="Deployed from manifest sync" || echo "  ⚠️ Deploy to test failed"
  terminus env:clear-cache "$SITE_NAME.test" 2>&1 | head -1
fi

# Deploy to live
if [ "$DEPLOY_TO_LIVE" = true ] && [ "$DEPLOY_TO_TEST" = true ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  Phase 5: Deploy to Live"
  echo "═══════════════════════════════════════════"
  echo ""

  echo "→ Deploying to live environment..."
  terminus env:deploy "$SITE_NAME.live" --note="Deployed from manifest sync" || echo "  ⚠️ Deploy to live failed"
  terminus env:clear-cache "$SITE_NAME.live" 2>&1 | head -1
fi

# Final summary
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║  ✅ Sync Complete                         ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Count successful changes
WP_CHANGED=0
PLUGINS_INSTALLED=0
PLUGINS_UPDATED=0
PLUGINS_ACTIVATED=0
PLUGINS_DEACTIVATED=0
PLUGINS_UNINSTALLED=0
THEMES_INSTALLED=0
THEMES_UPDATED=0

[ -f "$TMP_DIR/changes_made.txt" ] && [ -s "$TMP_DIR/changes_made.txt" ] && WP_CHANGED=1
[ -f "$TMP_DIR/plugins_installed.txt" ] && PLUGINS_INSTALLED=$(wc -l < "$TMP_DIR/plugins_installed.txt" | xargs)
[ -f "$TMP_DIR/plugins_updated.txt" ] && PLUGINS_UPDATED=$(wc -l < "$TMP_DIR/plugins_updated.txt" | xargs)
[ -f "$TMP_DIR/plugins_activated.txt" ] && PLUGINS_ACTIVATED=$(wc -l < "$TMP_DIR/plugins_activated.txt" | xargs)
[ -f "$TMP_DIR/plugins_deactivated.txt" ] && PLUGINS_DEACTIVATED=$(wc -l < "$TMP_DIR/plugins_deactivated.txt" | xargs)
[ -f "$TMP_DIR/plugins_uninstalled.txt" ] && PLUGINS_UNINSTALLED=$(wc -l < "$TMP_DIR/plugins_uninstalled.txt" | xargs)
[ -f "$TMP_DIR/themes_installed.txt" ] && THEMES_INSTALLED=$(wc -l < "$TMP_DIR/themes_installed.txt" | xargs)
[ -f "$TMP_DIR/themes_updated.txt" ] && THEMES_UPDATED=$(wc -l < "$TMP_DIR/themes_updated.txt" | xargs)

TOTAL_CHANGES=$((WP_CHANGED + PLUGINS_INSTALLED + PLUGINS_UPDATED + PLUGINS_ACTIVATED + PLUGINS_DEACTIVATED + PLUGINS_UNINSTALLED + THEMES_INSTALLED + THEMES_UPDATED))

echo "Actions planned:   $TOTAL_ACTIONS"
echo "Changes applied:   $TOTAL_CHANGES"
echo ""

if [ "$TOTAL_CHANGES" -gt 0 ]; then
  echo "🔄 Changes Applied:"
  echo ""

  # WordPress Core
  if [ -f "$TMP_DIR/changes_made.txt" ] && [ -s "$TMP_DIR/changes_made.txt" ]; then
    echo "WordPress Core:"
    cat "$TMP_DIR/changes_made.txt" | sed 's/^/  ✅ /'
    echo ""
  fi

  # Plugins installed
  if [ "$PLUGINS_INSTALLED" -gt 0 ]; then
    echo "Plugins Installed ($PLUGINS_INSTALLED):"
    while read line; do
      echo "  ✅ $line"
    done < "$TMP_DIR/plugins_installed.txt"
    echo ""
  fi

  # Plugins updated
  if [ "$PLUGINS_UPDATED" -gt 0 ]; then
    echo "Plugins Updated ($PLUGINS_UPDATED):"
    while read line; do
      echo "  ✅ $line"
    done < "$TMP_DIR/plugins_updated.txt"
    echo ""
  fi

  # Themes installed
  if [ "$THEMES_INSTALLED" -gt 0 ]; then
    echo "Themes Installed ($THEMES_INSTALLED):"
    while read line; do
      echo "  ✅ $line"
    done < "$TMP_DIR/themes_installed.txt"
    echo ""
  fi

  # Themes updated
  if [ "$THEMES_UPDATED" -gt 0 ]; then
    echo "Themes Updated ($THEMES_UPDATED):"
    while read line; do
      echo "  ✅ $line"
    done < "$TMP_DIR/themes_updated.txt"
    echo ""
  fi

  # Plugins activated
  if [ "$PLUGINS_ACTIVATED" -gt 0 ]; then
    echo "Plugins Activated ($PLUGINS_ACTIVATED):"
    while read line; do
      echo "  ✅ $line"
    done < "$TMP_DIR/plugins_activated.txt"
    echo ""
  fi

  # Plugins deactivated
  if [ "$PLUGINS_DEACTIVATED" -gt 0 ]; then
    echo "Plugins Deactivated ($PLUGINS_DEACTIVATED):"
    while read line; do
      echo "  ✅ $line"
    done < "$TMP_DIR/plugins_deactivated.txt"
    echo ""
  fi

  # Plugins uninstalled
  if [ "$PLUGINS_UNINSTALLED" -gt 0 ]; then
    echo "Plugins Uninstalled ($PLUGINS_UNINSTALLED):"
    while read line; do
      echo "  🗑️ $line"
    done < "$TMP_DIR/plugins_uninstalled.txt"
    echo ""
  fi
else
  echo "ℹ️ No changes applied - Either everything was already up to date or all updates failed."
  echo ""
fi

echo "---"
echo "Committed to dev:  $COMMIT_CHANGES"
echo "Deployed to test:  $DEPLOY_TO_TEST"
echo "Deployed to live:  $DEPLOY_TO_LIVE"
echo ""

echo "✅ Script completed successfully"
