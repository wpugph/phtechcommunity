#!/usr/bin/env bash
#
# Generate WordPress manifest JSON
# Usage: generate-manifest-json.sh [--error] SITE_NAME SITE_UUID ENV [WP_VERSION PHP_VERSION PLUGINS_JSON THEMES_JSON ACTIVE_THEME IS_MULTISITE]
#

set -euo pipefail

ERROR_MODE=false
if [ "${1:-}" = "--error" ]; then
  ERROR_MODE=true
  shift
fi

SITE_NAME="${1:-unknown}"
SITE_UUID="${2:-unknown}"
ENV="${3:-unknown}"

if [ "$ERROR_MODE" = "true" ]; then
  # Generate minimal error JSON
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{
  "site_name": "%s",
  "site_id": "%s",
  "environment": "%s",
  "wordpress": {"version": "unknown", "db_version": "unknown"},
  "php_version": "unknown",
  "plugins": {},
  "themes": {},
  "mu_plugins": {},
  "active_theme": "unknown",
  "multisite": false,
  "last_updated": "%s",
  "error": "WP-CLI connectivity failed"
}\n' "$SITE_NAME" "$SITE_UUID" "$ENV" "$TIMESTAMP"
else
  # Generate full manifest JSON
  WP_VERSION="${4:-unknown}"
  PHP_VERSION="${5:-unknown}"
  PLUGINS_OBJ="${6:-\{\}}"
  THEMES_OBJ="${7:-\{\}}"
  ACTIVE_THEME="${8:-unknown}"
  IS_MULTISITE="${9:-false}"
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Use jq for safe JSON generation with proper escaping
  jq -n \
    --arg site_name "$SITE_NAME" \
    --arg site_id "$SITE_UUID" \
    --arg env "$ENV" \
    --arg wp_version "$WP_VERSION" \
    --arg php_version "$PHP_VERSION" \
    --argjson plugins "$PLUGINS_OBJ" \
    --argjson themes "$THEMES_OBJ" \
    --arg active_theme "$ACTIVE_THEME" \
    --argjson is_multisite "$IS_MULTISITE" \
    --arg timestamp "$TIMESTAMP" \
    '{
      "site_name": $site_name,
      "site_id": $site_id,
      "environment": $env,
      "wordpress": {
        "version": $wp_version,
        "db_version": "unknown"
      },
      "php_version": $php_version,
      "plugins": $plugins,
      "themes": $themes,
      "mu_plugins": {},
      "active_theme": $active_theme,
      "multisite": $is_multisite,
      "last_updated": $timestamp
    }'
fi
