# Database Tables Reference

## Quick Reference Table

| # | Table Name | Purpose | Key Columns | Relationships |
|---|------------|---------|-------------|---------------|
| 1 | account | User accounts | account_id, email, phone | → login, profile_personal, stripe_customers |
| 2 | login | Login credentials | login_id, account_id, user_name | account ← |
| 3 | login_history | Login tracking | login_id, login_date, ip_address | login ← |
| 4 | activity_log | Activity logging | log_id, log_type, message | - |
| 5 | profile_personal | Core profile | profile_id, account_id | account ←, → all profile_* |
| 6 | profile_address | Addresses | profile_id, address_type | profile_personal ← |
| 7 | profile_contact | Contacts | profile_id, contact_type | profile_personal ← |
| 8 | profile_education | Education | profile_id, institution_name | profile_personal ← |
| 9 | profile_employment | Employment | profile_id, job_title_id | profile_personal ← |
| 10 | profile_family_reference | Family contacts | profile_id, reference_type | profile_personal ← |
| 11 | profile_hobby_interest | Hobbies | profile_id, hobby_interest_type | profile_personal ← |
| 12 | profile_lifestyle | Lifestyle | profile_id, diet_preference | profile_personal ← |
| 13 | profile_photo | Photos | profile_id, photo_type | profile_personal ← |
| 14 | profile_property | Property | profile_id, property_type | profile_personal ← |
| 15 | profile_search_preference | Search criteria | profile_id, min_age, max_age | profile_personal ← |
| 16 | profile_views | View tracking | from_profile_id, to_profile_id | profile_personal ← (both) |
| 17 | profile_favorites | Favorites | from_profile_id, to_profile_id | profile_personal ← (both) |
| 18 | profile_contacted | Contacts | from_profile_id, to_profile_id | profile_personal ← (both) |
| 19 | profile_saved_for_later | Saved profiles | from_profile_id, to_profile_id | profile_personal ← (both) |
| 20 | registered_partner | Partners | reg_partner_id, business_name | → api_clients |
| 21 | api_clients | API keys | id, api_key, partner_id | registered_partner ← |
| 22 | lookup_table | Lookups | id, name, category | Referenced by many |
| 23 | country | Countries | country_id, country_code_2 | → state |
| 24 | state | States | state_id, country_id | country ←, → zip_code |
| 25 | zip_code | ZIP codes | zip_id, state_id | state ← |
| 26-43 | stripe_* | Stripe data | Various Stripe IDs | stripe_customers as root |

---

## Detailed Table Descriptions

### account
**Purpose**: Central user account storage

**Key Fields**:
- `account_id` (PK) - Unique identifier
- `account_code` (UNIQUE) - Human-readable code
- `email` - User email
- `primary_phone` / `secondary_phone` - Contact numbers
- `first_name`, `last_name`, `middle_name` - Full name
- `birth_date`, `gender` - Demographics
- `address_line1/2`, `city`, `state`, `zip`, `country` - Location
- `is_active`, `is_deleted` - Status flags
- Audit fields: `created_date`, `modified_date`, `activated_date`, `deactivated_date`

**Indexes**: PK on `account_id`, UNIQUE on `account_code`

---

### login
**Purpose**: Authentication credentials

**Key Fields**:
- `login_id` (PK)
- `account_id` (FK to account)
- `user_name` - Login username
- `password` - Hashed password
- `is_active` - Status
- Audit fields: `created_date`, `modified_date`, `deactivation_date`

---

### profile_personal
**Purpose**: Detailed personal profile information

**Key Fields**:
- `profile_id` (PK)
- `account_id` (FK to account)
- Demographics: `first_name`, `last_name`, `gender`, `birth_date`
- Contact: `phone_mobile`, `phone_home`, `email_id`
- Physical: `height_inches`, `height_cms`, `weight`, `complexion`
- Social: `marital_status`, `religion`, `nationality`, `caste`, `profession`
- Social media: `linkedin`, `facebook`, `instagram`, `whatsapp_number`
- `is_active` - Status

**Indexes**: PK, index on `email_id`, `is_active`

**Validations**: Age 21-85, valid email, phone formats

---

### profile_education
**Purpose**: Educational background (supports multiple degrees)

**Key Fields**:
- `profile_education_id` (PK)
- `profile_id` (FK to profile_personal)
- `education_level` - Degree type (from lookup)
- `institution_name`, `field_of_study`
- `year_completed`
- Location: `city`, `state_id`, `country_id`, `zip`
- `isverified` - Verification status

---

### profile_employment
**Purpose**: Employment history (supports multiple jobs)

**Key Fields**:
- `profile_employment_id` (PK)
- `profile_id` (FK to profile_personal)
- `institution_name` - Employer
- `job_title_id` - Job title (from lookup)
- `start_year`, `end_year` - Employment period
- `last_salary_drawn`
- Location: `city`, `state_id`, `country_id`, `zip`

---

### profile_photo
**Purpose**: Profile photo gallery

**Key Fields**:
- `profile_photo_id` (PK)
- `profile_id` (FK to profile_personal)
- `photo_type` - Type (1=Headshot, 2=Full-body, 3=Casual, 4=Family, 5=Candid, 6=Hobby)
- `url`, `relative_path` - Photo location
- `caption`, `description`
- `isverified` - Verification status
- `softdelete` - Soft delete flag

---

### profile_views
**Purpose**: Track who viewed whose profile (many-to-many self-referencing)

**Key Fields**:
- `profile_view_id` (PK)
- `from_profile_id` (FK to profile_personal) - Viewer
- `to_profile_id` (FK to profile_personal) - Viewed
- `profile_view_date` - When viewed
- `account_id` - Associated account

**Usage**: Powers "Who viewed my profile" and "Profiles I viewed" features

---

### profile_favorites
**Purpose**: User's favorited/shortlisted profiles

**Key Fields**:
- `profile_favorite_id` (PK)
- `from_profile_id` (FK to profile_personal) - User
- `to_profile_id` (FK to profile_personal) - Favorited profile
- `is_active` - Active status
- `date_created`, `date_updated`

---

### profile_search_preference
**Purpose**: User's search criteria for matching

**Key Fields**:
- `search_preference_id` (PK)
- `profile_id` (FK to profile_personal)
- `min_age`, `max_age` - Age range
- `religion`, `casete_id` - Religious preferences
- `max_education`, `occupation` - Education/career
- `country`, `marital_status`, `gender` - Other filters

**Usage**: Used by `eb_profile_search_get` procedure

---

### stripe_customers
**Purpose**: Stripe customer records linked to accounts

**Key Fields**:
- `id` (PK) - Stripe customer ID (cus_XXX)
- `account_id` (FK to account) - Internal account link
- `email`, `name`, `phone`
- Address fields: `address_line1/2`, `city`, `state`, `postal_code`, `country`
- `default_payment_method_id`
- `tax_exempt`, `tax_ids` (JSON)
- `metadata` (JSON) - Additional data

**Indexes**: `account_id`, `email`, `created_at`

---

### stripe_subscriptions
**Purpose**: Subscription records

**Key Fields**:
- `id` (PK) - Stripe subscription ID (sub_XXX)
- `customer_id` (FK to stripe_customers, CASCADE DELETE)
- `status` - incomplete, trialing, active, past_due, canceled, unpaid
- `current_period_start`, `current_period_end` - Billing period
- `trial_start`, `trial_end` - Trial period
- `cancel_at_period_end`, `canceled_at` - Cancellation
- `default_payment_method_id`, `latest_invoice_id`
- `metadata` (JSON)

**Indexes**: `customer_id`, `status`, `current_period_end`

---

### registered_partner
**Purpose**: Business partner registration

**Key Fields**:
- `reg_partner_id` (PK)
- `business_name`, `alias`
- `business_email`, `primary_phone`
- Address: `address_line1`, `city`, `state`, `country`, `zip`
- `business_registration_number`, `business_ITIN` - Legal info
- `primary_contact_*` - Contact person details
- `business_website`, `business_linkedin`, `business_facebook`
- `isverified`, `Is_active` - Status
- `verification_status`, `verification_comment`

---

### api_clients
**Purpose**: API authentication for partners

**Key Fields**:
- `id` (PK)
- `partner_id` (FK to registered_partner)
- `api_key` (UNIQUE) - Authentication key
- `partner_name`, `partner_root_domain`
- `is_active` - Status
- `activated_date`, `deactivated_date`
- `activation_notes`, `deactivation_notes`

**Security**: API key must be kept secure, used for authentication

---

### lookup_table
**Purpose**: Central reference data for dropdowns

**Key Fields**:
- `id` (PK)
- `name` - Display value
- `description` - Additional info
- `category` - Group (PhoneType, Gender, MaritalStatus, Religion, etc.)
- `isactive` - Active status

**Categories**:
- PhoneType, Gender, MaritalStatus, Religion, Caste
- Education, Occupation, AddressType, ContactType
- PhotoType, PropertyType, ReferenceType, and more

---

### country
**Purpose**: Country reference with ISO codes

**Key Fields**:
- `country_id` (PK)
- `country_name`, `official_name`
- `country_code_2` (UNIQUE) - ISO 3166-1 alpha-2 (e.g., US, IN)
- `country_code_3` (UNIQUE) - ISO 3166-1 alpha-3 (e.g., USA, IND)
- `country_calling_code` - Phone code (e.g., +1, +91)
- `region`, `latitude`, `longitude`
- `flag_emoji`, `flag_image_url`

**Indexes**: `country_name`, `country_code_2`, `country_code_3`

---

### state
**Purpose**: State/province data

**Key Fields**:
- `state_id` (PK)
- `state_name`, `state_code`
- `country_id` (FK to country)
- `is_active`

---

## Table Relationships Diagram

```
account
├── login (1:1)
│   └── login_history (1:many)
├── profile_personal (1:many)
│   ├── profile_address (1:many)
│   ├── profile_contact (1:many)
│   ├── profile_education (1:many)
│   ├── profile_employment (1:many)
│   ├── profile_family_reference (1:many)
│   ├── profile_hobby_interest (1:many)
│   ├── profile_lifestyle (1:many)
│   ├── profile_photo (1:many)
│   ├── profile_property (1:many)
│   ├── profile_search_preference (1:1)
│   ├── profile_views (many:many self)
│   ├── profile_favorites (many:many self)
│   ├── profile_contacted (many:many self)
│   └── profile_saved_for_later (many:many self)
└── stripe_customers (1:1)
    ├── stripe_subscriptions (1:many)
    ├── stripe_payment_intents (1:many)
    ├── stripe_invoices (1:many)
    └── stripe_payment_methods (1:many)

registered_partner
└── api_clients (1:many)

country
└── state (1:many)
    └── zip_code (1:many)
```

---

## Common Query Patterns

### Get Complete User Profile
```sql
CALL eb_profile_get_complete_data(profile_id);
-- Returns all profile data in one call
```

### Search for Matches
```sql
CALL eb_profile_search_get(profile_id, min_age, max_age, religion, education, occupation, country, caste, marital_status);
-- Override parameters or use -1 to ignore filter
```

### Track Profile Views
```sql
CALL eb_profile_views_create(from_profile_id, to_profile_id, account_id);
CALL eb_profile_views_get_viewed_me(profile_id); -- Who viewed me
CALL eb_profile_views_get_viewed_by_me(profile_id); -- Who I viewed
```

### Get Lookup Data
```sql
CALL lkp_get_LookupData('Gender'); -- Get all gender options
CALL lkp_get_Country_List(); -- Get all countries
CALL lkp_get_Country_States(country_id); -- Get states for country
```
