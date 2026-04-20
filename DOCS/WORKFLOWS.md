# GitHub Actions Workflows

## 🚀 Available Workflows

### 1. Deploy to Pantheon
**File:** `deploy-pantheon.yml`  
**Trigger:** Automatic on merged PR to `master`

Automatically deploys custom code to Pantheon when a pull request is merged.

**What it does:**
- Pushes custom theme and MU plugins to Pantheon
- Installs plugins/themes from manifest
- Clears cache
- Reports deployment status

**No manual trigger needed** - happens automatically on PR merge.

---

### 2. Sync Manifest from Pantheon
**File:** `sync-manifest-from-pantheon.yml`  
**Trigger:** Manual (workflow_dispatch) or Scheduled (weekly)

Pulls current state from Pantheon environments and updates `bin/manifest.json`.

**How to run:**
1. Go to **Actions** tab in GitHub
2. Select **"Sync Manifest from Pantheon"**
3. Click **"Run workflow"**
4. Choose environments:
   - `all` (default) - syncs dev, test, live, and multidevs
   - `dev` - only dev
   - `dev,test` - specific environments
5. Click **"Run workflow"**

**What it does:**
- Connects to Pantheon via Terminus
- Queries WordPress version, PHP version, plugins, themes
- Updates `bin/manifest.json`
- Auto-commits changes back to repo

**When to use:**
- After installing/updating plugins in Pantheon dashboard
- Before major deployments (to capture current state)
- Weekly (runs automatically on Mondays at 9am UTC)
- When you want to see what's installed in each environment

**Auto-scheduled:** Runs every Monday at 9am UTC

---

### 3. Sync Plugins to Pantheon
**File:** `sync-plugins-to-pantheon.yml`  
**Trigger:** Manual (workflow_dispatch)

Installs plugins and themes from manifest to a Pantheon environment.

**How to run:**
1. Go to **Actions** tab in GitHub
2. Select **"Sync Plugins to Pantheon"**
3. Click **"Run workflow"**
4. Configure:
   - **Target environment:** Where to install (dev, test, live, multidev-name)
   - **Source environment:** Which manifest config to use (dev, test, live)
   - **Dry run:** `true` to preview, `false` to actually install
5. Click **"Run workflow"**

**What it does:**
- Switches environment to SFTP mode
- Reads `bin/manifest.json`
- Installs/updates plugins to exact versions
- Installs/updates themes to exact versions
- Activates correct theme
- Sets plugin activation states
- Commits changes and switches back to Git mode
- Clears cache

**Use cases:**
- **Replicate production to test:** Target=test, Source=live, Dry run=false
- **Preview changes:** Dry run=true (shows what would be installed)
- **Bootstrap new multidev:** Target=new-multidev, Source=dev
- **Downgrade environment:** Change manifest, then sync

**Example workflows:**

```bash
# Test before live deployment
Target: test
Source: dev
Dry run: false

# Preview what would change on live
Target: live
Source: dev
Dry run: true

# Clone production to staging
Target: test
Source: live
Dry run: false
```

---

## 📋 Required Secrets

All workflows require these GitHub secrets to be configured:

| Secret Name | Description | Where to Get It |
|-------------|-------------|-----------------|
| `PANTHEON_MACHINE_TOKEN` | Terminus authentication | https://dashboard.pantheon.io/users/#account/tokens/ |
| `PANTHEON_SITE_NAME` | Site machine name | `eventsph` |

**Setup:**
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Add each secret

---

## 🔄 Typical Workflows

### Scenario 1: Update Plugin in Dev, Deploy to Live

```
1. Install/update plugin in Pantheon dev dashboard
2. Run "Sync Manifest from Pantheon" (GitHub Actions)
   → Captures new plugin version in manifest
3. Create PR with updated manifest
4. Merge PR
   → Auto-deploys to dev via "Deploy to Pantheon"
5. Test in dev
6. Deploy to test: terminus env:deploy eventsph.test
7. Test in test
8. Deploy to live: terminus env:deploy eventsph.live
```

### Scenario 2: Replicate Production to Staging

```
1. Run "Sync Manifest from Pantheon" (captures live state)
2. Run "Sync Plugins to Pantheon"
   - Target: test
   - Source: live
   - Dry run: false
   → Test now matches live plugin/theme versions
```

### Scenario 3: Preview Changes Before Deploying to Live

```
1. Make changes in dev
2. Run "Sync Manifest from Pantheon"
3. Run "Sync Plugins to Pantheon"
   - Target: live
   - Source: dev
   - Dry run: true
   → Shows what would change (doesn't actually install)
4. Review summary
5. If looks good, run again with Dry run: false
```

### Scenario 4: Weekly Environment Audit

```
Every Monday at 9am UTC:
→ "Sync Manifest from Pantheon" runs automatically
→ Commits show any drift between environments
→ Team reviews what changed during the week
```

---

## 🛠️ Troubleshooting

### Workflow fails with "Site not found"
- Check `PANTHEON_SITE_NAME` secret is set to `eventsph`

### Workflow fails with "Unauthorized"
- Regenerate `PANTHEON_MACHINE_TOKEN` in Pantheon dashboard
- Update the GitHub secret

### Plugin installation fails
- Check if plugin exists on WordPress.org
- Premium plugins can't be auto-installed (need manual upload)

### No changes committed after sync
- This is normal if nothing changed in Pantheon since last sync
- Check workflow summary for details

### "Fatal error: Cannot redeclare..."
- See [URGENT-FIX.md](../../URGENT-FIX.md) to fix duplicate MU plugin issue

---

## 📊 Monitoring

Each workflow creates a **summary** on the Actions run page showing:
- What was synced/deployed
- Plugin and theme versions
- Any errors or warnings
- Links to environments

Check the **Actions** tab to see all workflow runs and their status.

---

## 🔒 Security Notes

- Workflows use GitHub Actions secrets (encrypted)
- Only repository admins can modify workflows
- Terminus token has limited scope (site access only)
- All actions are logged in GitHub Actions
- Dry run mode available for testing

---

## 📚 Learn More

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terminus Documentation](https://pantheon.io/docs/terminus)
- [Pantheon Workflows](https://pantheon.io/docs/pantheon-workflow)
