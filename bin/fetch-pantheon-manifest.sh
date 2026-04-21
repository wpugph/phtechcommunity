#!/usr/bin/env bash
#
# Fetch WordPress manifest data from a Pantheon environment
# Usage: fetch-pantheon-manifest.sh SITE_NAME ENV
#
# Returns JSON manifest to stdout, errors to stderr
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SITE_NAME="${1:?Site name required}"
ENV="${2:?Environment required (dev, test, live, or multidev name)}"

# Get site UUID
if ! SITE_UUID=$(terminus site:info "$SITE_NAME" --field=id 2>&1); then
  echo "❌ ERROR: Cannot access site '$SITE_NAME'" >&2
  echo "Terminus output:" >&2
  terminus site:info "$SITE_NAME" 2>&1 | head -10 >&2
  "$SCRIPT_DIR/generate-manifest-json.sh" --error "$SITE_NAME" "unknown" "$ENV"
  exit 0
fi

# Wake environment
echo "→ Fetching $ENV environment..." >&2
echo "  Waking environment..." >&2
terminus env:wake "$SITE_NAME.$ENV" 2>&1 | head -1 >&2
sleep 5

# Check connection mode and switch to SFTP if needed
echo "  Checking connection mode..." >&2
# Don't fail script if connection:info fails - it might not support --field=mode
CONN_MODE_OUTPUT=$(terminus connection:info "$SITE_NAME.$ENV" --field=mode 2>&1 || true)
CONN_MODE=$(echo "$CONN_MODE_OUTPUT" | head -1 | tr -d '[:space:]' || echo "unknown")

# Remove error prefix if present
CONN_MODE=$(echo "$CONN_MODE" | sed 's/\[error\]//g' | tr -d '[:space:]')

if [ -z "$CONN_MODE" ] || [ "$CONN_MODE" = "" ] || echo "$CONN_MODE" | grep -qi "error"; then
  echo "  Warning: Could not determine connection mode" >&2
  echo "  Terminus output: $CONN_MODE_OUTPUT" >&2
  CONN_MODE="unknown"
fi

echo "  Current mode: $CONN_MODE" >&2

if [ "$CONN_MODE" = "git" ]; then
  echo "  Switching to SFTP mode (required for WP-CLI)..." >&2
  terminus connection:set "$SITE_NAME.$ENV" sftp --yes 2>&1 | head -1 >&2 || true
  sleep 3
elif [ "$CONN_MODE" = "unknown" ] || echo "$CONN_MODE" | grep -qi "requested"; then
  echo "  Attempting to set SFTP mode anyway..." >&2
  terminus connection:set "$SITE_NAME.$ENV" sftp --yes 2>&1 | head -3 >&2 || true
  sleep 3
fi

# Test WP-CLI connectivity with retry
echo "  Testing WP-CLI connectivity..." >&2
echo "  Command: terminus wp $SITE_NAME.$ENV -- core version" >&2
WP_CLI_READY=false
for i in {1..3}; do
  echo "    Attempt $i/3..." >&2
  WP_TEST_OUTPUT=$(terminus wp "$SITE_NAME.$ENV" -- core version 2>&1 || true)
  WP_TEST_EXIT=$?

  if [ $WP_TEST_EXIT -eq 0 ] && echo "$WP_TEST_OUTPUT" | grep -qE "^[0-9]+\.[0-9]+"; then
    WP_CLI_READY=true
    echo "    ✓ Success! WordPress version: $WP_TEST_OUTPUT" >&2
    break
  else
    echo "    Failed (exit code: $WP_TEST_EXIT)" >&2
    if [ $i -eq 1 ]; then
      echo "    Error output: $WP_TEST_OUTPUT" | head -3 >&2
    fi
  fi

  if [ $i -lt 3 ]; then
    echo "    Waiting 5s before retry..." >&2
    sleep 5
  fi
done

if [ "$WP_CLI_READY" = "false" ]; then
  echo "  ❌ ERROR: Cannot connect to WordPress via WP-CLI after 3 attempts" >&2
  echo "" >&2
  echo "  Diagnostics:" >&2

  echo "    Checking if environment exists..." >&2
  if terminus env:list "$SITE_NAME" --format=list 2>/dev/null | grep -q "^$ENV$"; then
    echo "      ✓ Environment '$ENV' exists" >&2
  else
    echo "      ✗ Environment '$ENV' NOT found!" >&2
    echo "      Available environments:" >&2
    terminus env:list "$SITE_NAME" --format=list 2>&1 | sed 's/^/        /' >&2
  fi
  echo "" >&2

  echo "    Environment info:" >&2
  terminus env:info "$SITE_NAME.$ENV" 2>&1 | head -10 | sed 's/^/      /' >&2
  echo "" >&2

  echo "    Last WP-CLI error:" >&2
  echo "      Command: terminus wp $SITE_NAME.$ENV -- core version" >&2
  echo "      Output:" >&2
  WP_ERROR=$(terminus wp "$SITE_NAME.$ENV" -- core version 2>&1)
  if [ -z "$WP_ERROR" ]; then
    echo "        (no output from terminus - command timed out or failed silently)" >&2
  else
    echo "$WP_ERROR" | sed 's/^/        /' >&2
  fi
  echo "" >&2

  # Also try a simpler terminus command to see if it's a WP-CLI specific issue
  echo "    Testing basic terminus connection:" >&2
  echo "      Command: terminus env:info $SITE_NAME.$ENV --field=connection_mode" >&2
  BASIC_TEST=$(terminus env:info "$SITE_NAME.$ENV" --field=connection_mode 2>&1 || echo "FAILED")
  echo "      Result: $BASIC_TEST" >&2
  echo "" >&2

  echo "  Returning minimal data for $ENV" >&2
  "$SCRIPT_DIR/generate-manifest-json.sh" --error "$SITE_NAME" "$SITE_UUID" "$ENV"
  exit 0
fi

echo "  ✓ WP-CLI connected" >&2

# Get WordPress version
WP_VERSION=$(terminus wp "$SITE_NAME.$ENV" -- core version 2>&1 | grep -oE "^[0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 || echo "unknown")

# Get PHP version
PHP_VERSION=$(terminus env:info "$SITE_NAME.$ENV" --field=php_version 2>/dev/null || echo "unknown")

# Get plugins (robust JSON extraction)
PLUGINS_RAW=$(terminus wp "$SITE_NAME.$ENV" -- plugin list --format=json 2>&1)

# Try to extract valid JSON - look for array anywhere in output
if echo "$PLUGINS_RAW" | jq -e '.' >/dev/null 2>&1; then
  # Valid JSON found
  PLUGINS_JSON=$(echo "$PLUGINS_RAW" | jq -c '.')
elif echo "$PLUGINS_RAW" | grep -q '^\['; then
  # Found array at start of line
  PLUGINS_JSON=$(echo "$PLUGINS_RAW" | grep '^[[]' | head -1)
else
  # No valid JSON, show error and use empty
  echo "  ⚠️  Could not parse plugins JSON" >&2
  echo "  Raw output (first 200 chars): ${PLUGINS_RAW:0:200}" >&2
  PLUGINS_JSON="[]"
fi

# Debug: show plugin count
PLUGIN_COUNT=$(echo "$PLUGINS_JSON" | jq 'length' 2>&1 | grep -E '^[0-9]+$' || echo "0")
echo "  Plugins found: $PLUGIN_COUNT" >&2
echo "  Debug: PLUGINS_JSON first 200 chars = ${PLUGINS_JSON:0:200}" >&2

# Get themes (robust JSON extraction)
THEMES_RAW=$(terminus wp "$SITE_NAME.$ENV" -- theme list --format=json 2>&1)

# Try to extract valid JSON
if echo "$THEMES_RAW" | jq -e '.' >/dev/null 2>&1; then
  THEMES_JSON=$(echo "$THEMES_RAW" | jq -c '.')
elif echo "$THEMES_RAW" | grep -q '^\['; then
  THEMES_JSON=$(echo "$THEMES_RAW" | grep '^[[]' | head -1)
else
  echo "  ⚠️  Could not parse themes JSON" >&2
  echo "  Raw output (first 200 chars): ${THEMES_RAW:0:200}" >&2
  THEMES_JSON="[]"
fi

# Debug: show theme count
THEME_COUNT=$(echo "$THEMES_JSON" | jq 'length' 2>&1 | grep -E '^[0-9]+$' || echo "0")
echo "  Themes found: $THEME_COUNT" >&2
echo "  Debug: THEMES_JSON first 200 chars = ${THEMES_JSON:0:200}" >&2

# Get active theme
ACTIVE_THEME=$(terminus wp "$SITE_NAME.$ENV" -- theme list --status=active --field=name 2>&1 | grep -v "^\[" | grep -v "^Command:" | grep -v "^Warning:" | head -1 || echo "unknown")

# Get multisite status
IS_MULTISITE=$(terminus wp "$SITE_NAME.$ENV" -- eval 'echo is_multisite() ? "true" : "false";' 2>&1 | grep -E "^(true|false)$" | head -1 || echo "false")

# Process plugins JSON to object format (with error handling)
if [ "$PLUGINS_JSON" = "[]" ] || [ -z "$PLUGINS_JSON" ]; then
  PLUGINS_OBJ="{}"
else
  # Try to transform
  set +e  # Temporarily disable exit on error
  PLUGINS_OBJ=$(echo "$PLUGINS_JSON" | jq -c 'map({(.name): {version: .version, status: .status, update: .update, update_version: .update_version}}) | add // {}' 2>&1)
  JQ_EXIT=$?
  set -e  # Re-enable exit on error

  if [ $JQ_EXIT -ne 0 ]; then
    echo "  ⚠️  jq transformation failed for plugins (exit $JQ_EXIT): ${PLUGINS_OBJ:0:200}" >&2
    PLUGINS_OBJ="{}"
  elif [ -z "$PLUGINS_OBJ" ] || [ "$PLUGINS_OBJ" = "null" ]; then
    echo "  ⚠️  Could not process plugins to object format, using empty" >&2
    PLUGINS_OBJ="{}"
  fi
fi

# Process themes JSON to object format (with error handling)
if [ "$THEMES_JSON" = "[]" ] || [ -z "$THEMES_JSON" ]; then
  THEMES_OBJ="{}"
else
  # Try to transform
  set +e  # Temporarily disable exit on error
  THEMES_OBJ=$(echo "$THEMES_JSON" | jq -c 'map({(.name): {version: .version, status: .status, update: .update}}) | add // {}' 2>&1)
  JQ_EXIT=$?
  set -e  # Re-enable exit on error

  if [ $JQ_EXIT -ne 0 ]; then
    echo "  ⚠️  jq transformation failed for themes (exit $JQ_EXIT): ${THEMES_OBJ:0:200}" >&2
    THEMES_OBJ="{}"
  elif [ -z "$THEMES_OBJ" ] || [ "$THEMES_OBJ" = "null" ]; then
    echo "  ⚠️  Could not process themes to object format, using empty" >&2
    THEMES_OBJ="{}"
  fi
fi

# Debug: show what we're passing
echo "  Debug: WP_VERSION = $WP_VERSION" >&2
echo "  Debug: PHP_VERSION = $PHP_VERSION" >&2
echo "  Debug: ACTIVE_THEME = $ACTIVE_THEME" >&2
echo "  Debug: IS_MULTISITE = $IS_MULTISITE" >&2
echo "  Debug: PLUGINS_OBJ length = ${#PLUGINS_OBJ} chars, content = ${PLUGINS_OBJ:0:100}" >&2
echo "  Debug: THEMES_OBJ length = ${#THEMES_OBJ} chars, content = ${THEMES_OBJ:0:100}" >&2

# Build JSON using reusable script
"$SCRIPT_DIR/generate-manifest-json.sh" "$SITE_NAME" "$SITE_UUID" "$ENV" "$WP_VERSION" "$PHP_VERSION" "$PLUGINS_OBJ" "$THEMES_OBJ" "$ACTIVE_THEME" "$IS_MULTISITE"
