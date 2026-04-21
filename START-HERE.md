# 🚀 Caldera to Formidable Migration - START HERE

## What You Need to Do

Migrate your "Contact Us" form from Caldera Forms (broken on PHP 8) to Formidable Forms.

---

## 📚 Files Created for You

1. **QUICK-CHECKLIST.md** ← **START WITH THIS**
   - Simple checklist with checkboxes
   - Quick reference for the entire process
   
2. **FORMIDABLE-STEP-BY-STEP-GUIDE.md**
   - Detailed walkthrough with screenshots references
   - Complete instructions for every step
   
3. **community-list.txt**
   - Copy-paste ready list of 24 communities
   - Use this when creating the dropdown field
   
4. **community-email-mapping.csv**
   - Reference table: Which community → which email
   
5. **formidable-email-routing.php**
   - PHP code for automatic email routing
   - Copy to functions.php after getting Form ID
   
6. **get-formidable-ids.sh**
   - Helper script to find your Form ID and Field IDs
   - Run: `./get-formidable-ids.sh`

---

## 🎯 Quick Start (3 Steps)

### Step 1: Create the Form (20 mins)
```
1. Go to: http://phtech1.local/wp-admin
2. Click: Formidable → Forms → Add New
3. Follow: FORMIDABLE-STEP-BY-STEP-GUIDE.md (Steps 1-10)
   OR use: QUICK-CHECKLIST.md
```

### Step 2: Set Up Email Routing (15 mins)
```
1. Run: ./get-formidable-ids.sh
2. Note your Form ID and Community Field ID
3. Add PHP code from formidable-email-routing.php to functions.php
4. Update the Form ID and Field ID in the code
```

### Step 3: Update Contact Page (2 mins)
```
# Get your form ID first
./get-formidable-ids.sh

# Update page (replace X with your form ID)
wp post update 80 --post_content='[formidable id=X]' --allow-root

# Test at: http://phtech1.local/contact-us/
```

---

## 📋 Current Form Details

**Caldera Form "Contact Us":**
- Full Name (text, required)
- Email Address (email, required)
- Choose a Community (dropdown, 24 options, required)
- Comments / Questions (textarea, required)
- ReCAPTCHA/Spam protection
- Emails route to 24 different addresses based on community selection

**Used on:** Contact Us page (http://phtech1.local/contact-us/)

---

## ⏱️ Time Estimate

- Read guides: 10 mins
- Create form: 20 mins
- Email routing: 15 mins (PHP) or 45 mins (manual)
- Test & deploy: 10 mins

**Total: 55 minutes** (using PHP routing)

---

## 🆘 Need Help?

1. **Can't find Form ID?** → Run `./get-formidable-ids.sh`
2. **Community list?** → Open `community-list.txt` (copy-paste ready)
3. **Email addresses?** → See `community-email-mapping.csv`
4. **Step-by-step?** → Read `FORMIDABLE-STEP-BY-STEP-GUIDE.md`
5. **Quick reference?** → Use `QUICK-CHECKLIST.md`

---

## ✅ When You're Done

```bash
# Deactivate Caldera Forms
wp plugin deactivate caldera-forms caldera-forms-anti-spam --allow-root

# You're now ready for PHP 8 upgrade! 🎉
```

---

## 📁 All Your Files

```
START-HERE.md                          ← You are here
QUICK-CHECKLIST.md                     ← Use this as your guide
FORMIDABLE-STEP-BY-STEP-GUIDE.md      ← Detailed instructions
community-list.txt                     ← 24 communities (copy-paste)
community-email-mapping.csv            ← Community → Email reference
formidable-email-routing.php          ← PHP routing code
get-formidable-ids.sh                 ← Helper script
caldera-form-backup.json              ← Your backup (don't delete)
caldera-entries-backup.txt            ← Entry backup (don't delete)
CALDERA-TO-FORMIDABLE-MIGRATION.md    ← Technical overview
```

---

## 🚦 Ready?

**Recommended path:**
1. Open `QUICK-CHECKLIST.md` in one window
2. Open `http://phtech1.local/wp-admin` in browser
3. Follow the checklist step by step
4. Use `community-list.txt` when you need to add dropdown options
5. Run `./get-formidable-ids.sh` when you need IDs

**Let's go! 🚀**
