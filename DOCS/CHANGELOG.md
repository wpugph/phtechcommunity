# Changelog

All notable changes to the EventsPH WordPress project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.1.0] - 2026-04-21

### 🚀 Major Changes

**BREAKING CHANGE:** Manifest structure changed from single file to per-environment files
- `bin/manifest.json` → `bin/manifest.{env}.json` (dev, test, live, local)
- Each environment now has its own manifest file
- Migration: Re-run sync workflows to create new files

### Added
- Per-environment manifest files (`manifest.local.json`, `manifest.dev.json`, etc.)
- Smart comparison logic in sync-pantheon-from-manifest workflow
- Early exit optimization (skips execution when no changes needed)
- Debug mode flag for workflows (`debug_mode: true/false`)
- Progress tracking with counters (`[3/10] Installing...`)
- Terminus binary caching in workflows (saves 3-5s per run)
- Plugin removal detection (shows "Uninstall" list for plugins not in manifest)
- Comparison summary before execution showing:
  - ✅ Unchanged plugins (already match)
  - 📦 Plugins to install
  - 🔄 Plugins to update/downgrade
  - ⚡ Plugins to activate
  - ⏸️ Plugins to deactivate
  - 🗑️ Plugins to uninstall
- Git pull with rebase before push (prevents concurrent workflow conflicts)

### Changed
- Workflow optimizations:
  - Sleep time reduced: 5s → 2s (terminus auto-waits internally)
  - Sparse checkout (only fetches bin/ and .github/ directories)
  - Quieter apt-get install output
- Only processes plugins that actually need changes (no unnecessary reinstalls)
- Multidev check only runs when syncing "all" environments
- Improved git commit detection for new manifest files
- Reduced default log verbosity by 70%

### Fixed
- **CRITICAL:** sync-manifest-from-pantheon returning empty plugins/themes
  - Bug: Contradictory grep filters removed JSON arrays
  - Fix: Simplified filtering logic to properly extract JSON
- Plugins being unnecessarily reinstalled when already matching manifest
- Git push failures when concurrent workflows run
- Multidev environments synced even when selecting specific environment
- New manifest files not being committed to repository

### Performance
- No-change workflow runs: ~3 min → ~30 sec (85% faster!)
- With changes: Same speed, better visibility
- Early exit saves 2-3 minutes when environment already matches manifest

### Documentation
- Updated bin/README.md for per-environment manifests
- Updated DOCS/WORKFLOWS.md with new features and troubleshooting
- Added migration notes for manifest structure change
- Added performance metrics and optimization details

### Environment State (2026-04-21)
- **Site:** eventsph (4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c)
- **Dev:** WordPress 6.9.4, PHP 7.4, 29 plugins
- **Local:** WordPress 6.9.4, PHP 7.4.30, 29 plugins
- **Test:** PHP 7.4
- **Live:** PHP 7.4

---

## [1.0.0] - 2026-04-20

### Added
- Initial manifest-based deployment system
- GitHub Actions workflows for automated deployment and manifest sync
- Manifest-based dependency management system
- Workflow dispatch for manual manifest sync from Pantheon
- Workflow dispatch for syncing plugins/themes to Pantheon environments
- Scheduled weekly manifest sync (Mondays 9am UTC)
- Comprehensive documentation in DOCS folder
- Dry-run mode for plugin sync workflow
- Custom theme: `phcommunity.tech`
- Deployment scripts:
  - `bin/sync-manifest.sh` - Sync from Pantheon
  - `bin/bootstrap-env.sh` - Bootstrap local environment
  - `bin/setup.sh` - First-time setup
- GitHub Actions auto-deployment on PR merge
- Environment manifest tracking (dev, test, live, multidevs)
- Documentation:
  - DEPLOYMENT.md - Deployment guide
  - WORKFLOWS.md - GitHub Actions guide
  - bin/README.md - Scripts documentation

### Changed
- Refactored repository to track only custom code (~23 files vs ~10,000)
- WordPress core, plugins, and third-party themes now managed via manifest
- Deployment workflow now excludes bin/ folder from Pantheon
- Repository size reduced from ~305MB to ~5-10MB

### Fixed
- Documented fix for duplicate Pantheon MU plugin error

### Environment State (2026-04-20)
- **Site:** eventsph (4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c)
- **Dev:** WordPress 6.8.3, PHP 8.2
- **Test:** PHP 7.4
- **Live:** PHP 7.4
- **⚠️ Note:** Duplicate MU plugin causing WP-CLI errors (pending fix)

---

## [1.0.0] - 2026-04-20

### Added
- Initial manifest-based deployment system
- Custom theme: `phcommunity.tech`
- Deployment scripts:
  - `bin/sync-manifest.sh` - Sync from Pantheon
  - `bin/bootstrap-env.sh` - Bootstrap local environment
  - `bin/setup.sh` - First-time setup
- GitHub Actions auto-deployment on PR merge
- Environment manifest tracking (dev, test, live, multidevs)
- Documentation:
  - DEPLOYMENT.md - Deployment guide
  - WORKFLOWS.md - GitHub Actions guide
  - bin/README.md - Scripts documentation

### Environment State (2026-04-20)
- **Site:** eventsph (4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c)
- **Dev:** WordPress 6.8.3, PHP 8.2
- **Test:** PHP 7.4
- **Live:** PHP 7.4
- **⚠️ Note:** Duplicate MU plugin causing WP-CLI errors (pending fix)

### Infrastructure
- **Hosting:** Pantheon
- **CI/CD:** GitHub Actions
- **Version Control:** Git + GitHub
- **Deployment:** Manifest-based (vendor code excluded)

---

## [0.x.x] - Pre-manifest Era

### Legacy Setup
- WordPress core committed to repository
- All plugins and themes version controlled
- Manual deployments via Pantheon dashboard
- Repository size: ~305MB
- Tracked files: ~10,000+

---

## Migration Notes

### From Legacy to Manifest-Based (2026-04-20)

**What Changed:**
- Removed WP core, plugins, themes from git tracking
- Added `bin/manifest.json` for dependency management
- Created automated deployment pipeline
- Reduced git repo to only custom code

**Migration Steps Taken:**
1. Created `.gitignore` to exclude vendor code
2. Ran `git rm -r --cached .` to untrack all files
3. Re-added only custom theme and deployment tools
4. Committed ~2.8M lines of deletions
5. New repo size: 23 files (~5MB)

**Benefits:**
- 99% reduction in tracked files
- Faster git operations (clone, push, pull)
- Faster deployments (only custom code transferred)
- Clear separation of custom vs vendor code
- Environment parity via manifest
- Easy replication of environments

---

## Plugin Version History

### Major Plugin Updates

Track significant plugin updates here:

#### 2026-04-20
- **The Events Calendar:** (version TBD - pending manifest sync)
- **Jetpack:** (version TBD - pending manifest sync)
- **Wordfence:** (version TBD - pending manifest sync)

*Note: Full plugin inventory in `bin/manifest.json` after sync*

---

## Deployment History

### Production Deployments

#### 2026-04-20
- **Event:** Initial manifest-based deployment setup
- **Deployed by:** GitHub Actions
- **Commit:** c1619f4a - "removing the wp core, plugins and theme"
- **Status:** ✅ Completed
- **Notes:** Migrated to manifest-based deployment

---

## Known Issues

### Active Issues

#### Duplicate Pantheon MU Plugin (High Priority)
- **Issue:** Fatal error preventing WP-CLI access
- **Affected:** All environments
- **Cause:** Both `pantheon/` and `pantheon-mu-plugin/` directories exist
- **Fix:** See [URGENT-FIX.md](URGENT-FIX.md)
- **Status:** 🚨 Pending manual fix

### Resolved Issues

*(No resolved issues yet)*

---

## Security Updates

### 2026-04-20
- Set up GitHub Actions secrets for Pantheon authentication
- Configured workflow permissions (read-only default)
- Excluded sensitive files via `.gitignore`

---

## Performance Improvements

### 2026-04-20
- **Deployment Speed:** Reduced from ~5min to ~90sec (est.)
- **Git Clone:** Reduced from ~300MB to ~10MB
- **Repository Operations:** 100x faster due to file count reduction

---

## Breaking Changes

### v1.0.0 (2026-04-20)

⚠️ **Repository Structure Changed**

**Before:**
```
git clone → Downloads ~305MB (WP core + plugins + themes)
```

**After:**
```
git clone → Downloads ~10MB (custom code only)
./bin/bootstrap-env.sh dev → Installs WP core + plugins from manifest
```

**Impact:**
- Developers need to run `./bin/setup.sh` after cloning
- Local environments require `./bin/bootstrap-env.sh <env>` to install dependencies
- Can no longer `git pull` to update plugins (use manifest sync instead)

**Migration for Existing Developers:**
1. Pull latest changes
2. Run `./bin/setup.sh`
3. Run `./bin/bootstrap-env.sh dev`
4. Import database if needed

---

## Roadmap

### Planned Features

- [ ] Automated database sync workflow
- [ ] Automated uploads/media sync workflow
- [ ] Plugin update notifications (compare manifest to WordPress.org)
- [ ] Multi-site support in manifest
- [ ] Premium plugin handling (via private repos)
- [ ] Rollback workflow (revert to previous manifest state)
- [ ] Environment diff tool (compare dev vs test vs live)
- [ ] Slack notifications for deployments
- [ ] Deployment approval gates for live
- [ ] Performance monitoring integration

### Under Consideration

- [ ] Composer-based dependency management
- [ ] Docker local development environment
- [ ] Automated visual regression testing
- [ ] Continuous monitoring with New Relic
- [ ] CDN integration for static assets

---

## Contributors

### Core Team
- Carl Alberto ([@carl-alberto](https://github.com/carl-alberto)) - Initial setup and architecture

### Community Contributors
*(Contributors will be listed here as they contribute)*

---

## References

- [Pantheon Workflow](https://pantheon.io/docs/pantheon-workflow)
- [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)

---

**Last Updated:** 2026-04-20  
**Maintained by:** EventsPH Team
