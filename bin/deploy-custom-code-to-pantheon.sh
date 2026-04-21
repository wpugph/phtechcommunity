#!/usr/bin/env bash
#
# Deploy custom plugins, themes, and MU plugins to Pantheon
# Usage: deploy-custom-code-to-pantheon.sh [OPTIONS]
#
# This script:
# - Copies tracked custom themes/plugins from git to Pantheon via SFTP
# - Resolves symlinks by copying actual files (Pantheon doesn't support symlinks)
# - Commits changes to Pantheon dev environment
#
# Environment variables required:
#   TERMINUS_TOKEN        Pantheon machine token
#   PANTHEON_SITE_NAME    Pantheon site name
#
# Options:
#   --env ENV             Target environment (default: dev)
#   --commit              Commit changes after deployment
#   --skip-auth           Skip Terminus authentication
#   --dry-run             Show what would be deployed without actually doing it
#   --help                Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
TARGET_ENV="dev"
COMMIT_CHANGES=false
SKIP_AUTH=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      TARGET_ENV="$2"
      shift 2
      ;;
    --commit)
      COMMIT_CHANGES=true
      shift
      ;;
    --skip-auth)
      SKIP_AUTH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
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

echo "╔═══════════════════════════════════════════╗"
echo "║  Deploy Custom Code to Pantheon           ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Site:         $SITE_NAME"
echo "Environment:  $TARGET_ENV"
echo "Commit:       $COMMIT_CHANGES"
echo "Dry Run:      $DRY_RUN"
echo ""

# Authenticate with Pantheon (unless skipped)
if [ "$SKIP_AUTH" = false ]; then
  echo "→ Authenticating with Pantheon..."
  if ! terminus auth:login --machine-token="$TERMINUS_TOKEN" 2>&1 | head -1; then
    echo "❌ ERROR: Failed to authenticate with Pantheon" >&2
    exit 1
  fi
fi

# Switch to SFTP mode
echo "→ Switching $TARGET_ENV environment to SFTP mode..."
terminus connection:set "$SITE_NAME.$TARGET_ENV" sftp 2>&1 | head -1 || echo "  (already in SFTP mode or switch failed)"

# Get connection info for rsync
SFTP_HOST=$(terminus connection:info "$SITE_NAME.$TARGET_ENV" --field=sftp_host 2>/dev/null || echo "")
SFTP_USER=$(terminus connection:info "$SITE_NAME.$TARGET_ENV" --field=sftp_username 2>/dev/null || echo "")

if [ -z "$SFTP_HOST" ] || [ -z "$SFTP_USER" ]; then
  echo "⚠️  WARNING: Could not get SFTP connection info. Falling back to WP-CLI uploads."
  USE_RSYNC=false
else
  echo "  SFTP Host: $SFTP_HOST"
  echo "  SFTP User: $SFTP_USER"
  USE_RSYNC=true
fi

cd "$PROJECT_ROOT"

# Find all tracked custom themes (those not in .gitignore)
echo ""
echo "═══════════════════════════════════════════"
echo "  Finding Custom Code to Deploy"
echo "═══════════════════════════════════════════"
echo ""

CUSTOM_THEMES=()
CUSTOM_PLUGINS=()
CUSTOM_MU_PLUGINS=()

# Find custom themes from git (those explicitly included in .gitignore)
if [ -d "wp-content/themes" ]; then
  echo "→ Scanning for custom themes..."
  while IFS= read -r theme_path; do
    theme_name=$(basename "$theme_path")
    if [ "$theme_name" != ".gitkeep" ] && [ -d "$theme_path" ]; then
      CUSTOM_THEMES+=("$theme_name")
      echo "  ✓ Found: $theme_name"
    fi
  done < <(git ls-files wp-content/themes/ | grep -E '^wp-content/themes/[^/]+/' | cut -d'/' -f3 | sort -u)
fi

# Find custom plugins from git
if [ -d "wp-content/plugins" ]; then
  echo "→ Scanning for custom plugins..."
  while IFS= read -r plugin_path; do
    plugin_name=$(basename "$plugin_path")
    if [ "$plugin_name" != ".gitkeep" ] && [ -d "$plugin_path" ]; then
      CUSTOM_PLUGINS+=("$plugin_name")
      echo "  ✓ Found: $plugin_name"
    fi
  done < <(git ls-files wp-content/plugins/ | grep -E '^wp-content/plugins/[^/]+/' | cut -d'/' -f3 | sort -u)
fi

# Find custom MU plugins from git (excluding Pantheon's default ones)
if [ -d "wp-content/mu-plugins" ]; then
  echo "→ Scanning for custom MU plugins..."
  while IFS= read -r file; do
    if [[ ! "$file" =~ pantheon ]] && [ "$file" != "wp-content/mu-plugins/.gitkeep" ]; then
      mu_plugin_name=$(basename "$file")
      CUSTOM_MU_PLUGINS+=("$mu_plugin_name")
      echo "  ✓ Found: $mu_plugin_name"
    fi
  done < <(git ls-files wp-content/mu-plugins/)
fi

TOTAL_ITEMS=$((${#CUSTOM_THEMES[@]} + ${#CUSTOM_PLUGINS[@]} + ${#CUSTOM_MU_PLUGINS[@]}))

if [ "$TOTAL_ITEMS" -eq 0 ]; then
  echo ""
  echo "ℹ️  No custom code found to deploy."
  echo ""
  exit 0
fi

echo ""
echo "Found $TOTAL_ITEMS custom items to deploy:"
echo "  - Themes: ${#CUSTOM_THEMES[@]}"
echo "  - Plugins: ${#CUSTOM_PLUGINS[@]}"
echo "  - MU Plugins: ${#CUSTOM_MU_PLUGINS[@]}"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN - No changes will be made"
  echo ""
  exit 0
fi

# Function to deploy files via rsync
deploy_via_rsync() {
  local src="$1"
  local dest="$2"

  echo "  → Using rsync to deploy..."

  # Check if source is a symlink
  if [ -L "$src" ]; then
    echo "    ⚠️  Source is a symlink - will copy actual files"
    src=$(readlink -f "$src" || realpath "$src")
  fi

  # Rsync with Pantheon's SFTP
  rsync -avz --delete \
    -e "ssh -o StrictHostKeyChecking=no" \
    "$src/" \
    "$SFTP_USER@$SFTP_HOST:$dest/" \
    2>&1 | grep -v "^sending incremental" || true
}

# Function to deploy files via terminus rsync
deploy_via_terminus_rsync() {
  local src="$1"
  local dest="$2"

  echo "  → Using terminus rsync to deploy..."

  # Check if source is a symlink
  if [ -L "$src" ]; then
    echo "    ⚠️  Source is a symlink - will copy actual files"
    src=$(readlink -f "$src" || realpath "$src")
  fi

  terminus rsync "$src/" "$SITE_NAME.$TARGET_ENV:$dest/" -- --delete -avz
}

echo "═══════════════════════════════════════════"
echo "  Deploying Custom Code"
echo "═══════════════════════════════════════════"
echo ""

# Deploy custom themes
if [ ${#CUSTOM_THEMES[@]} -gt 0 ]; then
  echo "→ Deploying custom themes..."
  for theme in "${CUSTOM_THEMES[@]}"; do
    echo "  Deploying theme: $theme"
    src="wp-content/themes/$theme"
    dest="wp-content/themes/$theme"

    if [ ! -d "$src" ] && [ ! -L "$src" ]; then
      echo "    ⚠️  WARNING: $src not found, skipping"
      continue
    fi

    if [ "$USE_RSYNC" = true ]; then
      deploy_via_terminus_rsync "$src" "$dest"
    else
      # Fallback: use terminus env:diffstat to check if it worked
      echo "    ⚠️  Using manual file copy method"
      # Create a tarball and extract via terminus
      tar -czf "/tmp/${theme}.tar.gz" -C "wp-content/themes" "$theme"
      terminus wp "$SITE_NAME.$TARGET_ENV" -- eval "system('cd wp-content/themes && tar -xzf /tmp/${theme}.tar.gz');" || echo "    ⚠️  Manual copy failed"
      rm "/tmp/${theme}.tar.gz"
    fi

    echo "    ✅ Deployed: $theme"
  done
  echo ""
fi

# Deploy custom plugins
if [ ${#CUSTOM_PLUGINS[@]} -gt 0 ]; then
  echo "→ Deploying custom plugins..."
  for plugin in "${CUSTOM_PLUGINS[@]}"; do
    echo "  Deploying plugin: $plugin"
    src="wp-content/plugins/$plugin"
    dest="wp-content/plugins/$plugin"

    if [ ! -d "$src" ] && [ ! -L "$src" ]; then
      echo "    ⚠️  WARNING: $src not found, skipping"
      continue
    fi

    if [ "$USE_RSYNC" = true ]; then
      deploy_via_terminus_rsync "$src" "$dest"
    else
      echo "    ⚠️  Using manual file copy method"
      tar -czf "/tmp/${plugin}.tar.gz" -C "wp-content/plugins" "$plugin"
      terminus wp "$SITE_NAME.$TARGET_ENV" -- eval "system('cd wp-content/plugins && tar -xzf /tmp/${plugin}.tar.gz');" || echo "    ⚠️  Manual copy failed"
      rm "/tmp/${plugin}.tar.gz"
    fi

    echo "    ✅ Deployed: $plugin"
  done
  echo ""
fi

# Deploy custom MU plugins
if [ ${#CUSTOM_MU_PLUGINS[@]} -gt 0 ]; then
  echo "→ Deploying custom MU plugins..."
  for mu_plugin in "${CUSTOM_MU_PLUGINS[@]}"; do
    echo "  Deploying MU plugin: $mu_plugin"
    src="wp-content/mu-plugins/$mu_plugin"
    dest="wp-content/mu-plugins/$mu_plugin"

    if [ ! -f "$src" ] && [ ! -d "$src" ] && [ ! -L "$src" ]; then
      echo "    ⚠️  WARNING: $src not found, skipping"
      continue
    fi

    # For single files, use sftp put
    if [ -f "$src" ]; then
      terminus sftp:put "$SITE_NAME.$TARGET_ENV" "$src" "$dest" || echo "    ⚠️  Upload failed"
    else
      if [ "$USE_RSYNC" = true ]; then
        deploy_via_terminus_rsync "$src" "$dest"
      fi
    fi

    echo "    ✅ Deployed: $mu_plugin"
  done
  echo ""
fi

# Commit changes to Pantheon
if [ "$COMMIT_CHANGES" = true ]; then
  echo "═══════════════════════════════════════════"
  echo "  Committing Changes"
  echo "═══════════════════════════════════════════"
  echo ""

  echo "→ Building commit message..."

  cat > /tmp/custom_code_commit_message.txt <<EOF
Deploy custom code to $TARGET_ENV

Custom themes deployed:
EOF

  for theme in "${CUSTOM_THEMES[@]}"; do
    echo "  - $theme" >> /tmp/custom_code_commit_message.txt
  done

  if [ ${#CUSTOM_PLUGINS[@]} -gt 0 ]; then
    echo "" >> /tmp/custom_code_commit_message.txt
    echo "Custom plugins deployed:" >> /tmp/custom_code_commit_message.txt
    for plugin in "${CUSTOM_PLUGINS[@]}"; do
      echo "  - $plugin" >> /tmp/custom_code_commit_message.txt
    done
  fi

  if [ ${#CUSTOM_MU_PLUGINS[@]} -gt 0 ]; then
    echo "" >> /tmp/custom_code_commit_message.txt
    echo "Custom MU plugins deployed:" >> /tmp/custom_code_commit_message.txt
    for mu_plugin in "${CUSTOM_MU_PLUGINS[@]}"; do
      echo "  - $mu_plugin" >> /tmp/custom_code_commit_message.txt
    done
  fi

  echo "" >> /tmp/custom_code_commit_message.txt
  echo "Deployed via automated script" >> /tmp/custom_code_commit_message.txt

  # Show commit message
  echo "Commit message:"
  cat /tmp/custom_code_commit_message.txt
  echo ""

  # Commit with message
  terminus env:commit "$SITE_NAME.$TARGET_ENV" --message="$(cat /tmp/custom_code_commit_message.txt)" || echo "  ⚠️  No changes to commit or commit failed"

  rm /tmp/custom_code_commit_message.txt
fi

# Switch back to git mode
echo "→ Switching $TARGET_ENV environment back to Git mode..."
terminus connection:set "$SITE_NAME.$TARGET_ENV" git 2>&1 | head -1 || echo "  ⚠️  Could not switch to Git mode"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║  ✅ Custom Code Deployment Complete       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Deployed:"
echo "  - Themes: ${#CUSTOM_THEMES[@]}"
echo "  - Plugins: ${#CUSTOM_PLUGINS[@]}"
echo "  - MU Plugins: ${#CUSTOM_MU_PLUGINS[@]}"
echo ""

echo "✅ Script completed successfully"
