# Script Rename Summary

**Date**: 2026-04-20

## Changes Made

### File Renamed
- **Old**: `bin/local-install.sh`
- **New**: `bin/local-install-from-manifest.sh`

### Content Updated in `bin/local-install-from-manifest.sh`

1. **Header Comment** (Line 3):
   - Old: "Local Install - Install WordPress, plugins, and themes from manifest"
   - New: "Local Install From Manifest - Install WordPress, plugins, and themes from manifest"

2. **Usage Line** (Line 8):
   - Old: `Usage: ./bin/local-install.sh [--force] [--source-env=dev] [--yes]`
   - New: `Usage: ./bin/local-install-from-manifest.sh [--force] [--source-env=dev] [--yes]`

3. **Examples Section** (Lines 16-19):
   - Updated all 4 example commands to use new script name

4. **Error Message** (Lines 26-28):
   - Updated bash requirement error to reference new script name

### Documentation Updated

1. **README.md** - 9 references updated:
   - Line 63: Repository structure diagram
   - Line 157: Quick start example
   - Line 160: Force reinstall example
   - Line 163: Sync from live example
   - Line 205: Local setup instructions
   - Line 238: Exclude note
   - Line 249: Install command
   - Line 454: Troubleshooting command
   - Line 463: Another troubleshooting command

2. **bin/save-pantheon-to-manifest.sh** - 1 reference updated:
   - Line 272: "Next steps" output message

## Why This Rename?

The new name `local-install-from-manifest.sh` is more descriptive and clearly indicates that this script:
- Installs to **local** environment
- Uses **manifest.json** as the source of truth
- Differentiates it from other potential install scripts

## How to Use

Same usage as before, just with the new name:

```bash
# Interactive sync from dev
./bin/local-install-from-manifest.sh

# Auto-confirm
./bin/local-install-from-manifest.sh --yes

# Sync from live environment
./bin/local-install-from-manifest.sh --source-env=live

# Force reinstall everything
./bin/local-install-from-manifest.sh --force
```

## Verification

All references to the old script name have been updated across:
- ✅ The script itself
- ✅ README.md (9 references)
- ✅ bin/save-pantheon-to-manifest.sh (1 reference)
- ✅ No remaining references to old name

## Git Commands

To commit these changes:

```bash
git add bin/local-install-from-manifest.sh
git add README.md
git add bin/save-pantheon-to-manifest.sh
git commit -m "Rename local-install.sh to local-install-from-manifest.sh for clarity"
```
