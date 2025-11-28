# Entity Relationship Diagrams

## Visual Database Schema Reference

This document provides visual representations of the database relationships and structure.

---

## 1. Core System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     USER SYSTEM                              │
│                                                              │
│  ┌─────────┐         ┌─────────┐         ┌──────────────┐  │
│  │ account │ 1 ─── 1 │  login  │ 1 ─── * │login_history │  │
│  └────┬────┘         └─────────┘         └──────────────┘  │
│       │                                                      │
│       │ 1                                                    │
│       │                                                      │
│       │ *                                                    │
│  ┌────▼────────────────────────────────────────────────┐   │
│  │          PROFILE SYSTEM (see below)                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│       │ 1                                                    │
│       │                                                      │
│       │ 1                                                    │
│  ┌────▼──────────────────────────────────────────────┐     │
│  │    PAYMENT SYSTEM (Stripe - see below)            │     │
│  └────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                  PARTNER SYSTEM                              │
│                                                              │
│  ┌────────────────────┐         ┌─────────────┐            │
│  │registered_partner  │ 1 ─── * │ api_clients │            │
│  └────────────────────┘         └─────────────┘            │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                REFERENCE DATA SYSTEM                         │
│                                                              │
│  ┌─────────┐         ┌───────┐         ┌──────────┐        │
│  │ country │ 1 ─── * │ state │ 1 ─── * │ zip_code │        │
│  └─────────┘         └───────┘         └──────────┘        │
│                                                              │
│  ┌──────────────┐                                           │
│  │lookup_table  │ (Referenced by many tables)              │
│  └──────────────┘                                           │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Profile System Detail

```
                        ┌────────────────┐
                        │profile_personal│
                        │      (PK)      │
                        └────────┬───────┘
                                 │ 1
                 ┌───────────────┼───────────────┐
                 │               │               │
                 │ *             │ *             │ *
        ┌────────▼────────┐  ┌──▼───────────┐ ┌▼──────────────┐
        │profile_address  │  │profile_photo │ │profile_contact│
        └─────────────────┘  └──────────────┘ └───────────────┘
                 
                 │ *             │ *             │ *
        ┌────────▼─────────┐ ┌─▼──────────────┐ ┌▼────────────┐
        │profile_education│ │profile_employment│ │profile_hobby│
        └─────────────────┘ └──────────────────┘ └─────────────┘
                 
                 │ *             │ *             │ *
        ┌────────▼─────────┐ ┌─▼──────────────┐ ┌▼─────────────┐
        │profile_lifestyle│ │profile_property │ │profile_family│
        └─────────────────┘ └─────────────────┘ └──────────────┘

                                 │ 1
                        ┌────────▼──────────┐
                        │profile_search_pref│
                        └───────────────────┘
```

---

## 3. Social Features (Many-to-Many Self-Referencing)

```
┌──────────────────────────────────────────────────────────┐
│           Profile Interaction Tables                     │
│                                                          │
│  All connect: from_profile_id → to_profile_id           │
└──────────────────────────────────────────────────────────┘

         profile_personal (Profile A)
                │
                │ from_profile_id
                │
      ┌─────────┼─────────────────┬──────────────┐
      │         │                 │              │
      ▼         ▼                 ▼              ▼
┌──────────┐ ┌───────────┐ ┌──────────────┐ ┌─────────┐
│  views   │ │ favorites │ │  contacted   │ │  saved  │
└──────┬───┘ └─────┬─────┘ └──────┬───────┘ └────┬────┘
       │           │               │              │
       │ to_profile_id            │              │
       │           │               │              │
       └───────────┴───────────────┴──────────────┘
                            │
                            ▼
              profile_personal (Profile B)

Example:
- User A views User B: (from_profile_id=A, to_profile_id=B)
- User A favorites User B: (from_profile_id=A, to_profile_id=B)
- User B views User A: (from_profile_id=B, to_profile_id=A)
```

---

## 4. Payment System (Stripe Integration)

```
        account
           │ 1
           │
           │ 1
    ┌──────▼──────────┐
    │stripe_customers │ (PK: Stripe customer ID)
    └────────┬────────┘
             │ 1
             │
             ├─────────────────────────────────────────┐
             │                                         │
             │ *                                       │ *
    ┌────────▼────────────┐              ┌────────────▼─────────┐
    │stripe_subscriptions │              │stripe_payment_methods│
    └────────┬────────────┘              └──────────────────────┘
             │ 1
             │
             ├──────────────────────┬──────────────────┐
             │                      │                  │
             │ *                    │ *                │ *
    ┌────────▼─────────┐   ┌────────▼────────┐  ┌────▼──────┐
    │stripe_invoices   │   │stripe_payment_  │  │stripe_    │
    │                  │   │intents          │  │charges    │
    └──────────────────┘   └─────────────────┘  └───────────┘
             
             │ *                    │ *                │ *
    ┌────────▼─────────┐   ┌────────▼────────┐  ┌────▼──────┐
    │stripe_refunds    │   │stripe_disputes  │  │stripe_    │
    │                  │   │                 │  │payouts    │
    └──────────────────┘   └─────────────────┘  └───────────┘

Additional Tables:
- stripe_products, stripe_prices (product catalog)
- stripe_subscription_items (subscription line items)
- stripe_balance_transactions (transaction history)
- stripe_events (webhook log)
- stripe_checkout_sessions (checkout flows)
- stripe_setup_intents (payment method setup)
- stripe_tax_rates, stripe_coupons, stripe_promotion_codes
```

---

## 5. Relationship Cardinality

### One-to-One Relationships
```
account (1) ────── (1) login
account (1) ────── (1) stripe_customers
profile_personal (1) ────── (1) profile_search_preference
```

### One-to-Many Relationships
```
account (1) ────── (*) profile_personal
profile_personal (1) ────── (*) profile_address
profile_personal (1) ────── (*) profile_education
profile_personal (1) ────── (*) profile_employment
profile_personal (1) ────── (*) profile_photo
stripe_customers (1) ────── (*) stripe_subscriptions
registered_partner (1) ────── (*) api_clients
country (1) ────── (*) state
state (1) ────── (*) zip_code
```

### Many-to-Many (Self-Referencing)
```
profile_personal (*) ────── (*) profile_personal
  via: profile_views, profile_favorites, 
       profile_contacted, profile_saved_for_later
```

---

## 6. Data Flow Diagrams

### User Registration Flow
```
┌─────────┐
│  User   │
└────┬────┘
     │
     ▼
┌────────────────────┐
│ Registration Form  │
└────────┬───────────┘
         │
         ▼
┌────────────────────────┐
│eb_account_login_create │
└───────┬────────────────┘
        │
        ├────────────┐
        ▼            ▼
   ┌─────────┐  ┌───────┐
   │ account │  │ login │
   └─────────┘  └───────┘
        │
        ▼
   ┌──────────┐
   │Return ID │
   └──────────┘
```

### Profile Creation Flow
```
┌──────────┐
│ User ID  │
└────┬─────┘
     │
     ▼
┌──────────────────────────┐
│eb_profile_personal_create│
└────────┬─────────────────┘
         │
         ▼
    ┌────────────────┐
    │profile_personal│
    └────────┬───────┘
             │
     ┌───────┼────────┬─────────┐
     ▼       ▼        ▼         ▼
┌─────────┐ ┌───┐ ┌─────┐ ┌───────┐
│education│ │emp│ │photo│ │address│
└─────────┘ └───┘ └─────┘ └───────┘
```

### Search & Interaction Flow
```
┌──────────────┐
│ User Profile │
└──────┬───────┘
       │
       ▼
┌────────────────────────┐
│Set Search Preferences  │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│  Search Profiles       │
│eb_profile_search_get   │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│  Matching Profiles     │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│   View Profile         │
│eb_profile_views_create │
└────────┬───────────────┘
         │
         ├───────────────────┬──────────────┐
         ▼                   ▼              ▼
┌────────────────┐  ┌────────────┐  ┌───────────┐
│Add to Favorites│  │  Contact   │  │Save Later │
└────────────────┘  └────────────┘  └───────────┘
```

### Payment Flow
```
┌──────────┐
│   User   │
└────┬─────┘
     │
     ▼
┌────────────────┐
│Select Plan     │
└────┬───────────┘
     │
     ▼
┌────────────────┐
│Stripe Checkout │
└────┬───────────┘
     │
     ▼
┌────────────────┐     ┌─────────────────┐
│  Payment Made  │────▶│ Stripe Webhook  │
└────────────────┘     └────────┬────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Sync Procedure │
                       └────────┬────────┘
                                │
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
              ┌──────────┐ ┌────────┐ ┌────────┐
              │customers │ │subs    │ │invoices│
              └──────────┘ └────────┘ └────────┘
```

---

## 7. Table Dependencies (Build Order)

```
Level 1: Independent Tables (build first)
├── lookup_table
├── country
└── activity_log

Level 2: Reference Data
├── state (depends on: country)
└── zip_code (depends on: state, country)

Level 3: Core Authentication
├── account (depends on: lookup_table)
└── login (depends on: account)

Level 4: Authentication Extensions
└── login_history (depends on: login)

Level 5: Profile Foundation
└── profile_personal (depends on: account, lookup_table)

Level 6: Profile Components
├── profile_address (depends on: profile_personal, state, country)
├── profile_contact (depends on: profile_personal)
├── profile_education (depends on: profile_personal, state, country)
├── profile_employment (depends on: profile_personal, state, country)
├── profile_family_reference (depends on: profile_personal)
├── profile_hobby_interest (depends on: profile_personal)
├── profile_lifestyle (depends on: profile_personal)
├── profile_photo (depends on: profile_personal)
├── profile_property (depends on: profile_personal)
└── profile_search_preference (depends on: profile_personal)

Level 7: Social Features
├── profile_views (depends on: profile_personal, account)
├── profile_favorites (depends on: profile_personal, account)
├── profile_contacted (depends on: profile_personal, account)
└── profile_saved_for_later (depends on: profile_personal, account)

Level 8: Partners
├── registered_partner (depends on: state, country)
└── api_clients (depends on: registered_partner)

Level 9: Stripe Integration
├── stripe_customers (depends on: account)
└── All other stripe_* tables (depends on: stripe_customers)
```

---

## 8. Index Visualization

### Primary Keys (Clustered Indexes)
```
Every table has a primary key:
- account_id
- login_id
- profile_id
- profile_[component]_id
- Stripe tables use Stripe IDs as PK
```

### Unique Indexes
```
account.account_code       [UNIQUE]
api_clients.api_key        [UNIQUE]
country.country_code_2     [UNIQUE]
country.country_code_3     [UNIQUE]
```

### Foreign Key Indexes
```
All foreign keys are automatically indexed:
- login.account_id → account.account_id
- profile_personal.account_id → account.account_id
- profile_address.profile_id → profile_personal.profile_id
- stripe_subscriptions.customer_id → stripe_customers.id
- etc.
```

### Performance Indexes
```
profile_personal.email_id          [INDEX]
profile_personal.is_active         [INDEX]
stripe_customers.account_id        [INDEX]
stripe_customers.email             [INDEX]
stripe_subscriptions.status        [INDEX]
stripe_subscriptions.current_period_end [INDEX]
country.country_name               [INDEX]
```

---

## 9. Foreign Key Constraints

### CASCADE DELETE
```
stripe_subscriptions.customer_id → stripe_customers.id
  [ON DELETE CASCADE]
  
If stripe_customer deleted, all subscriptions deleted automatically
```

### RESTRICT (Default)
```
Most foreign keys use RESTRICT:
- Cannot delete account if login exists
- Cannot delete profile if photos exist
- Ensures data integrity
```

### Soft Deletes (Application Level)
```
Instead of DELETE, use:
- UPDATE account SET is_deleted = 1
- UPDATE profile_photo SET softdelete = 1
- Preserves data for audit and recovery
```

---

## 10. Quick Reference Matrix

| Table | PK | Main FK | Unique | Soft Delete | Audit Fields |
|-------|----|---------|----|-------------|--------------|
| account | account_id | - | account_code | is_deleted | ✓ |
| login | login_id | account_id | - | is_active | ✓ |
| profile_personal | profile_id | account_id | - | is_active | ✓ |
| profile_photo | profile_photo_id | profile_id | - | softdelete | ✓ |
| stripe_customers | id (Stripe) | account_id | - | deleted_at | ✓ |
| api_clients | id | partner_id | api_key | is_active | ✓ |

**Legend:**
- PK = Primary Key
- FK = Foreign Key
- Audit Fields = created_date, modified_date, created_user, modified_user

---

## Diagram Legend

```
Relationship Symbols:
(1) ────── (1)    One-to-One
(1) ────── (*)    One-to-Many
(*) ────── (*)    Many-to-Many

└──┬──┘            Hierarchy
   │
   ▼               Direction of dependency

[PK]               Primary Key
[FK]               Foreign Key
[UNIQUE]           Unique Constraint
[INDEX]            Performance Index
```

---

**These diagrams represent the database structure as of November 27, 2025**
