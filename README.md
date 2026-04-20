# EventsPH - Philippine Tech Community Events Platform

[![Pantheon](https://img.shields.io/badge/Pantheon-Hosted-yellow)](https://pantheon.io)
[![WordPress](https://img.shields.io/badge/WordPress-6.8.3-blue)](https://wordpress.org)
[![PHP](https://img.shields.io/badge/PHP-7.4-purple)](https://php.net)
[![License](https://img.shields.io/badge/license-GPL--2.0-green)](LICENSE)

> A WordPress-powered platform for managing and showcasing tech community events across the Philippines.

---

## 🎯 About

EventsPH is a community-driven platform that aggregates and promotes technology events, meetups, conferences, and workshops happening across the Philippine tech ecosystem. Built on WordPress and hosted on Pantheon, it provides a centralized hub for developers, designers, and tech enthusiasts to discover and participate in local tech events.

**Live Site:** [eventsph.pantheonsite.io](https://live-eventsph.pantheonsite.io)

---

## ✨ Features

- 📅 **Event Management** - Comprehensive event listings with dates, venues, and registration details
- 🎨 **Custom Theme** - Purpose-built responsive theme optimized for event discovery
- 🔌 **Plugin Integration** - Leverages The Events Calendar and community-focused plugins
- 🚀 **CI/CD Pipeline** - Automated deployments via GitHub Actions to Pantheon
- 📦 **Manifest-Based Dependencies** - Lightweight repo tracking only custom code
- 🌐 **Multi-Environment** - Separate dev, test, and live environments on Pantheon

---

## 🛠️ Tech Stack

**Platform:**
- **CMS:** WordPress 6.8.3
- **Hosting:** Pantheon (PHP 7.4 across all environments)
- **Version Control:** Git + GitHub
- **CI/CD:** GitHub Actions

**Key Plugins:**
- The Events Calendar
- Jetpack
- Wordfence Security
- SendGrid Email Delivery
- Redirection
- And more (see `bin/manifest.json`)

**Custom Development:**
- **Theme:** `/wp-content/themes/phcommunity.tech/`
- **MU Plugins:** Custom must-use plugins for site-specific functionality

---

## 📂 Repository Structure

This repository uses a **manifest-based deployment approach** - only custom code is version-controlled, while WordPress core, plugins, and third-party themes are managed via environment manifests.

```
.
├── bin/                              # Deployment tools (NOT deployed to Pantheon)
│   ├── manifest.json                 # Environment state for dev/test/live
│   ├── manifest-exclude.txt          # Plugins/themes to exclude from manifest
│   ├── sync-manifest.sh              # Sync from Pantheon to manifest
│   ├── local-install.sh              # Install from manifest to local
│   └── bootstrap-env.sh              # Legacy: Replicate environment locally
├── .github/workflows/
│   ├── deploy-pantheon.yml           # Auto-deploy on merged PRs
│   ├── sync-manifest-from-pantheon.yml  # Scheduled manifest sync
│   └── sync-plugins-to-pantheon.yml  # Sync plugins/themes to Pantheon
├── wp-content/
│   ├── themes/phcommunity.tech/      # ✅ Custom theme (tracked)
│   ├── plugins/                      # ❌ Not tracked (managed via manifest)
│   ├── themes/                       # ❌ Not tracked (managed via manifest)
│   └── mu-plugins/                   # ✅ Custom MU plugins (tracked)
├── wp-config-local.php               # ✅ Local development config (Local by Flywheel)
├── .gitignore                        # Excludes WP core, plugins, themes
├── DOCS/                             # Documentation
│   ├── DEPLOYMENT.md                 # Deployment guide
│   ├── WORKFLOWS.md                  # GitHub Actions workflows
│   ├── CHANGELOG.md                  # Change history
│   └── URGENT-FIX.md                 # Critical fixes
└── README.md                         # This file
```

**What's tracked in Git:**
- Custom theme and MU plugins (~228KB)
- Deployment scripts and manifest
- GitHub Actions workflow
- Configuration files

**What's NOT tracked:**
- WordPress core (~50MB)
- Third-party plugins (~100MB+)
- Third-party themes (~50MB+)
- Uploads, cache, logs

**Benefits:**
- Fast git operations (small repo size)
- Quick deployments (only custom code pushed)
- Easy environment replication
- Clear separation of custom vs vendor code

---

## 🚀 Getting Started

### Prerequisites

**For Local Development:**
- [Local by Flywheel](https://localwp.com) (recommended) OR LAMP/LEMP stack
- [WP-CLI](https://wp-cli.org/) - `brew install wp-cli`
- [jq](https://stedolan.github.io/jq/) - `brew install jq`
- PHP 7.4+ (matches production environment)

**For Pantheon Integration:**
- [Terminus](https://pantheon.io/docs/terminus/install) - Pantheon CLI tool
- Pantheon Machine Token (get from [dashboard](https://dashboard.pantheon.io/users/#account/tokens/))

**Optional:**
- Composer (for advanced plugin management)

### Local Setup

We recommend using **Local by Flywheel** for local WordPress development, but you can also use any LAMP/LEMP stack.

#### Option A: Using Local by Flywheel (Recommended)

1. **Install Local by Flywheel:**
   - Download from [localwp.com](https://localwp.com)
   - Create a new site (e.g., `phtech1.local`)
   - Choose "Custom" setup with PHP 7.4

2. **Clone repository into Local site:**
   ```bash
   cd ~/Local\ Sites/phtech1/app/public
   git clone https://github.com/wpugph/eventsph.git .
   ```

3. **Create local configuration:**
   ```bash
   # wp-config-local.php already exists in the repo
   # Verify it matches your Local database credentials
   cat wp-config-local.php
   ```

4. **Sync manifest from Pantheon:**
   ```bash
   # First time: authenticate with Pantheon
   terminus auth:login --machine-token=YOUR_TOKEN
   
   # Sync environment state
   ./bin/sync-manifest.sh eventsph
   ```

5. **Install WordPress, plugins, and themes from manifest:**
   ```bash
   # Install everything from dev environment
   ./bin/local-install.sh
   
   # Or force reinstall if needed
   ./bin/local-install.sh --force
   
   # Install from test or live environment
   ./bin/local-install.sh --source-env=live
   ```

6. **Import database from Pantheon (optional):**
   ```bash
   # Create backup and download
   terminus backup:create eventsph.dev --element=db
   terminus backup:get eventsph.dev --element=db --to=~/Downloads/
   
   # Import into Local
   wp db import ~/Downloads/eventsph_dev_*.sql
   
   # Update URLs for local
   wp search-replace 'https://dev-eventsph.pantheonsite.io' 'http://phtech1.local'
   ```

7. **Access your local site:**
   - Open Local by Flywheel
   - Click "Open Site" → http://phtech1.local
   - Click "Admin" → http://phtech1.local/wp-admin

#### Option B: Manual Setup (LAMP/LEMP/MAMP)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/wpugph/eventsph.git
   cd eventsph
   ```

2. **Create wp-config.php:**
   ```bash
   # Copy and edit with your database credentials
   cp wp-config-sample.php wp-config.php
   nano wp-config.php
   ```

3. **Sync and install from manifest:**
   ```bash
   # Sync manifest from Pantheon
   ./bin/sync-manifest.sh eventsph
   
   # Install WordPress, plugins, themes
   ./bin/local-install.sh
   ```

4. **Create and import database:**
   ```bash
   wp db create
   
   # Optional: Import from Pantheon
   terminus backup:create eventsph.dev --element=db
   terminus backup:get eventsph.dev --element=db --to=.
   wp db import *.sql
   ```

5. **Start server:**
   ```bash
   wp server
   # Site available at http://localhost:8080
   ```

### Excluding Plugins/Themes from Manifest

Some plugins are environment-specific (e.g., Pantheon-only plugins) and shouldn't be synced locally.

**Edit `bin/manifest-exclude.txt`:**
```txt
# Add plugin/theme slugs (one per line)
pantheon-advanced-page-cache
uploads-sync
query-monitor
```

These exclusions apply to:
- `./bin/sync-manifest.sh` - Won't include them in manifest
- `./bin/local-install.sh` - Won't install them locally

### Keeping Local Environment in Sync

When Pantheon environment is updated:

```bash
# 1. Sync latest manifest from Pantheon
./bin/sync-manifest.sh eventsph

# 2. Update local installation
./bin/local-install.sh

# 3. Optional: Pull latest database
terminus backup:create eventsph.dev --element=db
terminus backup:get eventsph.dev --element=db --to=.
wp db import *.sql
wp search-replace 'https://dev-eventsph.pantheonsite.io' 'http://phtech1.local'
```

---

## 📖 Development Workflow

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes to custom theme or MU plugins:**
   ```bash
   # Edit files in:
   # - wp-content/themes/phcommunity.tech/
   # - wp-content/mu-plugins/
   ```

3. **Test locally:**
   ```bash
   wp server
   # Test your changes
   ```

4. **Commit and push:**
   ```bash
   git add .
   git commit -m "Add: Your feature description"
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request on GitHub**

6. **Get PR reviewed and approved**

7. **Merge PR** → Auto-deploys to Pantheon dev environment 🚀

### Adding/Updating Plugins

**Option A: Via Pantheon Dashboard (Recommended)**
```bash
# 1. Install/update plugin in Pantheon dev dashboard
# 2. Sync manifest to track the change
./bin/sync-manifest.sh eventsph

# 3. Commit updated manifest
git add bin/manifest.json
git commit -m "Update: Plugin name to version X.Y.Z"
git push
```

**Option B: Via Manifest (Advanced)**
```bash
# 1. Edit bin/manifest.json manually
# 2. Deploy and test
git add bin/manifest.json
git commit -m "Add: New plugin"
git push
```

### Syncing Environment State

**Pull latest state from Pantheon environments:**

```bash
# Sync dev, test, and live environments
./bin/sync-manifest.sh eventsph

# Commit the updated manifest
git add bin/manifest.json
git commit -m "Update: Sync manifest from Pantheon"
git push
```

This updates `bin/manifest.json` with current versions of WordPress, PHP, plugins, and themes across dev, test, and live environments.

**Notes:**
- Only **dev** environment is writable (plugins can be installed/updated)
- **test** and **live** are read-only snapshots for reference
- Plugins/themes listed in `bin/manifest-exclude.txt` will be skipped
- Manifest sync runs automatically via GitHub Actions every Monday

---

## 🚢 Deployment

### Automatic Deployment (via GitHub Actions)

Deployments happen automatically when PRs are merged to `master`:

1. PR is created and reviewed
2. PR gets approved
3. PR is merged → Triggers GitHub Action
4. GitHub Action:
   - Pushes custom code to Pantheon git
   - Installs dependencies from manifest
   - Clears cache
   - Reports deployment status

**Required GitHub Secrets:**
- `PANTHEON_MACHINE_TOKEN` - Get from [Pantheon Dashboard](https://dashboard.pantheon.io/users/#account/tokens/)
- `PANTHEON_SITE_NAME` - `eventsph`

### Manual Deployment

```bash
# Deploy to dev
git push pantheon master

# Deploy to test
terminus env:deploy eventsph.test --sync-content

# Deploy to live
terminus env:deploy eventsph.live --sync-content
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment documentation.

---

## 🧪 Testing

### Local Testing

```bash
# Start development server
wp server

# Run WordPress tests
wp core verify-checksums

# Check plugin status
wp plugin list

# Clear cache
wp cache flush
```

### Testing on Pantheon

```bash
# Test on dev environment
open https://dev-eventsph.pantheonsite.io

# Test on test environment
open https://test-eventsph.pantheonsite.io
```

---

## 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Test thoroughly**
5. **Commit your changes:** `git commit -m 'Add: Amazing feature'`
6. **Push to your fork:** `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### Coding Standards

- Follow [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/)
- Use meaningful commit messages
- Test on local environment before submitting PR
- Update documentation when adding new features

---

## 📚 Documentation

- **[DOCS/DEPLOYMENT.md](DOCS/DEPLOYMENT.md)** - Complete deployment guide
- **[DOCS/WORKFLOWS.md](DOCS/WORKFLOWS.md)** - GitHub Actions workflows documentation
- **[DOCS/CHANGELOG.md](DOCS/CHANGELOG.md)** - Project change history
- **[DOCS/URGENT-FIX.md](DOCS/URGENT-FIX.md)** - Critical fixes and troubleshooting
- **[Pantheon Docs](https://pantheon.io/docs)** - Platform documentation
- **[WordPress Codex](https://codex.wordpress.org/)** - WordPress documentation

---

## 🐛 Troubleshooting

### "Environment not found in manifest"
```bash
# Sync manifest from Pantheon
./bin/sync-manifest.sh eventsph
```

### Plugin installation failed locally
```bash
# Check if plugin exists on WordPress.org
# Premium plugins need manual installation via wp-admin

# Try forcing installation
./bin/local-install.sh --force
```

### Local environment out of sync with Pantheon
```bash
# 1. Sync latest manifest
./bin/sync-manifest.sh eventsph

# 2. Reinstall from manifest
./bin/local-install.sh --force

# 3. Optional: Import fresh database
terminus backup:create eventsph.dev --element=db
terminus backup:get eventsph.dev --element=db --to=.
wp db import *.sql
wp search-replace 'https://dev-eventsph.pantheonsite.io' 'http://phtech1.local'
```

### "Plugin X should not be installed locally"
```bash
# Add plugin slug to exclusion list
echo "plugin-slug" >> bin/manifest-exclude.txt

# Re-sync manifest
./bin/sync-manifest.sh eventsph
git add bin/manifest-exclude.txt bin/manifest.json
git commit -m "Exclude plugin-slug from manifest"
```

### Site shows critical error on Pantheon
See **[DOCS/URGENT-FIX.md](DOCS/URGENT-FIX.md)** for fixing common issues.

---

## 📄 License

This project is licensed under the GPL-2.0 License - see the [LICENSE](license.txt) file for details.

---

## 👥 Team

**Maintainers:**
- Carl Alberto - [@carl-alberto](https://github.com/carl-alberto)

**Contributors:**
- See GitHub contributors for a full list

---

## 🙏 Acknowledgments

- [WordPress Philippines User Group](https://www.meetup.com/wpphmeetup/)
- [Philippine Tech Communities](https://phtech.community)
- [Pantheon](https://pantheon.io) for hosting
- All contributors and community members

---

## 📞 Contact & Support

- **Website:** [eventsph.pantheonsite.io](https://live-eventsph.pantheonsite.io)
- **Issues:** [GitHub Issues](https://github.com/wpugph/eventsph/issues)
- **Community:** [WordPress Philippines Meetup](https://www.meetup.com/wpphmeetup/)
- **Twitter:** [@wpugph](https://twitter.com/wpugph)

---

**Built with ❤️ by the Philippine Tech Community**
