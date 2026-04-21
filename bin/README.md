# Deployment Scripts

Quick reference for managing Pantheon environments and manifests.

## 🚀 Quick Commands

```bash
# Save local WordPress state to manifest
./bin/save-local-to-manifest.sh

# Save Pantheon environments to manifests
./bin/save-pantheon-to-manifest.sh

# Install from manifest to local
./bin/local-install-from-manifest.sh --source-env=dev
```

## 📋 Scripts

### `save-local-to-manifest.sh`
**Purpose:** Capture local WordPress state to manifest file  
**Output:** `bin/manifest.local.json`

**What it does:**
- Reads local WordPress installation via WP-CLI
- Captures:
  - WordPress core version
  - PHP version
  - All plugins (with versions and activation status)
  - All themes (with versions)
  - MU plugins
  - Active theme
  - Multisite configuration
- Excludes items from `bin/manifest-exclude.txt`
- Saves to `bin/manifest.local.json`

**When to use:**
- Before syncing local changes to Pantheon
- After installing/updating plugins locally
- To create a snapshot of your local environment
- When preparing to sync from local to dev

**Example:**
```bash
# Save current local state
./bin/save-local-to-manifest.sh

# Commit the manifest
git add bin/manifest.local.json
git commit -m "Update local manifest: added Jetpack 10.5"
```

**Options:**
```bash
# Save to a different environment name (default: local)
./bin/save-local-to-manifest.sh --env=dev
```

---

### `save-pantheon-to-manifest.sh`
**Purpose:** Pull environment state from Pantheon  
**Output:** `bin/manifest.dev.json`, `bin/manifest.test.json`, `bin/manifest.live.json`

**What it does:**
- Connects to Pantheon via Terminus
- Queries all standard environments (dev, test, live)
- For each environment, extracts:
  - WordPress core version
  - PHP version
  - All plugins (with status and available updates)
  - All themes
  - MU plugins
  - Active theme
  - Multisite configuration
- Excludes items from `bin/manifest-exclude.txt`
- Saves each environment to separate file: `bin/manifest.{env}.json`

**When to use:**
- Before major deployments (to capture current state)
- After installing/updating plugins via Pantheon dashboard
- Weekly (to track environment drift)
- When you want to replicate a specific environment state

**Example:**
```bash
# Sync all environments (interactive)
./bin/save-pantheon-to-manifest.sh

# With site name and auto-confirm
./bin/save-pantheon-to-manifest.sh eventsph --yes

# Commit the updated manifests
git add bin/manifest.*.json
git commit -m "Update Pantheon manifests: WordPress 6.9.4"
```

**Output files:**
- `bin/manifest.dev.json` - Dev environment
- `bin/manifest.test.json` - Test environment
- `bin/manifest.live.json` - Live environment

---

### `local-install-from-manifest.sh`
**Purpose:** Install WordPress plugins/themes from manifest  
**Input:** `bin/manifest.{env}.json`

**What it does:**
- Reads manifest file for specified environment
- Compares with current local installation
- Only installs/updates what's different (smart sync)
- Handles:
  - Installing missing plugins/themes
  - Updating/downgrading mismatched versions
  - Activating/deactivating plugins
  - Removing plugins not in manifest
  - Activating correct theme

**What it DOESN'T do:**
- Sync database (use `terminus backup:get` for that)
- Sync uploads (use `terminus rsync` for that)
- Update WordPress core (manual step)

**When to use:**
- Setting up local development environment
- After pulling latest manifest changes
- When switching between environment states (dev vs test vs live)
- Testing how a different environment configuration works locally

**Example:**
```bash
# Install from dev environment manifest (default)
./bin/local-install-from-manifest.sh

# Install from test environment
./bin/local-install-from-manifest.sh --source-env=test

# Force reinstall everything
./bin/local-install-from-manifest.sh --force

# Auto-confirm (no prompts)
./bin/local-install-from-manifest.sh --source-env=live --yes
```

**Options:**
- `--source-env=ENV` - Environment to sync from (dev, test, live, local)
- `--force` - Force reinstall even if versions match
- `--yes` - Skip confirmation prompt

---

## 📁 Manifest Files Structure

**New per-environment structure:**
```
bin/
├── manifest.local.json  ← Your local WordPress state
├── manifest.dev.json    ← Pantheon dev environment
├── manifest.test.json   ← Pantheon test environment
└── manifest.live.json   ← Pantheon live environment
```

**Benefits:**
- ✅ Easier git tracking (one file per environment)
- ✅ Fewer merge conflicts
- ✅ Clearer separation of concerns
- ✅ Simpler to diff between environments

**Each manifest contains:**
```json
{
  "site_name": "eventsph",
  "site_id": "4bf58ee6-...",
  "environment": "dev",
  "wordpress": {
    "version": "6.9.4",
    "db_version": "60717"
  },
  "php_version": "8.2",
  "plugins": {
    "jetpack": {
      "version": "13.9",
      "status": "active",
      "update": "none"
    }
  },
  "themes": { ... },
  "active_theme": "astra",
  "last_updated": "2026-04-21T12:00:00Z"
}
```

---

## 🔄 Common Workflows

### New Developer Onboarding
```bash
git clone <repo-url>
cd <repo>

# Install from dev environment manifest
./bin/local-install-from-manifest.sh --source-env=dev --yes
```

### Adding a Plugin Locally
```bash
# Install plugin via WP-CLI
wp plugin install woocommerce --version=7.5.0 --activate

# Save to local manifest
./bin/save-local-to-manifest.sh

# Commit
git add bin/manifest.local.json
git commit -m "Add: WooCommerce 7.5.0"

# Then use GitHub Actions to sync to Pantheon dev
```

### Syncing Local to Pantheon Dev
```bash
# 1. Save local state
./bin/save-local-to-manifest.sh

# 2. Commit and push
git add bin/manifest.local.json
git commit -m "Update local manifest"
git push

# 3. Run GitHub Actions workflow:
#    "Sync Pantheon from Manifest"
#    - source_env: local
#    - commit_changes: true
```

### Syncing Pantheon to Local
```bash
# Option 1: Via script
./bin/save-pantheon-to-manifest.sh eventsph --yes
./bin/local-install-from-manifest.sh --source-env=dev --yes

# Option 2: Via GitHub Actions
# Run "Sync Manifest from Pantheon" workflow
# Then: git pull
./bin/local-install-from-manifest.sh --source-env=dev --yes
```

### Replicating Production Locally
```bash
# Get live manifest
./bin/save-pantheon-to-manifest.sh eventsph --yes

# Install from live
./bin/local-install-from-manifest.sh --source-env=live

# Optional: Get production database
terminus backup:create eventsph.live --element=db
terminus backup:get eventsph.live --element=db
wp db import <backup-file>.sql
```

### Excluding Plugins/Themes
```bash
# Edit exclusion file
echo "wordfence" >> bin/manifest-exclude.txt
echo "jetpack-backup" >> bin/manifest-exclude.txt

# Excluded items won't be:
# - Captured in manifests
# - Installed/updated during sync
# - Removed during cleanup
```

---

## 🛠️ Troubleshooting

### "terminus: command not found"
```bash
brew install pantheon-systems/external/terminus
```

### "wp: command not found"
```bash
brew install wp-cli
```

### "jq: command not found"
```bash
brew install jq
```

### "Permission denied" when running scripts
```bash
chmod +x bin/*.sh
```

### "Manifest file not found"
```bash
# For local manifest
./bin/save-local-to-manifest.sh

# For Pantheon manifests
./bin/save-pantheon-to-manifest.sh
```

### Plugin fails to install
- Check if plugin is available on WordPress.org
- Premium plugins must be installed manually or via custom source
- Some plugins may have dependencies that need to be installed first

### "Environment not found in manifest"
Old error - no longer applicable!  
Each environment now has its own manifest file.

---

## 🆕 What Changed (April 2026)

**Breaking Change:** Manifest structure changed from single file to per-environment files

**Before:**
```
bin/manifest.json
└── .environments
    ├── .dev
    ├── .test
    ├── .live
    └── .local
```

**After:**
```
bin/
├── manifest.dev.json
├── manifest.test.json
├── manifest.live.json
└── manifest.local.json
```

**Migration:** Re-run `save-pantheon-to-manifest.sh` and `save-local-to-manifest.sh` to create new files.

---

## 📚 Additional Info

- **Workflows:** See [DOCS/WORKFLOWS.md](../DOCS/WORKFLOWS.md) for GitHub Actions
- **Deployment:** See [DOCS/DEPLOYMENT.md](../DOCS/DEPLOYMENT.md) for complete deployment guide
- **Changelog:** See [DOCS/CHANGELOG.md](../DOCS/CHANGELOG.md) for recent changes
