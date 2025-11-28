# Stored Procedures Reference

## Procedure Naming Convention

- **`eb_*`** - External/user-facing procedures
- **`admin_*`** - Administrative procedures
- **`lkp_*`** - Lookup data procedures
- **`common_*`** - Utility procedures
- **`stripe_*`** - Stripe integration procedures

## Procedure Inventory by Module

### Authentication & Account (7 procedures)

| Procedure | Purpose | Key Parameters |
|-----------|---------|----------------|
| `eb_account_login_create` | Create account + login | email, password, personal details |
| `eb_login_validate` | Validate login | user_name, password |
| `eb_validate_mail_and_generate_OTP` | Generate OTP | email |
| `eb_validate_email_otp` | Validate OTP | email, otp |
| `eb_update_new_password_forgot_password` | Reset password (forgot) | email, new_password |
| `eb_reset_password` | Reset password (logged in) | login_id, old_password, new_password |
| `eb_enable_disable_account` | Enable/disable account | account_id, action, reason |

### Profile Personal (3 procedures)

| Procedure | Purpose | Key Parameters |
|-----------|---------|----------------|
| `eb_profile_personal_create` | Create personal profile | account_id, personal details |
| `eb_profile_personal_get` | Get personal profile | profile_id |
| `eb_profile_personal_update` | Update personal profile | profile_id, personal details |

### Profile Components (40 procedures)
Each component has 4 procedures: create, get, update, delete

**Components**:
- Address (`eb_profile_address_*`)
- Contact (`eb_profile_contact_*`)
- Education (`eb_profile_education_*`)
- Employment (`eb_profile_employment_*`)
- Family Reference (`eb_profile_family_reference_*`)
- Hobby Interest (`eb_profile_hobby_interest_*`)
- Lifestyle (`eb_profile_lifestyle_*`)
- Photo (`eb_profile_photo_*`)
- Property (`eb_profile_property_*`)
- Search Preference (`eb_profile_search_preference_*`)

### Social Features (12 procedures)

**Profile Views**:
- `eb_profile_views_create` - Record view
- `eb_profile_views_get` - Get views
- `eb_profile_views_get_viewed_by_me` - Profiles I viewed
- `eb_profile_views_get_viewed_me` - Who viewed me
- `eb_profile_views_update` - Update view
- `eb_profile_views_delete` - Delete view

**Profile Favorites**:
- `eb_profile_favorites_create` - Add favorite
- `eb_profile_favorites_get` - Get favorites
- `eb_profile_favorites_update` - Update favorite
- `eb_profile_favorites_delete` - Remove favorite

**Profile Contacted**:
- `eb_profile_contacted_create` - Record contact
- `eb_profile_contacted_get` - Get contacts
- `eb_profile_contacted_update` - Update contact
- `eb_profile_contacted_delete` - Delete contact

**Profile Saved**:
- `eb_profile_saved_for_later_create` - Save profile
- `eb_profile_saved_for_later_get` - Get saved
- `eb_profile_saved_for_later_update` - Update saved
- `eb_profile_saved_for_later_delete` - Delete saved

### Search & Matching (4 procedures)

| Procedure | Purpose | Key Parameters |
|-----------|---------|----------------|
| `eb_profile_search_preference_create` | Create search prefs | profile_id, age range, filters |
| `eb_profile_search_preference_get` | Get search prefs | profile_id |
| `eb_profile_search_preference_update` | Update search prefs | search_preference_id, filters |
| `eb_profile_search_get` | Search profiles | profile_id, override params |
| `eb_profile_search_get_all` | Get all profiles | none |

### Partner Management (4 procedures)

| Procedure | Purpose | Key Parameters |
|-----------|---------|----------------|
| `eb_registered_partner_create` | Register partner | business details |
| `admin_registered_partner_get` | Get partner | reg_partner_id |
| `admin_registered_partner_update` | Update partner | reg_partner_id, details |
| `admin_registered_partner_delete` | Delete partner | reg_partner_id, reason |
| `admin_api_clients_create` | Create API client | partner_id, details |

### Utility & Lookup (4 procedures)

| Procedure | Purpose | Key Parameters |
|-----------|---------|----------------|
| `lkp_get_LookupData` | Get lookup by category | category |
| `lkp_get_Country_List` | Get all countries | none |
| `lkp_get_Country_States` | Get states by country | country_id |
| `get_accountDetails` | Get account details | account_id |
| `eb_account_profile_get` | Get account + profile | account_id |
| `eb_profile_get_complete_data` | Get complete profile | profile_id |

### Logging (2 procedures)

| Procedure | Purpose | Key Parameters |
|-----------|---------|----------------|
| `common_log_activity` | Log activity | activity_type, details, login_id |
| `common_log_error` | Log error | error_code, error_message, context |

---

## Detailed Procedure Documentation

### eb_account_login_create

**Purpose**: Create new user account with login credentials

**Parameters**:
```sql
IN p_email VARCHAR(150)
IN p_user_pwd VARCHAR(150)
IN p_first_name VARCHAR(45)
IN p_middle_name VARCHAR(45)
IN p_last_name VARCHAR(45)
IN p_birth_date DATE
IN p_gender INT
IN p_primary_phone VARCHAR(10)
IN p_primary_phone_country VARCHAR(5)
IN p_primary_phone_type INT
IN p_secondary_phone VARCHAR(10)
IN p_secondary_phone_country VARCHAR(5)
IN p_secondary_phone_type INT
IN p_address_line1 VARCHAR(45)
IN p_address_line2 VARCHAR(45)
IN p_city VARCHAR(45)
IN p_state VARCHAR(45)
IN p_zip VARCHAR(45)
IN p_country VARCHAR(45)
IN p_photo VARCHAR(45)
IN p_secret_question VARCHAR(45)
IN p_secret_answer VARCHAR(45)
```

**Validations**:
- Email required and valid format
- Password required
- First name and last name required
- Birth date validation (min age 20 years)
- Duplicate email check
- Duplicate phone check

**Returns**:
```json
{
  "status": "success" | "fail",
  "error_type": "Validation Exception" | "SQL Exception",
  "account_id": 123,
  "account_code": "ACC000123",
  "email": "user@example.com",
  "error_code": "45001_MISSING_EMAIL",
  "error_message": "Email is required"
}
```

**Error Codes**: 45001-45999

---

### eb_profile_personal_create

**Purpose**: Create detailed personal profile

**Parameters**: 30+ fields including demographics, physical attributes, social media, etc.

**Key Validations**:
- Account must exist and be active
- Age between 21-85 years
- No duplicate profile (first + last name + DOB)
- No duplicate email or mobile phone
- Phone number must have 10+ digits
- Valid email format
- Height/weight must be > 0

**Returns**: Success with profile_id or error details

**Error Codes**: 46001-46017

---

### eb_profile_search_get

**Purpose**: Search for matching profiles based on preferences

**Parameters**:
```sql
IN p_profile_id INT               -- Searcher's profile
IN p_min_age INT                  -- Override or -1 to ignore
IN p_max_age INT
IN p_religion INT
IN p_max_education INT
IN p_occupation INT
IN p_country INT
IN p_casete_id INT
IN p_marital_status INT
```

**Logic**:
1. Retrieve saved search preferences for p_profile_id
2. Apply override parameters:
   - If parameter = -1: Ignore this filter
   - If parameter IS NOT NULL: Use parameter value
   - If parameter IS NULL: Use saved preference
3. Search profile_personal with filters
4. Exclude own profile from results

**Returns**: List of matching profiles with full personal details

**Usage Example**:
```sql
-- Use saved preferences
CALL eb_profile_search_get(123, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Override min/max age, use saved prefs for rest
CALL eb_profile_search_get(123, 25, 35, NULL, NULL, NULL, NULL, NULL, NULL);

-- Ignore religion filter, use saved for rest
CALL eb_profile_search_get(123, NULL, NULL, -1, NULL, NULL, NULL, NULL, NULL);
```

---

### eb_profile_views_create

**Purpose**: Record that one profile viewed another

**Parameters**:
```sql
IN p_from_profile_id INT   -- Viewer
IN p_to_profile_id INT     -- Viewed
IN p_account_id INT        -- Associated account
```

**Validations**:
- Both profiles must exist
- Cannot view own profile
- Prevents duplicate views (or updates existing)

**Returns**: Success or error

**Error Codes**: 59001-59014

---

### eb_profile_favorites_create

**Purpose**: Add profile to favorites

**Parameters**:
```sql
IN p_from_profile_id INT   -- User
IN p_to_profile_id INT     -- Favorited profile
IN p_account_id INT
```

**Validations**:
- Both profiles must exist
- Cannot favorite own profile
- Check for duplicate favorite

**Returns**: Success with favorite_id or error

**Error Codes**: 58001-58015

---

### admin_api_clients_create

**Purpose**: Generate API credentials for registered partner

**Parameters**:
```sql
IN p_partner_id INT
IN p_partner_name VARCHAR(255)
IN p_partner_root_domain VARCHAR(50)
IN p_partner_admin_url VARCHAR(100)
IN p_partner_pin INT
```

**Logic**:
1. Validates partner exists
2. Generates unique API key (64 characters)
3. Creates api_clients record
4. Returns API key (only shown once!)

**Returns**: API client details with generated api_key

**Security Note**: API key should be stored securely by partner, used for authentication

---

### lkp_get_LookupData

**Purpose**: Retrieve lookup values by category

**Parameters**:
```sql
IN p_category VARCHAR(150)   -- e.g., 'Gender', 'MaritalStatus', 'Religion'
```

**Returns**: List of lookup values for that category

**Common Categories**:
- PhoneType (Mobile, Home, Work, Emergency)
- Gender (Male, Female, Other)
- MaritalStatus (Single, Married, Divorced, Widowed)
- Religion (Hindu, Muslim, Christian, Buddhist, etc.)
- Education (High School, Bachelor's, Master's, PhD, etc.)
- Occupation (Engineer, Doctor, Teacher, Business, etc.)

---

### common_log_activity

**Purpose**: Log user activity for audit trail

**Parameters**:
```sql
IN p_activity_type VARCHAR(100)      -- e.g., 'LOGIN', 'PROFILE_VIEW', 'SEARCH'
IN p_activity_details VARCHAR(255)   -- Additional details
IN p_login_id INT
IN p_ip_address VARCHAR(45)
IN p_browser_profile VARCHAR(255)
```

**Usage**: Called by application for important user actions

---

### common_log_error

**Purpose**: Log errors with context

**Parameters**:
```sql
IN p_error_code VARCHAR(100)
IN p_error_message VARCHAR(255)
IN p_user_context VARCHAR(45)       -- Email or username
IN p_procedure_name VARCHAR(100)
IN p_start_time DATETIME
```

**Usage**: Called automatically by error handlers in procedures

---

## Standard Error Handling Pattern

All procedures implement this pattern:

```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
    ROLLBACK;
    GET DIAGNOSTICS CONDITION 1 
        error_message = MESSAGE_TEXT, 
        error_code = MYSQL_ERRNO;
    
    CALL common_log_error(
        error_code, 
        error_message, 
        p_user_email, 
        'PROCEDURE_NAME', 
        start_time
    );
    
    SELECT 'fail' AS status, 
           'SQL Exception' as error_type,
           error_code, 
           error_message;
END;

DECLARE EXIT HANDLER FOR SQLSTATE '45000' BEGIN
    ROLLBACK;
    
    CALL common_log_error(
        error_code, 
        error_message, 
        p_user_email, 
        'PROCEDURE_NAME', 
        start_time
    );
    
    SELECT 'fail' AS status, 
           'Validation Exception' as error_type,
           error_code, 
           error_message;
END;
```

---

## Standard Response Format

### Success Response
```json
{
  "status": "success",
  "data": {
    "id": 123,
    "other_fields": "values"
  }
}
```

### Error Response
```json
{
  "status": "fail",
  "error_type": "Validation Exception",
  "error_code": "45001_MISSING_EMAIL",
  "error_message": "Email is required"
}
```

---

## Usage Guidelines

### 1. Always Use Stored Procedures
Direct table access should be avoided. Use procedures for all operations.

### 2. Handle Errors Gracefully
Check response status and display appropriate error messages to users.

### 3. Log Important Actions
Use `common_log_activity` for audit trail of critical operations.

### 4. Validate Input
Procedures validate input, but application should also validate for better UX.

### 5. Use Transactions
Procedures handle transactions automatically. Don't nest transactions.

### 6. Parameter Order Matters
Follow exact parameter order as defined in procedure signature.

### 7. NULL vs Empty String
- Use NULL for optional parameters
- Empty string may be treated as invalid input

### 8. Override Parameters
For search procedures, use:
- `NULL` to use saved preference
- `-1` to ignore/skip that filter
- Actual value to override preference

---

## Testing Procedures

```sql
-- Test account creation
CALL eb_account_login_create(
    'test@example.com', 'password123', 'John', NULL, 'Doe',
    '1990-01-15', 1, '1234567890', '+1', 1,
    NULL, NULL, NULL, '123 Main St', NULL,
    'CityName', 'StateName', '12345', 'USA',
    NULL, NULL, NULL
);

-- Test profile search with saved preferences
CALL eb_profile_search_get(123, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Test profile search with overrides
CALL eb_profile_search_get(123, 25, 35, -1, NULL, NULL, NULL, NULL, NULL);

-- Test lookup data
CALL lkp_get_LookupData('Gender');
CALL lkp_get_Country_List();

-- Test profile views
CALL eb_profile_views_create(123, 456, 789);
CALL eb_profile_views_get_viewed_me(123);
```
