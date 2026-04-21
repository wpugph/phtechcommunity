# Pantheon WAF Setup

## 📋 Overview

This document explains how Wordfence and Jetpack WAF are configured to work on Pantheon's read-only filesystem.

**Reference:** [Pantheon: Symlinks and Assumed Write Access](https://docs.pantheon.io/symlinks-assumed-write-access)

---

## 🎯 The Problem

On Pantheon, the filesystem is **read-only** except for:
- `wp-content/uploads/`

However, WAF (Web Application Firewall) plugins need to write:
- **Wordfence**: Logs, rules, and config files to `wp-content/wflogs/`
- **Jetpack WAF**: Rules and logs to `wp-content/jetpack-waf/`

These directories are **outside** the writable area, causing failures on Pantheon.

---

## ✅ The Solution

### Symlink Approach

We symlink WAF directories to writable locations inside `wp-content/uploads/`:

```
wp-content/wflogs/       → wp-content/uploads/private/wordfence-waf-logs/
wp-content/jetpack-waf/  → wp-content/uploads/private/jetpack-waf/
```

This is handled automatically by the **MU plugin**: `wp-content/mu-plugins/pantheon-waf-setup.php`

---

## 🔧 How It Works

### 1. MU Plugin (Auto-Setup)

The MU plugin (`pantheon-waf-setup.php`) runs on every request and:

1. **Detects Pantheon environment** (via `$_ENV['PANTHEON_ENVIRONMENT']`)
2. **Creates target directories** in `uploads/private/`
3. **Migrates existing files** (if directories already exist)
4. **Creates symlinks** from `wp-content/wflogs/` → `uploads/private/...`

**Note:** Pantheon uses nginx (not Apache), so `.htaccess` files are not used. The `uploads/private/` directory is automatically protected by Pantheon's nginx configuration.

### 2. Directory Structure

**On Pantheon (after setup):**
```
wp-content/
├── uploads/
│   └── private/                    ← Protected by Pantheon's nginx config
│       ├── wordfence-waf-logs/    ← Actual files here (writable)
│       │   ├── config.php
│       │   ├── rules.php
│       │   └── ...
│       └── jetpack-waf/            ← Actual files here (writable)
│           └── rules/
├── wflogs/                         ← Symlink →  ../uploads/private/wordfence-waf-logs/
└── jetpack-waf/                    ← Symlink →  ../uploads/private/jetpack-waf/
```

**On Local (development):**
```
wp-content/
├── wflogs/         ← Real directory (git ignored)
└── jetpack-waf/    ← Real directory (git ignored)
```

Local development doesn't need symlinks since the filesystem is fully writable.

---

## 🚀 Deployment Process

### First-Time Setup on Pantheon

When you first deploy to Pantheon:

1. **MU plugin deploys** via Git push
2. **First request triggers** the MU plugin
3. **Symlinks are created** automatically
4. **WAF plugins activate** and write to symlinked locations
5. **Files end up** in `uploads/private/`

### Subsequent Deployments

- Symlinks persist (not affected by code deploys)
- WAF data persists in `uploads/` (not overwritten)
- MU plugin re-checks symlinks on each init

---

## 🛡️ Security

### Protected Directories

Both WAF directories are stored in `uploads/private/`, which is automatically protected by **Pantheon's nginx configuration**.

**How Pantheon Protects `/private/`:**
- Pantheon uses **nginx** (not Apache), so `.htaccess` files don't work
- Nginx is configured to **deny direct HTTP access** to any `/private/` directory
- Files are still readable by PHP/WordPress but not accessible via browser

This prevents:
- Direct browser access to config files
- Exposure of firewall rules
- Access to logs and attack data

### Private Location

Files are stored in `uploads/private/` specifically (not just `uploads/`):
- More secure than public uploads
- Not indexed by search engines
- Protected by Pantheon's nginx configuration
- Still writable by WordPress (bypasses read-only filesystem)

---

## 📝 Configuration

### Wordfence

The MU plugin sets the Wordfence log path:

```php
define('WFWAF_LOG_PATH', $uploads['basedir'] . '/private/wordfence-waf-logs/');
```

This tells Wordfence where to write its files.

### Jetpack WAF

Jetpack WAF automatically follows the `wp-content/jetpack-waf/` directory, which is symlinked to the writable location.

---

## 🧪 Testing

### Verify Setup on Pantheon

SSH into your Pantheon environment:

```bash
# Connect to dev environment
terminus ssh eventsph.dev

# Check symlinks
ls -la web/wp-content/ | grep -E "wflogs|jetpack"

# Should show:
# lrwxr-xr-x  wflogs -> ../uploads/private/wordfence-waf-logs
# lrwxr-xr-x  jetpack-waf -> ../uploads/private/jetpack-waf

# Verify target directories exist
ls -la web/wp-content/uploads/private/

# Check Wordfence logs are writing
ls -la web/wp-content/wflogs/
```

### Verify Wordfence is Working

1. Go to: **Wordfence** → **Dashboard**
2. Check: **Firewall Status**
   - Should show: "Learning Mode" or "Enabled"
   - Should NOT show: "Cannot write to wflogs/"

3. Check: **Scan Status**
   - Run a scan
   - Should complete without errors

### Verify Jetpack WAF is Working

1. Go to: **Jetpack** → **Protect**
2. Check: **Firewall Status**
   - Should show: "Active" or "Running"
   - Should NOT show: Permission errors

---

## 🔍 Troubleshooting

### Issue: "Cannot write to wflogs directory"

**Cause:** Symlink not created or pointing to wrong location

**Solution:**
```bash
# SSH to Pantheon
terminus ssh eventsph.dev

# Check if symlink exists
ls -la web/wp-content/wflogs

# Remove broken symlink (if needed)
rm -f web/wp-content/wflogs

# The MU plugin will recreate it on next request
# Or create manually:
ln -s ../uploads/private/wordfence-waf-logs web/wp-content/wflogs
```

### Issue: "Permission denied" errors

**Cause:** Target directory doesn't exist in uploads/private/

**Solution:**
```bash
# SSH to Pantheon
terminus ssh eventsph.dev

# Create target directories (Pantheon automatically makes them writable)
mkdir -p web/wp-content/uploads/private/wordfence-waf-logs
mkdir -p web/wp-content/uploads/private/jetpack-waf

# Permissions are handled automatically by Pantheon for uploads/ directory
```

### Issue: MU plugin not running

**Cause:** Plugin not deployed or disabled

**Solution:**
```bash
# Verify MU plugin exists
terminus ssh eventsph.dev
ls -la web/wp-content/mu-plugins/pantheon-waf-setup.php

# If missing, redeploy:
git push pantheon master
```

### Issue: Symlinks work on dev but not test/live

**Cause:** Code deploy doesn't preserve symlinks

**Solution:**
- Symlinks are created automatically by MU plugin
- Just trigger a request on test/live
- Visit the site homepage after deployment

---

## 📦 Git Tracking

These directories are **excluded** from Git (in `.gitignore`):

```gitignore
wp-content/wflogs/
wp-content/jetpack-waf/
```

**Why:**
- WAF logs and configs are environment-specific
- Can be large (GeoIP database ~10MB)
- Contain sensitive security data
- Auto-generated by plugins

**What IS tracked:**
- ✅ `wp-content/mu-plugins/pantheon-waf-setup.php` - The setup script
- ❌ `wp-content/wflogs/` - Generated files
- ❌ `wp-content/jetpack-waf/` - Generated files

---

## 🔄 Backup & Restore

### Backing Up WAF Data

WAF data is stored in `wp-content/uploads/`, which is backed up by Pantheon automatically.

To manually backup:

```bash
# Create backup
terminus backup:create eventsph.dev --element=files

# Download backup
terminus backup:get eventsph.dev --element=files --to=~/Downloads/

# Extract and find WAF data
tar -xzf ~/Downloads/files_*.tar.gz
cd wp-content/uploads/private/
```

### Restoring WAF Data

WAF data doesn't usually need manual restoration:
- Wordfence downloads rules automatically
- Jetpack WAF syncs rules from WordPress.com

If you need to restore:

```bash
# Upload to environment
terminus rsync ~/local-waf-backup/ eventsph.dev:files/private/wordfence-waf-logs/
```

---

## 🚨 Important Notes

1. **Local vs Pantheon:**
   - Local: Real directories (no symlinks needed)
   - Pantheon: Symlinks to `uploads/private/`

2. **MU Plugin Always Runs:**
   - Checks symlinks on every `init` hook
   - Low performance impact (simple file_exists checks)
   - Can be disabled locally with: `define('PANTHEON_WAF_SETUP_FORCE', false);`

3. **Force Local Symlinks (Optional):**
   - Add to `wp-config-local.php`:
   ```php
   define('PANTHEON_WAF_SETUP_FORCE', true);
   ```

4. **Private Directory Protection:**
   - Pantheon uses nginx, not Apache (`.htaccess` doesn't work)
   - `/uploads/private/` is protected by Pantheon's nginx config
   - Test by trying to access: `https://your-site.pantheonsite.io/wp-content/uploads/private/wordfence-waf-logs/config.php` (should get 403 Forbidden)

5. **Pantheon Caching:**
   - WAF rules are cached by Pantheon's edge
   - Changes may take 5-10 minutes to propagate
   - Clear cache: `terminus env:clear-cache eventsph.dev`

---

## 📚 References

- [Pantheon: Symlinks and Assumed Write Access](https://docs.pantheon.io/symlinks-assumed-write-access)
- [Pantheon: WordPress Known Issues](https://docs.pantheon.io/wordpress-known-issues)
- [Wordfence: Installation Guide](https://www.wordfence.com/help/firewall/installation/)
- [Jetpack Protect Documentation](https://jetpack.com/support/protect/)

---

## ✅ Checklist

- [ ] MU plugin deployed: `wp-content/mu-plugins/pantheon-waf-setup.php`
- [ ] `.gitignore` excludes WAF directories
- [ ] Symlinks created on Pantheon dev
- [ ] Wordfence dashboard shows no errors
- [ ] Jetpack WAF shows as active
- [ ] WAF logs are writing to `uploads/private/`
- [ ] Private directory protection verified (403 Forbidden on direct access)
- [ ] Test/Live environments setup (after deployment)

---

Last Updated: 2026-04-21
