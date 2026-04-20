# Deployment Scripts

Quick reference for managing Pantheon environments.

## 🚀 Quick Commands

```bash
# First-time setup
./bin/setup.sh

# Sync environment state from Pantheon → manifest.json
./bin/sync-manifest.sh <site-name>

# Replicate environment locally from manifest.json
./bin/bootstrap-env.sh dev|test|live|multidev-name
```

## 📋 Scripts

### `setup.sh`
**Purpose:** First-time setup for new developers  
**What it does:**
- Checks all dependencies (Terminus, WP-CLI, jq, git)
- Authenticates with Terminus
- Syncs initial manifest from Pantheon
- Configures Pantheon git remote
- Creates necessary .gitkeep files

**When to use:**
- Setting up the project for the first time
- Onboarding new team members

---

### `sync-manifest.sh`
**Purpose:** Pull environment state from Pantheon  
**What it does:**
- Connects to Pantheon via Terminus
- Queries all environments (dev, test, live, multidevs)
- Extracts versions for:
  - WordPress core
  - PHP
  - All plugins (with status and available updates)
  - All themes
  - MU plugins
  - Active theme
  - Multisite configuration
- Saves everything to `bin/manifest.json`

**When to use:**
- Before major deployments (to capture current state)
- After installing/updating plugins via Pantheon dashboard
- Weekly (to track environment drift)
- When you want to replicate a specific environment state

**Example:**
```bash
# Sync all environments
./bin/sync-manifest.sh phtech1

# Commit the updated manifest
git add manifest.json
git commit -m "Update manifest: added Jetpack 10.5"
```

---

### `bootstrap-env.sh`
**Purpose:** Replicate a Pantheon environment locally  
**What it does:**
- Reads `bin/manifest.json`
- Installs/updates WordPress core to match version
- Installs/updates all plugins with exact versions
- Installs/updates all themes (except custom theme)
- Activates correct theme
- Sets plugin activation states

**What it DOESN'T do:**
- Sync database (use `terminus backup:get` for that)
- Sync uploads (use `terminus rsync` for that)

**When to use:**
- Setting up local development environment
- After pulling latest manifest changes
- When switching between environment states (dev vs test vs live)
- Testing how a different environment configuration works locally

**Example:**
```bash
# Replicate dev environment
./bin/bootstrap-env.sh dev

# Replicate test environment
./bin/bootstrap-env.sh test

# Replicate a multidev environment
./bin/bootstrap-env.sh feature-authentication
```

---

## 🔄 Common Workflows

### New Developer Onboarding
```bash
git clone <repo-url>
cd <repo>
./bin/setup.sh
./bin/bootstrap-env.sh dev
```

### Adding a Plugin
```bash
# Option 1: Via Pantheon Dashboard
# 1. Install plugin in Pantheon dev
# 2. Run sync
./bin/sync-manifest.sh phtech1
git add bin/manifest.json
git commit -m "Add: WooCommerce 7.5.0"

# Option 2: Via Local WP-CLI
wp plugin install woocommerce --version=7.5.0 --activate
./bin/sync-manifest.sh phtech1  # Verify it matches
git add bin/manifest.json
git commit -m "Add: WooCommerce 7.5.0"
```

### Updating Dependencies
```bash
# Update in Pantheon dev environment via dashboard
./bin/sync-manifest.sh phtech1
./bin/bootstrap-env.sh dev  # Test locally
git add bin/manifest.json
git commit -m "Update: Jetpack 10.4 → 10.5"
```

### Replicating Production Locally
```bash
./bin/sync-manifest.sh phtech1
./bin/bootstrap-env.sh live

# Optional: Get production database
terminus backup:create phtech1.live --element=db
terminus backup:get phtech1.live --element=db
wp db import <backup-file>.sql
```

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

### Plugin fails to install
- Check if plugin is available on WordPress.org
- Premium plugins must be installed manually or via custom source
- Some plugins may have dependencies that need to be installed first

### Environment not in manifest
```bash
# Re-sync to include all environments
./bin/sync-manifest.sh phtech1
```

## 📚 Additional Info

See [DEPLOYMENT.md](../DEPLOYMENT.md) for complete documentation.
