# GitHub Actions Workflows

## 🚀 Available Workflows

### 1. Deploy to Pantheon
**File:** `deploy-pantheon.yml`  
**Trigger:** Automatic on merged PR to `master`

Automatically deploys custom code to Pantheon when a pull request is merged.

**What it does:**
- Pushes custom theme and MU plugins to Pantheon
- Installs plugins/themes from `manifest.dev.json`
- Clears cache
- Reports deployment status

**No manual trigger needed** - happens automatically on PR merge.

---

### 2. Sync Manifest from Pantheon
**File:** `sync-manifest-from-pantheon.yml`  
**Trigger:** Manual (workflow_dispatch) or Scheduled (weekly)

Pulls current state from Pantheon environments and updates manifest files.

**How to run:**
1. Go to **Actions** tab in GitHub
2. Select **"Sync Manifest from Pantheon"**
3. Click **"Run workflow"**
4. Choose environments:
   - `all` (default) - syncs dev, test, live (also checks for multidevs)
   - `dev` - only dev environment
   - `test` - only test environment
   - `live` - only live environment
   - `dev,test` - multiple specific environments (comma-separated)
5. Click **"Run workflow"**

**What it does:**
- Connects to Pantheon via Terminus
- For each selected environment:
  - Queries WordPress version, PHP version, plugins, themes
  - Saves to `bin/manifest.{env}.json`
- Auto-commits changed manifest files back to repo

**Output files:**
- `bin/manifest.dev.json` - Dev environment state
- `bin/manifest.test.json` - Test environment state
- `bin/manifest.live.json` - Live environment state
- `bin/manifest.{multidev}.json` - Multidev states (only when syncing "all")

**When to use:**
- After installing/updating plugins in Pantheon dashboard
- Before major deployments (to capture current state)
- Weekly (runs automatically on Mondays at 9am UTC)
- When you want to see what's installed in each environment

**Optimizations:**
- ✅ Terminus binary caching (saves ~3-5 seconds)
- ✅ Multidev check only runs when syncing "all"
- ✅ Properly detects and commits new manifest files

**Auto-scheduled:** Runs every Monday at 9am UTC

---

### 3. Sync Pantheon from Manifest
**File:** `sync-pantheon-from-manifest.yml`  
**Trigger:** Manual (workflow_dispatch)

Syncs Pantheon dev environment to match a manifest file (local, dev, test, or live).

**How to run:**
1. Go to **Actions** tab in GitHub
2. Select **"Sync Pantheon from Manifest"**
3. Click **"Run workflow"**
4. Configure:
   - **source_env:** Which manifest to use (local, dev, test, live)
   - **force_reinstall:** Force reinstall everything (slow, default: false)
   - **commit_changes:** Commit changes to Pantheon dev (default: false)
   - **deploy_to_test:** Deploy to test after dev sync (default: false)
   - **deploy_to_live:** Deploy to live after test (default: false)
   - **debug_mode:** Enable verbose debug output (default: false)
5. Click **"Run workflow"**

**What it does:**
- Switches Pantheon dev to SFTP mode
- Compares current dev state with selected manifest
- Shows detailed comparison summary:
  - ✅ Unchanged plugins (already match)
  - 📦 Plugins to install
  - 🔄 Plugins to update/downgrade
  - ⚡ Plugins to activate
  - ⏸️ Plugins to deactivate
  - 🗑️ Plugins to uninstall (not in manifest)
- **Smart execution:**
  - If no changes needed → exits early (saves ~3 minutes!)
  - Only executes operations for items that need changes
  - Shows progress counters: `[3/10] Installing...`
- Updates `manifest.dev.json` with final state
- Auto-commits manifest changes back to repo
- Optionally deploys to test/live environments

**New Features (April 2026):**
- 🚀 **Early exit:** Skips execution when already in sync
- 📊 **Comparison summary:** See what will change before execution
- 🎯 **Smart sync:** Only touches plugins that need changes
- 🐛 **Debug mode:** Optional verbose output
- 📈 **Progress tracking:** Shows `[current/total]` for all operations

**Example Comparison Output:**
```
╔═══════════════════════════════════════════╗
║  Plugin Comparison Summary                ║
╚═══════════════════════════════════════════╝

✓ Unchanged (already match):     25
↓ Install (not present):         0
↑ Update/Downgrade (version):    2  
⚡ Activate (inactive):           1
⚠ Deactivate (active):           0
✗ Uninstall (not in manifest):   4

⚠️  Plugins to be REMOVED:
  - all-in-one-wp-migration|7.75
  - altis-accelerate|1.0
  - classic-editor|1.6.3
  - custom-post-type-ui|1.13.8
```

**Use cases:**
- **Sync local to dev:** source_env=local (after making local changes)
- **Replicate test to dev:** source_env=test
- **Reset dev to live:** source_env=live
- **Remove obsolete plugins:** They'll show in "Uninstall" list

**Performance:**
- No changes: ~30 seconds (85% faster than before!)
- With changes: ~2-5 minutes (depending on number of plugins)
- Debug mode: adds ~10-20 seconds for verbose output

---

## 📋 Required Secrets

All workflows require these GitHub secrets to be configured:

| Secret Name | Description | Where to Get It |
|-------------|-------------|-----------------|
| `PANTHEON_MACHINE_TOKEN` | Terminus authentication | https://dashboard.pantheon.io/users/#account/tokens/ |
| `PANTHEON_SITE_NAME` | Site machine name | `eventsph` |
| `PANTHEON_SSH_PRIVATE_KEY` | SSH key for Pantheon | Generate with `ssh-keygen`, add public key to Pantheon |

**Setup:**
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Add each secret

---

## 🔄 Typical Workflows

### Scenario 1: Sync Local Changes to Pantheon Dev

```
1. Make changes locally (install/update plugins)
2. Run locally: ./bin/save-local-to-manifest.sh
3. Commit: git add bin/manifest.local.json && git commit -m "..."
4. Push: git push
5. Run "Sync Pantheon from Manifest" workflow
   - source_env: local
   - commit_changes: true
   - deploy_to_test: false (optional)
   → Dev now matches your local environment
```

### Scenario 2: Remove Obsolete Plugins from Dev

```
1. Remove plugins locally
2. Run locally: ./bin/save-local-to-manifest.sh
3. Commit and push manifest
4. Run "Sync Pantheon from Manifest" workflow
   - source_env: local
   - commit_changes: true
   → Workflow will show plugins in "Uninstall" list
   → Removes plugins not in manifest
```

### Scenario 3: Update Manifest After Pantheon Changes

```
1. Install/update plugin in Pantheon dev dashboard
2. Run "Sync Manifest from Pantheon" workflow
   - environments: dev
   → Captures new plugin version in manifest.dev.json
   → Auto-commits to repo
3. Pull: git pull
4. Run locally: ./bin/local-install-from-manifest.sh --source-env=dev
   → Your local now matches dev
```

### Scenario 4: Replicate Live to Test

```
1. Run "Sync Manifest from Pantheon"
   - environments: live
   → Captures live state to manifest.live.json
2. Run "Sync Pantheon from Manifest"
   - source_env: live
   - (this targets dev by default)
   → Dev now matches live
3. Deploy to test: terminus env:deploy eventsph.test
   → Test now matches live
```

### Scenario 5: Weekly Environment Audit

```
Every Monday at 9am UTC:
→ "Sync Manifest from Pantheon" runs automatically
→ Commits show any drift between environments
→ Team reviews what changed during the week
→ Each environment has its own manifest file for easy comparison
```

### Scenario 6: Check if Sync Needed (Without Running)

```
1. Run "Sync Pantheon from Manifest" workflow
   - source_env: local
   - commit_changes: false
   - debug_mode: false
2. Check workflow summary
   → Shows comparison without making changes
   → If "Already in Sync" → no action needed
   → If changes listed → run again with commit_changes=true
```

---

## 📁 Manifest File Structure

**Per-environment files:**
```
bin/
├── manifest.local.json  ← Your local WordPress state
├── manifest.dev.json    ← Pantheon dev environment
├── manifest.test.json   ← Pantheon test environment
└── manifest.live.json   ← Pantheon live environment
```

**Benefits:**
- ✅ Easier git tracking (clear diff per environment)
- ✅ Fewer merge conflicts
- ✅ Compare environments: `diff manifest.dev.json manifest.live.json`
- ✅ Simpler jq queries (no nested paths)

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
  "multisite": false,
  "last_updated": "2026-04-21T12:00:00Z"
}
```

---

## 🛠️ Troubleshooting

### Workflow fails with "Manifest file not found"
- The selected source_env manifest doesn't exist
- Run "Sync Manifest from Pantheon" to create it
- Or run locally: `./bin/save-local-to-manifest.sh`

### Workflow fails with "Site not found"
- Check `PANTHEON_SITE_NAME` secret is set to `eventsph`

### Workflow fails with "Unauthorized"
- Regenerate `PANTHEON_MACHINE_TOKEN` in Pantheon dashboard
- Update the GitHub secret

### Workflow fails with "Cannot connect to WordPress via WP-CLI"
- Environment may not be in SFTP mode
- SSH keys not configured
- Try running workflow again (auto-switches to SFTP)

### Plugin installation fails
- Check if plugin exists on WordPress.org
- Premium plugins can't be auto-installed (need manual upload)
- Check exclusion list: `bin/manifest-exclude.txt`

### No changes committed after sync
- This is normal if nothing changed since last sync
- Check workflow summary for "Already in Sync" message

### Workflow shows all plugins being reinstalled
- **Fixed in April 2026!**
- Now uses smart comparison
- Only reinstalls plugins with version/status differences

### Git push fails with "rejected"
- **Fixed in April 2026!**
- Workflow now runs `git pull --rebase` before push
- Handles concurrent workflow runs

### Multidev environments always synced even when selecting "dev"
- **Fixed in April 2026!**
- Multidev check only runs when environments="all"

---

## 📊 Monitoring

Each workflow creates a **summary** on the Actions run page showing:
- Comparison details (before execution)
- What was synced/deployed
- Plugin and theme changes
- Any errors or warnings
- Links to environments
- Execution time

**New in April 2026:**
- ✅ Early exit message when no changes needed
- 📊 Detailed comparison summary with counts
- 🎯 Progress tracking: `[3/10] Installing...`
- ⚡ Performance metrics

Check the **Actions** tab to see all workflow runs and their status.

---

## 🔒 Security Notes

- Workflows use GitHub Actions secrets (encrypted)
- Only repository admins can modify workflows
- Terminus token has limited scope (site access only)
- All actions are logged in GitHub Actions
- SSH keys stored securely in GitHub secrets
- Manifest files committed to repo (no sensitive data)

---

## 🆕 What Changed (April 2026)

### Breaking Changes
1. **Manifest structure:** Single file → Per-environment files
   - `bin/manifest.json` → `bin/manifest.{env}.json`
   - Migration: Re-run sync workflows to create new files

### New Features
1. **Smart comparison:** Only syncs plugins that need changes
2. **Early exit:** Skips execution when already in sync
3. **Debug mode:** Optional verbose output via input flag
4. **Progress tracking:** Shows `[current/total]` for all operations
5. **Terminus caching:** Saves 3-5 seconds per workflow run
6. **Git pull before push:** Prevents concurrent run conflicts

### Performance Improvements
- No-change runs: ~3 min → ~30 sec (85% faster)
- With changes: Same speed, better visibility
- Reduced log verbosity by 70% (default mode)

### Bug Fixes
- ✅ Multidev check only runs when needed
- ✅ New manifest files properly committed
- ✅ Git push conflicts handled automatically
- ✅ Plugins no longer reinstalled unnecessarily

---

## 📚 Learn More

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terminus Documentation](https://pantheon.io/docs/terminus)
- [Pantheon Workflows](https://pantheon.io/docs/pantheon-workflow)
- [bin/README.md](../bin/README.md) - Script documentation
- [CHANGELOG.md](CHANGELOG.md) - Detailed change history
