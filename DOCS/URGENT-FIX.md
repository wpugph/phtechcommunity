# 🚨 URGENT: Fix Duplicate MU Plugin Error

## Problem

Your Pantheon site has a **critical error** preventing it from loading:

```
Fatal error: Cannot redeclare Pantheon_Enqueue_Login_style()
(previously declared in /code/wp-content/mu-plugins/pantheon-mu-plugin/inc/pantheon-login-form-mods.php:25)
in /code/wp-content/mu-plugins/pantheon/pantheon-login-form-mods.php on line 25
```

**Cause:** Duplicate Pantheon MU plugin directories:
- `/wp-content/mu-plugins/pantheon-mu-plugin/` ✅ (newer, keep this)
- `/wp-content/mu-plugins/pantheon/` ❌ (old duplicate, DELETE this)

---

## 🔧 Fix (Choose One Method)

### Method 1: Via Pantheon Dashboard (Easiest)

1. **Go to Dashboard:**
   ```
   https://dashboard.pantheon.io/sites/4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c#dev/code
   ```

2. **Enable SFTP Mode:**
   - Click "Connection Mode" → Switch to **SFTP**

3. **Connect via SFTP:**
   - Use an SFTP client (FileZilla, Cyberduck, Transmit)
   - **Host:** `appserver.dev.4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c.drush.in`
   - **Port:** `2222`
   - **Username:** `dev.4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c`
   - **Password:** (use your Pantheon dashboard password or SSH key)

4. **Delete the duplicate:**
   - Navigate to: `code/wp-content/mu-plugins/`
   - **Delete the entire `pantheon/` directory** (NOT `pantheon-mu-plugin/`)

5. **Commit the change:**
   - In Pantheon Dashboard → Go to "Code" tab
   - You'll see uncommitted SFTP changes
   - Add commit message: "Remove duplicate Pantheon MU plugin"
   - Click "Commit"

6. **Switch back to Git mode:**
   - Connection Mode → Git

---

### Method 2: Via Command Line (Advanced)

```bash
# 1. Set to SFTP mode (already done)
terminus connection:set eventsph.dev sftp

# 2. Connect via SFTP
sftp -o Port=2222 dev.4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c@appserver.dev.4bf58ee6-abd8-47c2-a6c9-f839ae0aa50c.drush.in

# 3. Once connected, run these commands:
cd code/wp-content/mu-plugins
ls -la                           # Verify you see both 'pantheon/' and 'pantheon-mu-plugin/'
rm -rf pantheon                  # Delete the OLD duplicate
ls -la                           # Confirm only 'pantheon-mu-plugin/' remains
exit

# 4. Commit the change
terminus env:commit eventsph.dev --message="Remove duplicate Pantheon MU plugin"

# 5. Switch back to Git mode
terminus connection:set eventsph.dev git
```

---

### Method 3: Via Git (If you have local access)

If the duplicate exists in your local repo:

```bash
cd /Users/carlalberto/Local\ Sites/phtech1/app/public

# Check if duplicate exists locally
ls -la wp-content/mu-plugins/

# If you see 'pantheon/' directory, remove it
rm -rf wp-content/mu-plugins/pantheon/

# Commit and push
git add wp-content/mu-plugins/
git commit -m "Remove duplicate Pantheon MU plugin"
git push pantheon master
```

---

## ✅ Verify Fix

After removing the duplicate, test:

```bash
# Wake the environment
terminus env:wake eventsph.dev

# Test WP-CLI (should work now)
terminus wp eventsph.dev -- core version

# If this returns WordPress version without errors, you're fixed! ✅
```

---

## 📊 Then Re-Sync Manifest

Once fixed, run:

```bash
cd /Users/carlalberto/Local\ Sites/phtech1/app/public
./bin/sync-manifest.sh eventsph
```

This will populate the full manifest with all plugins, themes, and environment data.

---

## 🔍 Why This Happened

The Pantheon MU plugin was reorganized in a Pantheon update:
- **Old location:** `/mu-plugins/pantheon/` (deprecated)
- **New location:** `/mu-plugins/pantheon-mu-plugin/` (current)

Your site has both, causing function conflicts. Only keep the new one.

---

**Need help?** This is blocking your site from loading and manifest sync. Fix this first, then everything else will work.
