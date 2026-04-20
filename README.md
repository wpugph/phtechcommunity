# EventsPH - Philippine Tech Community Events Platform

[![Pantheon](https://img.shields.io/badge/Pantheon-Hosted-yellow)](https://pantheon.io)
[![WordPress](https://img.shields.io/badge/WordPress-6.8.3-blue)](https://wordpress.org)
[![PHP](https://img.shields.io/badge/PHP-8.2-purple)](https://php.net)
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
- **Hosting:** Pantheon (PHP 8.2 on dev, PHP 7.4 on test/live)
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
│   ├── sync-manifest.sh              # Sync from Pantheon
│   ├── bootstrap-env.sh              # Replicate environment locally
│   └── setup.sh                      # First-time setup
├── .github/workflows/
│   └── deploy-pantheon.yml           # Auto-deploy on merged PRs
├── wp-content/
│   ├── themes/phcommunity.tech/      # ✅ Custom theme (tracked)
│   ├── plugins/                      # ❌ Not tracked (managed via manifest)
│   ├── themes/                       # ❌ Not tracked (managed via manifest)
│   └── mu-plugins/                   # ✅ Custom MU plugins (tracked)
├── .gitignore                        # Excludes WP core, plugins, themes
├── DEPLOYMENT.md                     # Deployment documentation
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

- [WP-CLI](https://wp-cli.org/) - `brew install wp-cli`
- [jq](https://stedolan.github.io/jq/) - `brew install jq`
- [Terminus](https://pantheon.io/docs/terminus/install) - Pantheon CLI
- PHP 8.2+ (for local development)
- Composer (optional, for plugin management)

### Local Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_ORG/eventsph.git
   cd eventsph
   ```

2. **Run first-time setup:**
   ```bash
   ./bin/setup.sh
   ```
   This will:
   - Check dependencies
   - Authenticate with Pantheon
   - Sync environment manifest
   - Configure git remotes

3. **Bootstrap your local environment:**
   ```bash
   # Replicate dev environment
   ./bin/bootstrap-env.sh dev
   ```
   This installs WordPress core, plugins, and themes matching the dev environment.

4. **Configure local database:**
   ```bash
   # Create local database
   wp db create

   # Import from Pantheon (optional)
   terminus backup:create eventsph.dev --element=db
   terminus backup:get eventsph.dev --element=db
   wp db import <downloaded-backup>.sql
   ```

5. **Start local server:**
   ```bash
   wp server
   # Site available at http://localhost:8080
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

Pull latest state from all Pantheon environments:

```bash
./bin/sync-manifest.sh eventsph
```

This updates `bin/manifest.json` with current versions of WordPress, PHP, plugins, and themes across dev, test, live, and multidev environments.

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

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
- **[bin/README.md](bin/README.md)** - Deployment scripts documentation
- **[URGENT-FIX.md](URGENT-FIX.md)** - Fix for current MU plugin conflict
- **[Pantheon Docs](https://pantheon.io/docs)** - Platform documentation
- **[WordPress Codex](https://codex.wordpress.org/)** - WordPress documentation

---

## 🐛 Troubleshooting

### "Environment not found in manifest"
```bash
./bin/sync-manifest.sh eventsph
```

### Plugin installation failed
Check if plugin exists on WordPress.org. Premium plugins need manual installation.

### Local environment out of sync
```bash
./bin/sync-manifest.sh eventsph
./bin/bootstrap-env.sh dev
```

### Site shows critical error
See **[URGENT-FIX.md](URGENT-FIX.md)** for fixing the duplicate MU plugin issue.

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
