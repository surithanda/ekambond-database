# Database Quick Start Guide

## For Data Engineers & Developers

This guide helps you quickly understand and work with the matrimony services database.

---

## 1. Database Setup

### Prerequisites
- MySQL 5.7+ or MariaDB 10.3+
- Database user with CREATE, INSERT, UPDATE, DELETE, EXECUTE privileges

### Initial Setup
```bash
# Navigate to database folder
cd database/

# Run setup script (Windows)
.\setup-database.ps1

# Or manually execute in order:
# 1. Create tables (in order - lookup and reference data first)
# 2. Load data scripts
# 3. Create stored procedures
```

### Load Order
1. `tables/04 lookup_table.sql`
2. `tables/countries.sql`
3. `tables/state.sql`
4. `tables/zip_code.sql`
5. `tables/00 activity_log.sql`
6. `tables/01 account.sql`
7. `tables/02 login.sql`
8. All other tables (can be loaded in any order)
9. All stored procedures from `procedures/`

---

## 2. Understanding the Data Model

### Core Entities

```
USER ACCOUNT
    ↓
PROFILE (Personal, Education, Employment, Photos, etc.)
    ↓
INTERACTIONS (Views, Favorites, Contacts, Saved)
    ↓
SUBSCRIPTIONS (Stripe Payment Data)
```

### Key Relationships

```plaintext
account (1) ─────── (1) login
   │
   ├─── (1) profile_personal
   │         ├─── (many) education
   │         ├─── (many) employment
   │         ├─── (many) photos
   │         └─── (many) addresses
   │
   └─── (1) stripe_customers
             └─── (many) stripe_subscriptions
```

### Self-Referencing Tables (Many-to-Many)
- **profile_views**: Profile A views Profile B
- **profile_favorites**: Profile A favorites Profile B
- **profile_contacted**: Profile A contacts Profile B
- **profile_saved_for_later**: Profile A saves Profile B

---

## 3. Common Operations

### A. User Registration

```sql
-- Create account and login
CALL eb_account_login_create(
    'john.doe@example.com',           -- email
    'hashed_password_here',           -- password (hash in app)
    'John',                           -- first_name
    'M',                              -- middle_name (optional)
    'Doe',                            -- last_name
    '1990-05-15',                     -- birth_date (must be 20+ years old)
    1,                                -- gender (1=Male, 2=Female)
    '5551234567',                     -- primary_phone
    '+1',                             -- primary_phone_country
    1,                                -- primary_phone_type (from lookup)
    NULL, NULL, NULL,                 -- secondary phone (optional)
    '123 Main Street',                -- address_line1
    'Apt 4B',                         -- address_line2 (optional)
    'New York',                       -- city
    'NY',                             -- state
    '10001',                          -- zip
    'USA',                            -- country
    NULL,                             -- photo (optional)
    NULL, NULL                        -- secret_question/answer (optional)
);

-- Response includes account_id and account_code
```

### B. Create Profile

```sql
-- Create personal profile
CALL eb_profile_personal_create(
    @account_id,                      -- from registration
    'John', 'Doe', 'M',               -- names
    'Mr.', NULL,                      -- prefix, suffix
    1,                                -- gender
    '1990-05-15',                     -- birth_date (21-85 years)
    '5551234567',                     -- phone_mobile
    NULL, NULL,                       -- phone_home, phone_emergency
    'john.doe@example.com',           -- email_id
    1,                                -- marital_status (from lookup)
    1,                                -- religion (from lookup)
    1,                                -- nationality (from lookup)
    NULL,                             -- caste (optional)
    72.00, 182.88,                    -- height_inches, height_cms
    180.00, 'lbs',                    -- weight, weight_units
    NULL,                             -- complexion (optional)
    'linkedin.com/in/johndoe',        -- linkedin
    'facebook.com/johndoe',           -- facebook
    'instagram.com/johndoe',          -- instagram
    '+15551234567',                   -- whatsapp_number
    1,                                -- profession (from lookup)
    NULL,                             -- disability (optional)
    'john.doe@example.com'            -- created_user
);

-- Add education
CALL eb_profile_education_create(
    @profile_id,
    5,                                -- education_level (Bachelor's)
    2015,                             -- year_completed
    'State University',               -- institution_name
    '789 Campus Dr',                  -- address_line1
    'College Town',                   -- city
    25,                               -- state_id
    1,                                -- country_id
    '12345',                          -- zip
    3,                                -- field_of_study (Computer Science)
    'john.doe@example.com'            -- user_created
);

-- Add employment
CALL eb_profile_employment_create(
    @profile_id,
    'Tech Corp Inc',                  -- institution_name
    '456 Business Blvd',              -- address_line1
    'San Francisco',                  -- city
    5,                                -- state_id
    1,                                -- country_id
    '94105',                          -- zip
    2018,                             -- start_year
    NULL,                             -- end_year (current job)
    15,                               -- job_title_id (Software Engineer)
    NULL,                             -- other_title
    95000.00,                         -- last_salary_drawn
    'john.doe@example.com'            -- user_created
);

-- Upload photo
CALL eb_profile_photo_create(
    @profile_id,
    1,                                -- photo_type (1=Headshot)
    'Professional headshot',          -- description
    'My profile photo',               -- caption
    '/uploads/profiles/123/',         -- relative_path
    'https://cdn.example.com/photo.jpg', -- url
    'john.doe@example.com'            -- user_created
);
```

### C. Search for Matches

```sql
-- First, set search preferences
CALL eb_profile_search_preference_create(
    @profile_id,
    25,                               -- min_age
    35,                               -- max_age
    1,                                -- religion (same as user)
    5,                                -- max_education (Bachelor's+)
    NULL,                             -- occupation (any)
    'USA',                            -- country
    NULL,                             -- casete_id (any)
    1,                                -- marital_status (Single)
    2                                 -- gender (Female)
);

-- Search using saved preferences
CALL eb_profile_search_get(
    @profile_id,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
);

-- Override specific criteria (age 28-33, ignore religion)
CALL eb_profile_search_get(
    @profile_id,
    28,                               -- min_age (override)
    33,                               -- max_age (override)
    -1,                               -- religion (ignore filter)
    NULL,                             -- max_education (use saved)
    NULL,                             -- occupation (use saved)
    NULL,                             -- country (use saved)
    NULL,                             -- casete_id (use saved)
    NULL                              -- marital_status (use saved)
);
```

### D. Profile Interactions

```sql
-- Record profile view
CALL eb_profile_views_create(
    @my_profile_id,                   -- from_profile_id (viewer)
    @other_profile_id,                -- to_profile_id (viewed)
    @my_account_id                    -- account_id
);

-- Add to favorites
CALL eb_profile_favorites_create(
    @my_profile_id,
    @other_profile_id,
    @my_account_id
);

-- Record contact
CALL eb_profile_contacted_create(
    @my_profile_id,
    @other_profile_id,
    'email',                          -- contact_method
    'Sent introduction email',        -- contact_notes
    @my_account_id,
    'john.doe@example.com'            -- created_user
);

-- Save for later
CALL eb_profile_saved_for_later_create(
    @my_profile_id,
    @other_profile_id,
    'Interesting profile, review later', -- notes
    @my_account_id,
    'john.doe@example.com'
);

-- Get who viewed my profile
CALL eb_profile_views_get_viewed_me(@my_profile_id);

-- Get profiles I viewed
CALL eb_profile_views_get_viewed_by_me(@my_profile_id);

-- Get my favorites
CALL eb_profile_favorites_get(@my_profile_id);
```

### E. Get Complete Profile Data

```sql
-- Get all profile information in one call
CALL eb_profile_get_complete_data(@profile_id);

-- Returns:
-- - Personal information
-- - All addresses
-- - All education records
-- - All employment records
-- - All family references
-- - All photos
-- - All hobbies
-- - Lifestyle preferences
-- - Property information
```

### F. Lookup Data

```sql
-- Get all lookup categories
CALL lkp_get_LookupData('Gender');
CALL lkp_get_LookupData('MaritalStatus');
CALL lkp_get_LookupData('Religion');
CALL lkp_get_LookupData('Education');
CALL lkp_get_LookupData('Occupation');

-- Get countries
CALL lkp_get_Country_List();

-- Get states for a country
CALL lkp_get_Country_States(@country_id);
```

---

## 4. Error Handling

### Understanding Error Codes

```plaintext
Error Code Format: NNNNN_DESCRIPTION
Examples:
- 45001_MISSING_EMAIL
- 46009_INVALID_AGE
- 58006_DUPLICATE_FAVORITE
```

### Error Code Ranges
- **45000-45999**: Account/Login errors
- **46000-46999**: Profile Personal creation errors
- **48000-48999**: Partner registration errors
- **50000-50999**: Profile Personal errors
- **51000-64999**: Profile component errors (1000 per component)

### Handling Errors in Application

```javascript
// Example in Node.js/TypeScript
const [result] = await connection.query(
    'CALL eb_account_login_create(?, ?, ...)', 
    [email, password, ...]
);

if (result[0].status === 'fail') {
    console.error(`Error: ${result[0].error_code}`);
    console.error(`Message: ${result[0].error_message}`);
    
    // Display user-friendly message based on error_code
    switch(result[0].error_code) {
        case '45005_DUPLICATE_EMAIL':
            return 'This email is already registered';
        case '45008_UNDERAGE':
            return 'You must be at least 20 years old';
        default:
            return result[0].error_message;
    }
}

// Success
const accountId = result[0].account_id;
const accountCode = result[0].account_code;
```

---

## 5. Partner Integration

### Register Partner

```sql
CALL eb_registered_partner_create(
    'Matchmaking Services LLC',       -- business_name
    'MatchmakingPro',                 -- alias
    'info@matchmaking.com',           -- business_email
    '5551234567',                     -- primary_phone
    1,                                -- primary_phone_country_code
    NULL,                             -- secondary_phone
    '789 Business Center',            -- address_line1
    'Boston',                         -- city
    22,                               -- state (Massachusetts)
    1,                                -- country (USA)
    '02101',                          -- zip
    'REG123456789',                   -- business_registration_number
    'ITIN987654321',                  -- business_ITIN
    'Professional matchmaking services', -- business_description
    'Jane',                           -- primary_contact_first_name
    'Smith',                          -- primary_contact_last_name
    2,                                -- primary_contact_gender (Female)
    '1985-03-20',                     -- primary_contact_date_of_birth
    'jane@matchmaking.com',           -- primary_contact_email
    'linkedin.com/company/matchmaking', -- business_linkedin
    'https://matchmaking.com',        -- business_website
    'facebook.com/matchmaking',       -- business_facebook
    '+15551234567',                   -- business_whatsapp
    'admin@example.com'               -- user_created
);
```

### Generate API Credentials

```sql
CALL admin_api_clients_create(
    @partner_id,                      -- from partner registration
    'Matchmaking Services LLC',       -- partner_name
    'matchmaking.com',                -- partner_root_domain
    'https://admin.matchmaking.com',  -- partner_admin_url
    1234                              -- partner_pin
);

-- Response includes generated api_key (64 chars)
-- Store this securely - it won't be shown again!
```

### Use API Key

```javascript
// In partner's application
const response = await fetch('https://api.matrimony.com/profiles/search', {
    headers: {
        'X-API-Key': 'generated_api_key_here',
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({ /* search criteria */ })
});
```

---

## 6. Performance Tips

### Indexing
- All primary keys and foreign keys are indexed
- Email fields are indexed for quick lookups
- Add indexes on frequently queried columns

### Query Optimization
```sql
-- Good: Use stored procedures (already optimized)
CALL eb_profile_search_get(...);

-- Avoid: Direct SELECT with complex JOINs
-- Let procedures handle the complexity
```

### Large Result Sets
```sql
-- For admin dashboards, add pagination to procedures
-- Or fetch in batches using LIMIT and OFFSET
```

### Activity Log Maintenance
```sql
-- Archive old activity logs periodically
-- Keep last 90 days in main table
-- Move older records to archive table
INSERT INTO activity_log_archive 
SELECT * FROM activity_log 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);

DELETE FROM activity_log 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
```

---

## 7. Common Pitfalls

### ❌ Don't
```sql
-- Don't query tables directly
SELECT * FROM profile_personal WHERE email_id = 'user@example.com';

-- Don't hardcode lookup IDs
INSERT INTO profile_personal (gender, ...) VALUES (1, ...); -- What's 1?

-- Don't skip validation
-- App should validate before calling procedures
```

### ✅ Do
```sql
-- Use stored procedures
CALL eb_profile_personal_get(@profile_id);

-- Get lookup values first, then use IDs
CALL lkp_get_LookupData('Gender');
-- Then use the returned ID

-- Validate in app layer AND database
-- Double validation prevents bad data
```

---

## 8. Testing Checklist

### Unit Tests
- [ ] Test each procedure with valid data
- [ ] Test each procedure with invalid data
- [ ] Test duplicate prevention (email, phone, etc.)
- [ ] Test age validation (min 20-21, max 85)
- [ ] Test required field validation
- [ ] Test foreign key constraints

### Integration Tests
- [ ] Test complete user registration flow
- [ ] Test profile creation with all components
- [ ] Test search with various criteria
- [ ] Test profile interactions (view, favorite, contact)
- [ ] Test Stripe webhook synchronization
- [ ] Test partner API authentication

### Performance Tests
- [ ] Test search with 10,000+ profiles
- [ ] Test concurrent user registrations
- [ ] Test profile view tracking with high volume
- [ ] Monitor query execution times

---

## 9. Maintenance Tasks

### Daily
- Monitor error logs in `activity_log`
- Check for failed Stripe webhooks

### Weekly
- Review slow queries
- Check database size and growth
- Archive old activity logs

### Monthly
- Update statistics for query optimizer
```sql
ANALYZE TABLE profile_personal;
ANALYZE TABLE profile_views;
ANALYZE TABLE activity_log;
```
- Review and optimize indexes
- Check for orphaned records

### As Needed
- Backup database before major changes
- Test restore procedures
- Update lookup table data
- Add new error codes for new features

---

## 10. Resources

### Documentation Files
- `DATABASE_OVERVIEW.md` - High-level architecture
- `TABLE_REFERENCE.md` - All tables with details
- `PROCEDURES_REFERENCE.md` - All procedures with examples
- `error_codes.md` - Complete error code list

### SQL Files
- `/database/tables/` - Table creation scripts
- `/database/procedures/` - Stored procedure scripts
- `/database/data/` - Reference data scripts

### Support
- Check error_codes.md for error descriptions
- Review procedure code for business logic
- Check activity_log table for debugging

---

## Quick Reference Card

```sql
-- USER OPERATIONS
CALL eb_account_login_create(...);           -- Register
CALL eb_login_validate(user, pass);          -- Login
CALL eb_reset_password(...);                 -- Change password

-- PROFILE OPERATIONS
CALL eb_profile_personal_create(...);        -- Create profile
CALL eb_profile_get_complete_data(id);       -- Get all data
CALL eb_profile_[component]_create(...);     -- Add component

-- SEARCH & MATCH
CALL eb_profile_search_preference_create(...); -- Set preferences
CALL eb_profile_search_get(id, ...);         -- Search

-- INTERACTIONS
CALL eb_profile_views_create(from, to, acc); -- Record view
CALL eb_profile_favorites_create(...);       -- Add favorite
CALL eb_profile_contacted_create(...);       -- Record contact

-- LOOKUPS
CALL lkp_get_LookupData('Category');         -- Get options
CALL lkp_get_Country_List();                 -- Get countries
```

---

**You're now ready to work with the matrimony services database!**
