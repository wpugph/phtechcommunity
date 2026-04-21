# PHP 8.5 Upgrade Compatibility Report

**Date**: 2026-04-20  
**Issue**: https://github.com/wpugph/phtechcommunity/issues/37  
**Current PHP**: 7.4.30  
**Target PHP**: 8.5 (Note: Likely means PHP 8.3 or 8.4 - PHP 8.5 doesn't exist)  
**WordPress**: 6.8.3 → Should update to 6.9.4

---

## ⚠️ CRITICAL FINDINGS

### 🚨 SHOW STOPPERS - Will Break on PHP 8.0+

#### 1. Caldera Forms v1.9.4 - **MUST REPLACE**

**Status**: ABANDONED (last update ~2019)  
**PHP 8.x Compatibility**: ❌ **WILL BREAK**

**Code Issues Found:**
- ✗ `create_function()` usage: **3 instances** (REMOVED in PHP 8.0)
- ⚠ `extract()` usage: **7 files** (Risky, not removed but discouraged)

**Impact**: Forms will break completely on PHP 8.0+

**Solution**: 
```bash
# BEFORE upgrading PHP:
# 1. Export all Caldera form data
wp caldera-forms export --allow-root

# 2. Install replacement (choose one)
wp plugin install wpforms-lite --activate --allow-root
# OR
wp plugin install gravityforms --activate --allow-root  # (premium)

# 3. Manually recreate forms in new plugin
# 4. Test thoroughly
# 5. Deactivate Caldera Forms
wp plugin deactivate caldera-forms --allow-root
```

---

## 🟡 HIGH RISK - Likely Issues

### 2. Ninja Forms v3.2.16
- **Current**: 3.2.16 (2018)  
- **Latest**: 3.14.2  
- **Status**: Very outdated (6+ years old)
- **Found**: Multiple `extract()` uses
- **Action**: Update to 3.14.2 OR deactivate (currently inactive)

### 3. Google Analytics (MonsterInsights) v8.15
- **Current**: 8.15  
- **Latest**: 10.1.2  
- **Gap**: 2+ major versions behind
- **Action**: Update to 10.x before PHP upgrade

### 4. Theme My Login v7.1.5
- **Current**: 7.1.5  
- **Latest**: 7.1.14
- **Found**: `extract()` usage
- **Action**: Update to 7.1.14 and test thoroughly

### 5. Cactus Companion v1.0.6 (Custom Plugin)
- **Status**: Custom/proprietary
- **Found**: `extract()` in 5+ files
- **Action**: Code review and update required

---

## 🟠 MEDIUM RISK - Major Updates Required

### 6. Elementor v3.13.4 → 4.0.3
- **Gap**: Major version change (3.x → 4.x)
- **Risk**: Template breaking changes possible
- **Action**: 
  ```bash
  # Update in stages
  wp plugin update elementor --allow-root
  # Test all Elementor-built pages
  ```

### 7. Jetpack v12.1.1 → 15.7.1
- **Gap**: 3+ major versions
- **Risk**: Feature deprecations, API changes
- **Action**: Update before PHP upgrade

### 8. The Events Calendar v6.0.13.1 → 6.15.20
- **Gap**: Multiple point releases
- **Action**: Update to latest

### 9. WP Optimize v3.2.15 → 4.5.1
- **Gap**: Major version behind
- **Action**: Update to 4.x

### 10. Wordfence v7.9.2 → 8.1.4
- **Gap**: Major version behind
- **Risk**: Security features may break
- **Action**: Update to 8.x

---

## ✅ LOW RISK - Should Work

- Advanced Access Manager v7.1.0 ✓
- Astra Theme v4.1.5 ✓ (update to 4.13.0 recommended)
- Autoptimize v3.1.15.1 ✓
- Jetpack (after update) ✓

---

## PHP 7.4 → 8.x Breaking Changes Detected

| Issue | Severity | Affected Plugins | Impact |
|-------|----------|------------------|---------|
| `create_function()` removed | 🚨 CRITICAL | Caldera Forms (3×) | Complete breakage |
| `extract()` usage | 🟡 MEDIUM | Caldera, Ninja Forms, Theme My Login, Cactus | Security risk, possible issues |
| Outdated code patterns | 🟠 MEDIUM | Multiple plugins | Various failures possible |

---

## Step-by-Step Upgrade Plan

### ✅ Phase 1: Pre-Flight (Do Now)

1. **Full Backup**
   ```bash
   # Database backup
   wp db export backup-before-php8-$(date +%Y%m%d).sql --allow-root
   
   # File backup (optional but recommended)
   cd /Users/carlalberto/Local\ Sites/phtech1/app
   tar -czf backup-files-$(date +%Y%m%d).tar.gz public/
   ```

2. **Update WordPress Core**
   ```bash
   wp core update --version=6.9.4 --allow-root
   wp core update-db --allow-root
   ```

3. **Check PHP Compatibility**
   ```bash
   # Already installed: php-compatibility-checker
   # Go to WP Admin > Tools > PHP Compatibility
   # Select PHP 8.3 and run scan
   ```

### ⚠️ Phase 2: Critical Plugin Migration (REQUIRED)

4. **Replace Caldera Forms** (CANNOT be skipped)
   ```bash
   # Export forms first
   # Document all form configurations
   # Take screenshots of each form
   
   # Install WPForms
   wp plugin install wpforms-lite --activate --allow-root
   
   # Manually recreate forms
   # Test each form submission
   # Update form embed codes on pages
   
   # Only after testing:
   wp plugin deactivate caldera-forms caldera-forms-anti-spam --allow-root
   ```

### 🔄 Phase 3: Plugin Updates

5. **Update All Plugins to Latest**
   ```bash
   # Update low-risk plugins first
   wp plugin update akismet advanced-custom-fields wordfence --allow-root
   
   # Update medium-risk plugins one by one
   wp plugin update elementor --allow-root
   # Test site after each
   
   wp plugin update jetpack --allow-root
   # Test site
   
   wp plugin update the-events-calendar --allow-root
   # Test events functionality
   
   wp plugin update google-analytics-for-wordpress --allow-root
   wp plugin update theme-my-login --allow-root
   wp plugin update wp-optimize --allow-root
   ```

6. **Update Theme**
   ```bash
   wp theme update astra --allow-root
   ```

### 🧪 Phase 4: PHP Version Testing

7. **Test with PHP 8.1 First** (Safest approach)
   - In Local by Flywheel: Site > PHP Version > 8.1
   - Test all functionality (see checklist below)
   - Check error log: `/Users/carlalberto/Local Sites/phtech1/app/logs/php/error.log`

8. **Then Test PHP 8.3**
   - Change to PHP 8.3
   - Repeat all tests
   - Monitor error logs

9. **Finally PHP 8.4** (if available and needed)

### ✅ Phase 5: Testing Checklist

- [ ] Homepage loads without errors
- [ ] Admin dashboard accessible
- [ ] **Forms submit correctly** (CRITICAL - test new WPForms)
- [ ] Events calendar displays
- [ ] Event creation/editing works
- [ ] User login/logout works
- [ ] User registration works (Theme My Login)
- [ ] Elementor editor loads
- [ ] Edit pages with Elementor
- [ ] Jetpack features work (if used)
- [ ] Analytics tracking works
- [ ] Image optimization works (Imagify)
- [ ] Security features active (Wordfence/Cerber)
- [ ] No PHP errors in error log
- [ ] No JavaScript console errors
- [ ] Permalinks work
- [ ] Search functions properly

---

## Error Monitoring Commands

```bash
# Watch error log in real-time during testing
tail -f /Users/carlalberto/Local\ Sites/phtech1/app/logs/php/error.log

# Check for fatal errors
grep -i "fatal\|error" /Users/carlalberto/Local\ Sites/phtech1/app/logs/php/error.log | tail -20

# Check for deprecated warnings
grep -i "deprecated" /Users/carlalberto/Local\ Sites/phtech1/app/logs/php/error.log | tail -20

# Clear error log before testing
> /Users/carlalberto/Local\ Sites/phtech1/app/logs/php/error.log
```

---

## Rollback Plan (If Things Break)

```bash
# Rollback PHP version in Local by Flywheel:
# Site > PHP Version > 7.4

# Restore database if needed:
wp db import backup-before-php8-YYYYMMDD.sql --allow-root

# Restore files if needed:
cd /Users/carlalberto/Local\ Sites/phtech1/app
tar -xzf backup-files-YYYYMMDD.tar.gz
```

---

## Custom Plugin Code Review Needed

These plugins need manual code review for PHP 8 compatibility:

1. **Cactus Companion** (v1.0.6)
   - Location: `wp-content/plugins/cactus-companion/`
   - Issues: Multiple `extract()` uses
   - Action: Review and update code

2. **Re-Welcome** (v1.0)
   - Location: `wp-content/plugins/re-welcome/`
   - Action: Check for deprecated functions

3. **PHCommunity.tech Theme** (v1.0.0)
   - Location: `wp-content/themes/phcommunity.tech/`
   - Status: Currently inactive
   - Action: Code review if planning to use

---

## Estimated Timeline

- **Phase 1 (Backup & Core Update)**: 30 minutes
- **Phase 2 (Caldera Forms Migration)**: 4-8 hours (depending on form complexity)
- **Phase 3 (Plugin Updates)**: 1-2 hours
- **Phase 4 (PHP Testing)**: 2-4 hours
- **Phase 5 (Thorough Testing)**: 4-8 hours

**Total**: 2-3 days for safe migration

---

## Risk Summary

| Risk Level | Action | Can Skip? |
|------------|--------|-----------|
| 🚨 Caldera Forms | Replace | ❌ NO - Will break |
| 🟡 Plugin Updates | Update all | ❌ NO - Required |
| 🟠 Custom Plugins | Code review | ⚠️ Depends on usage |
| ✅ WP Core Update | Update | ❌ NO - Required |
| 🧪 Staging Test | Test thoroughly | ⚠️ Highly recommended |

---

## Next Steps - What to Do Now

1. ✅ Review this report
2. ⏰ Schedule maintenance window (2-3 days)
3. 📋 Start with Phase 1 (backups)
4. 🔴 Priority: Begin Caldera Forms migration planning
5. 📊 Run PHP Compatibility scan in WP Admin
6. 👥 Inform stakeholders of the migration timeline

---

## Questions?

- Which forms are using Caldera Forms? (Need to document before migration)
- Is the PHCommunity.tech custom theme actively used?
- Are all Elementor pages documented?
- Is there a staging environment available for testing?

