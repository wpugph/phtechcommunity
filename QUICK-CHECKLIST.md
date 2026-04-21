# Quick Migration Checklist

## Before You Start
- [ ] Read `FORMIDABLE-STEP-BY-STEP-GUIDE.md`
- [ ] Open WordPress Admin: http://phtech1.local/wp-admin
- [ ] Have `community-email-mapping.csv` open for reference

---

## Create Form (20 mins)

- [ ] **Step 1**: Formidable → Forms → Add New
- [ ] **Step 2**: Name it "Contact Us"
- [ ] **Step 3**: Add "Full Name" (text, required)
- [ ] **Step 4**: Add "Email Address" (email, required)
- [ ] **Step 5**: Add "Choose a Community" (dropdown, required)
  - [ ] Click "Bulk Edit Options"
  - [ ] Paste all 24 communities from guide
  - [ ] Note the Field ID for this dropdown: ______
- [ ] **Step 6**: Add "Comments / Questions" (paragraph, required)
- [ ] **Step 7**: Enable Honeypot spam protection
- [ ] **Step 8**: Change submit button text to "Send Message"
- [ ] **Step 9**: Set success message: "Form has been successfully submitted. Thank you."
- [ ] **Step 10**: Click "Update" to save form
- [ ] Note your Form ID: ______

---

## Set Up Email Routing (15 mins)

**Choose ONE method:**

### Option A: PHP Code (Recommended)
- [ ] Run: `./get-formidable-ids.sh` to get Form ID and Field ID
- [ ] Go to: Appearance → Theme File Editor
- [ ] Open: functions.php
- [ ] Scroll to bottom
- [ ] Copy code from `formidable-email-routing.php`
- [ ] Update `YOUR_FORM_ID_HERE` with your Form ID
- [ ] Update `YOUR_FIELD_ID_HERE` with your Community dropdown Field ID
- [ ] Click "Update File"

### Option B: Manual Email Actions (Takes longer)
- [ ] Create 24 separate email actions in Settings → Actions & Notifications
- [ ] Each action: different email + condition for each community
- [ ] Use `community-email-mapping.csv` for email addresses

---

## Update Contact Page (2 mins)

- [ ] Run: `./get-formidable-ids.sh` to see your Form ID
- [ ] Update page: `wp post update 80 --post_content='[formidable id=X]' --allow-root`
  - Replace X with your actual Form ID

**OR via Admin:**
- [ ] Pages → All Pages → Edit "Contact Us"
- [ ] Replace `[caldera_form id="CF5a6b15c166d59"]` with `[formidable id=X]`
- [ ] Click Update

---

## Test Everything (10 mins)

- [ ] Visit: http://phtech1.local/contact-us/
- [ ] Form displays correctly
- [ ] Test required fields (try submitting blank form)
- [ ] All 24 communities in dropdown
- [ ] Submit test #1: AWS Usergroup → check core@awsug.ph gets email
- [ ] Submit test #2: WordPress WPUGPH → check jpalmes@gmail.com gets email
- [ ] Submit test #3: * WEBSITE ADMIN * → check avgarcia.contact@gmail.com gets email
- [ ] Success message displays after submit
- [ ] Check Formidable → Entries (should see your test submissions)

---

## Clean Up (1 min)

- [ ] All tests passed ✅
- [ ] Deactivate Caldera: `wp plugin deactivate caldera-forms caldera-forms-anti-spam --allow-root`
- [ ] Visit contact page one more time to confirm it still works
- [ ] Done! ✅

---

## Helper Commands

```bash
# Get Form and Field IDs
./get-formidable-ids.sh

# Update Contact page (replace X with form ID)
wp post update 80 --post_content='[formidable id=X]' --allow-root

# Check current page content
wp post get 80 --field=post_content --allow-root

# View Contact page URL
wp post get 80 --field=url --allow-root

# Deactivate Caldera
wp plugin deactivate caldera-forms caldera-forms-anti-spam --allow-root

# Reactivate Caldera (if you need to rollback)
wp plugin activate caldera-forms caldera-forms-anti-spam --allow-root
```

---

## Quick Reference

| Item | Value |
|------|-------|
| Admin URL | http://phtech1.local/wp-admin |
| Contact Page | http://phtech1.local/contact-us/ |
| Formidable Menu | Formidable → Forms |
| Total Communities | 24 |
| Email Mapping | See community-email-mapping.csv |
| Old Shortcode | [caldera_form id="CF5a6b15c166d59"] |
| New Shortcode | [formidable id=?] |
| Form ID | Fill in after creation: ______ |
| Dropdown Field ID | Fill in after creation: ______ |

---

## Troubleshooting

**Can't find Form ID?**
→ Run `./get-formidable-ids.sh`

**Emails not sending?**
→ Check spam folder
→ Verify email routing code has correct Form ID and Field ID
→ Test with your own email first

**Form doesn't show on page?**
→ Check shortcode is correct
→ Clear cache
→ Make sure Formidable is active

**Need help?**
→ Read full guide: `FORMIDABLE-STEP-BY-STEP-GUIDE.md`

---

## Estimated Time

- Create Form: 20 minutes
- Email Routing: 15 minutes (PHP) or 45 minutes (manual)
- Update Page: 2 minutes
- Testing: 10 minutes

**Total: 45-90 minutes**
