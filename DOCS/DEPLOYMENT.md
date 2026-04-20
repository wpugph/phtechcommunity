# Pantheon Deployment & Environment Management

This repository uses a **lightweight manifest-based approach** for WordPress deployments to Pantheon. Only custom code is version-controlled; WordPress core, plugins, and themes are managed via `manifest.json`.

## 🎯 What's Version Controlled

✅ **Tracked in Git (NOT deployed to Pantheon):**
- Deployment tools: `bin/` folder
  - Environment manifest: `bin/manifest.json`
  - Deployment scripts: `bin/*.sh`

✅ **Tracked in Git AND deployed to Pantheon:**
- Custom theme: `wp-content/themes/phcommunity.tech/`
- Custom MU plugins (excluding Pantheon's)

❌ **NOT Tracked (managed via manifest):**
- WordPress core
- All plugins
- Third-party themes
- Uploads, cache, logs

## 📋 Prerequisites

### Local Development
- [WP-CLI](https://wp-cli.org/) - `brew install wp-cli`
- [jq](https://stedolan.github.io/jq/) - `brew install jq`
- [Terminus](https://pantheon.io/docs/terminus/install) - Pantheon CLI

### GitHub Actions (Secrets)
Set these in your GitHub repository settings:

| Secret | Description | Example |
|--------|-------------|---------|
| `PANTHEON_MACHINE_TOKEN` | Terminus machine token | `xxxxx-xxxxx-xxxxx` |
| `PANTHEON_SITE_NAME` | Pantheon site name | `phtech1` |

Get machine token: https://dashboard.pantheon.io/users/#account/tokens/

## 🚀 Deployment Workflow

### Automatic Deployment (via GitHub Actions)

1. **Create feature branch** and make changes to custom theme/plugins
2. **Commit and push** changes
3. **Create Pull Request** to `master`
4. **Get PR approved** by team member
5. **Merge PR** → GitHub Actions automatically:
   - Pushes custom code to Pantheon git
   - Installs/updates plugins and themes from `manifest.json`
   - Clears cache
   - Deploys to `dev` environment

### Manual Deployment (via local terminal)

```bash
# 1. Add Pantheon remote (first time only)
terminus connection:info your-site-name.dev --field=git_url
git remote add pantheon <git-url-from-above>

# 2. Push to Pantheon
git push pantheon master

# 3. Install dependencies from manifest
./bin/bootstrap-env.sh dev
```

## 📊 Environment Management

### Sync Manifest from Pantheon

Pull current state of all environments (dev, test, live, multidevs) into `bin/manifest.json`:

```bash
./bin/sync-manifest.sh your-site-name
```

This captures:
- WordPress core version
- PHP version
- All plugins (name, version, status, available updates)
- All themes (name, version, status)
- MU plugins
- Active theme
- Multisite configuration

**When to sync:**
- Before major deployments
- After installing plugins via Pantheon dashboard
- Weekly (to track environment drift)
- Before replicating environment locally

### Bootstrap Local Environment

Replicate any Pantheon environment locally from `bin/manifest.json`:

```bash
# Replicate dev environment
./bin/bootstrap-env.sh dev

# Replicate test environment
./bin/bootstrap-env.sh test

# Replicate a multidev
./bin/bootstrap-env.sh feature-branch
```

This will:
- Install/update WordPress core to match
- Install/update all plugins with exact versions
- Install/update all themes (except custom)
- Activate correct theme
- Set plugin activation states

**Note:** Database and uploads are NOT synced. To sync those:

```bash
# Sync database
terminus backup:create your-site-name.dev --element=db
terminus backup:get your-site-name.dev --element=db
wp db import <downloaded-file>.sql

# Sync uploads
terminus rsync your-site-name.dev:files/ wp-content/uploads/
```

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy-pantheon.yml    # Auto-deployment workflow
├── bin/                           # ✅ Tracked in git, NOT deployed to Pantheon
│   ├── manifest.json              # Environment state for all envs
│   ├── sync-manifest.sh           # Pull environment state from Pantheon
│   ├── bootstrap-env.sh           # Replicate environment locally
│   ├── setup.sh                   # First-time setup
│   └── README.md                  # Scripts documentation
├── wp-content/
│   ├── themes/
│   │   └── phcommunity.tech/      # ✅ Custom theme (deployed)
│   ├── plugins/                   # ❌ Not tracked (managed via manifest)
│   └── mu-plugins/                # ✅ Custom MU plugins (deployed)
├── .gitignore                     # Ignores WP core, plugins, themes
└── DEPLOYMENT.md                  # This file
```

## 🔄 Common Workflows

### Adding a New Plugin

**Option A: Via Pantheon Dashboard (Recommended)**
```bash
# 1. Install plugin in Pantheon dev environment
# 2. Sync manifest
./bin/sync-manifest.sh your-site-name

# 3. Commit updated manifest
git add bin/manifest.json
git commit -m "Add plugin: plugin-name"
git push
```

**Option B: Via Manifest (Advanced)**
```bash
# 1. Manually edit manifest.json to add plugin
# 2. Test locally
./bin/bootstrap-env.sh dev

# 3. Commit and deploy
git add manifest.json
git commit -m "Add plugin: plugin-name"
git push
```

### Updating a Plugin

```bash
# 1. Update in Pantheon dev environment
# 2. Sync manifest
./bin/sync-manifest.sh your-site-name

# 3. Commit updated manifest
git add bin/manifest.json
git commit -m "Update plugin: plugin-name to vX.Y.Z"
git push
```

### Promoting to Test/Live

```bash
# Deploy code to test
terminus env:deploy your-site-name.test --sync-content

# Install dependencies from manifest (if manifest changed)
./bin/bootstrap-env.sh test  # This installs on Pantheon via terminus

# Deploy to live
terminus env:deploy your-site-name.live --sync-content
```

### Creating a Multidev

```bash
# 1. Create multidev
terminus multidev:create your-site-name.dev new-feature

# 2. Sync manifest (includes new multidev)
./bin/sync-manifest.sh your-site-name

# 3. Work on multidev
git checkout -b new-feature
# ... make changes ...
git push pantheon new-feature:new-feature
```

## 🎯 Benefits of This Approach

### Fast Deployments
- Only ~2MB of custom code pushed (vs ~50MB+ with WP core)
- Shallow git clones
- Parallel dependency installation
- No build steps needed

### Environment Parity
- Exact versions tracked across all environments
- Easy to spot environment drift
- Reproducible local setups
- Clear dependency management

### Clean Repository
- No vendor code in git
- Small repo size (~5MB vs ~500MB)
- Fast clones and checkouts
- Clear code ownership

### Flexibility
- Update plugins via dashboard or manifest
- Track multiple environments simultaneously
- Easy rollbacks (git revert)
- Support for multidevs

## 🛠️ Troubleshooting

### "Environment not found in manifest"
Re-sync from Pantheon:
```bash
./bin/sync-manifest.sh your-site-name
```

### "Plugin installation failed"
Check if plugin exists on WordPress.org. Premium plugins need manual installation.

### "WP-CLI not found" in GitHub Actions
This is expected - we use `terminus wp` which runs WP-CLI on Pantheon servers.

### Local environment out of sync
```bash
./bin/sync-manifest.sh your-site-name
./bin/bootstrap-env.sh dev
```

## 📚 Additional Resources

- [Pantheon Documentation](https://pantheon.io/docs)
- [Terminus Commands](https://pantheon.io/docs/terminus/commands)
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)

## 🤝 Contributing

1. Always sync manifest before major changes
2. Test locally before pushing
3. Get PR reviews for production deployments
4. Document new dependencies in commit messages
