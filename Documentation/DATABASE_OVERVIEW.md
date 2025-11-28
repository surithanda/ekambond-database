# Matrimony Services Database - Complete Documentation

## Overview

This is a comprehensive matrimony/matchmaking platform database supporting user profiles, search/matching, payments (Stripe), and partner integrations.

### Quick Stats
- **42 Tables**: Authentication, Profiles, Social Features, Stripe Integration, Partners, Reference Data
- **85+ Stored Procedures**: Complete CRUD operations with validation
- **Database Engine**: MySQL/MariaDB
- **Key Features**: User profiles, search/match, Stripe payments, API for partners

---

## Table Categories

### 1. Authentication & Account (4 tables)
- `account` - User accounts with personal info
- `login` - Login credentials
- `login_history` - Login tracking
- `activity_log` - Activity and error logging

### 2. Profile Management (11 tables)
- `profile_personal` - Core profile data
- `profile_address` - Multiple addresses
- `profile_contact` - Contact methods
- `profile_education` - Education history
- `profile_employment` - Employment history
- `profile_family_reference` - Family contacts
- `profile_hobby_interest` - Hobbies
- `profile_lifestyle` - Lifestyle preferences
- `profile_photo` - Photo gallery
- `profile_property` - Property ownership
- `profile_search_preference` - Search criteria

### 3. Social Features (4 tables)
- `profile_views` - Who viewed whom
- `profile_favorites` - Favorited profiles
- `profile_contacted` - Contact tracking
- `profile_saved_for_later` - Saved profiles

### 4. Stripe Integration (18 tables)
- `stripe_customers`, `stripe_subscriptions`, `stripe_products`, `stripe_prices`
- `stripe_payment_methods`, `stripe_payment_intents`, `stripe_charges`
- `stripe_invoices`, `stripe_refunds`, `stripe_disputes`, `stripe_payouts`
- `stripe_balance_transactions`, `stripe_events`, `stripe_setup_intents`
- `stripe_checkout_sessions`, `stripe_subscription_items`
- `stripe_tax_rates`, `stripe_coupons`, `stripe_promotion_codes`

### 5. Partner Management (2 tables)
- `registered_partner` - Business partners
- `api_clients` - API credentials

### 6. Reference Data (3 tables)
- `lookup_table` - Central lookup for categories
- `country` - Country data with ISO codes
- `state` - State/province data
- `zip_code` - ZIP/postal codes

---

## Core Relationships

```
account (1:1) login (1:many) login_history
account (1:1) stripe_customers (1:many) stripe_subscriptions
account (1:many) profile_personal
    └── (1:many) profile_address, education, employment, family, photos, etc.
    └── (many:many) profile_views, favorites, contacted, saved (self-referencing)

registered_partner (1:many) api_clients
country (1:many) state (1:many) zip_code
```

---

## Key Stored Procedures

### Authentication
- `eb_account_login_create` - Register new user
- `eb_login_validate` - Validate login
- `eb_validate_mail_and_generate_OTP` - Email verification
- `eb_reset_password` - Password reset
- `eb_enable_disable_account` - Account activation

### Profile Management
- `eb_profile_personal_create/get/update` - Personal profile CRUD
- `eb_profile_[component]_create/get/update/delete` - For each profile component
- `eb_profile_get_complete_data` - Complete profile retrieval

### Social Features
- `eb_profile_views_create/get` - Track profile views
- `eb_profile_favorites_create/get/update/delete` - Favorites management
- `eb_profile_contacted_create/get` - Contact tracking
- `eb_profile_saved_for_later_create/get` - Save profiles

### Search
- `eb_profile_search_preference_create/get/update` - Search preferences
- `eb_profile_search_get` - Search matching profiles

### Partner Management
- `eb_registered_partner_create` - Register partner
- `admin_api_clients_create` - Generate API credentials

### Utilities
- `lkp_get_LookupData` - Get lookup values
- `lkp_get_Country_List` - Get countries
- `common_log_activity` - Log activities
- `common_log_error` - Log errors

---

## Error Handling

### Error Code Ranges
| Module | Range | Example Codes |
|--------|-------|---------------|
| Account Login | 45000-45999 | 45001_MISSING_EMAIL, 45005_DUPLICATE_EMAIL |
| Profile Personal Create | 46000-46999 | 46001_INVALID_ACCOUNTID, 46009_INVALID_AGE |
| Registered Partner | 48000-48999 | 48001-48014 (required fields) |
| Profile Components | 50000-64999 | Each component has 1000 code range |

All procedures return standardized error responses with status, error_code, and error_message.

---

## Security Features

1. **Authentication**: Password hashing, OTP verification, security questions
2. **Authorization**: API key authentication, account status checks
3. **Audit Trail**: Created/modified timestamps, user tracking, activity logs
4. **Data Protection**: Parameterized queries, input validation, soft deletes
5. **Error Handling**: Comprehensive logging without exposing sensitive data

---

## Common Data Flows

### User Registration
```
User Form → eb_account_login_create() 
  → Validate (age, email, phone)
  → Create account + login records
  → Return account_id
```

### Profile Creation
```
Personal Info → eb_profile_personal_create()
Additional Details → eb_profile_address_create(), eb_profile_education_create(), etc.
Photos → eb_profile_photo_create()
```

### Profile Search
```
Set Preferences → eb_profile_search_preference_create()
Search → eb_profile_search_get() 
  → Apply filters
  → Return matches
View Profile → eb_profile_views_create()
Interact → eb_profile_favorites_create() | eb_profile_contacted_create()
```

### Payment Flow
```
Select Plan → Stripe Checkout
Payment → Stripe Webhook
Webhook → stripe_sync procedures
  → Update stripe_customers, stripe_subscriptions, stripe_invoices
```

---

## Design Principles

1. **Modular Architecture**: Clear separation of concerns
2. **Data Integrity**: Foreign keys, constraints, validations
3. **Audit Trail**: Complete tracking of changes
4. **Soft Deletes**: Data retention and recovery
5. **Business Logic in Procedures**: Centralized validation
6. **Comprehensive Logging**: Activity and error tracking
7. **Performance**: Proper indexing, stored procedures
8. **Scalability**: JSON for flexible data, partitioning strategy

---

## For Developers

### Adding New Features
1. Create table in `/database/tables/`
2. Add stored procedures in `/database/procedures/`
3. Define error codes in `/database/documentation/error_codes.md`
4. Update this documentation
5. Test procedures thoroughly

### Naming Conventions
- Tables: lowercase with underscores (`profile_personal`)
- Procedures: `[prefix]_[table]_[action]` (e.g., `eb_profile_personal_create`)
- Prefixes: `eb_` (external), `admin_` (admin), `lkp_` (lookup), `common_` (utility)
- Error codes: `[number]_[DESCRIPTION]` (e.g., `45001_MISSING_EMAIL`)

### Best Practices
- Always use stored procedures for data operations
- Validate input parameters in procedures
- Log errors with context
- Use transactions for multi-table operations
- Return standardized response format
- Document new procedures and error codes
- Test edge cases and error conditions

---

## Reference Links

- **Error Codes**: See `error_codes.md` for complete error code reference
- **Table Schemas**: See individual SQL files in `/database/tables/`
- **Procedure Code**: See SQL files in `/database/procedures/`
- **Data Scripts**: See `/database/data/` for lookup data

---

## Support Information

For questions about:
- **Table Structure**: Review SQL files in `/database/tables/`
- **Procedure Logic**: Review SQL files in `/database/procedures/`
- **Error Codes**: See `error_codes.md`
- **Setup**: See deployment scripts in `/database/`
