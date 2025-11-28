# Matrimony Services Database Documentation

## 📚 Documentation Index

Welcome to the complete database documentation for the Matrimony Services platform. This documentation is designed for developers, data engineers, and database administrators.

---

## 📖 Documentation Files

### 1. [DATABASE_OVERVIEW.md](./DATABASE_OVERVIEW.md)
**Start here for a high-level understanding**

Covers:
- Purpose and key features
- Database architecture and design principles
- Module organization
- Security features
- Performance optimization
- Table and procedure statistics

**Best for**: Project managers, architects, new developers

---

### 2. [TABLE_REFERENCE.md](./TABLE_REFERENCE.md)
**Complete reference for all database tables**

Covers:
- Quick reference table with all 42 tables
- Detailed schema for each table
- Column descriptions and data types
- Indexes and constraints
- Relationships and foreign keys
- Common query patterns

**Best for**: Data engineers, database developers, report writers

---

### 3. [PROCEDURES_REFERENCE.md](./PROCEDURES_REFERENCE.md)
**Complete reference for all 85+ stored procedures**

Covers:
- Procedure inventory organized by module
- Detailed parameters and return values
- Validation logic and business rules
- Error codes by procedure
- Usage examples and test cases
- Standard patterns and conventions

**Best for**: Backend developers, API developers, QA engineers

---

### 4. [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md)
**Hands-on guide to get started quickly**

Covers:
- Database setup instructions
- Common operations with code examples
- User registration and profile creation
- Search and matching workflows
- Partner integration steps
- Error handling patterns
- Testing checklist
- Quick reference card

**Best for**: New developers, contractors, integration partners

---

### 5. [error_codes.md](./error_codes.md)
**Complete error code reference**

Covers:
- Error code ranges by module
- Detailed description of each error
- Error handling guidelines
- SQLSTATE information

**Best for**: All developers, support engineers, QA

---

## 🚀 Quick Navigation

### I'm a New Developer
1. Start with [DATABASE_OVERVIEW.md](./DATABASE_OVERVIEW.md) to understand the system
2. Read [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md) for hands-on examples
3. Reference [PROCEDURES_REFERENCE.md](./PROCEDURES_REFERENCE.md) as you code
4. Keep [error_codes.md](./error_codes.md) handy for debugging

### I'm Working on a Specific Feature
1. Check [TABLE_REFERENCE.md](./TABLE_REFERENCE.md) for table schemas
2. Find relevant procedures in [PROCEDURES_REFERENCE.md](./PROCEDURES_REFERENCE.md)
3. Use [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md) for code examples

### I'm Integrating as a Partner
1. Read the Partner Integration section in [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md)
2. Review API procedures in [PROCEDURES_REFERENCE.md](./PROCEDURES_REFERENCE.md)
3. Understand error handling from [error_codes.md](./error_codes.md)

### I'm a Data Engineer
1. Study [TABLE_REFERENCE.md](./TABLE_REFERENCE.md) for complete schema
2. Review relationships in [DATABASE_OVERVIEW.md](./DATABASE_OVERVIEW.md)
3. Check indexing strategy in [DATABASE_OVERVIEW.md](./DATABASE_OVERVIEW.md)

---

## 🗂️ Database Structure at a Glance

### Tables (42 total)

```
Authentication & Account (4)
├── account
├── login
├── login_history
└── activity_log

Profile Management (11)
├── profile_personal
├── profile_address
├── profile_contact
├── profile_education
├── profile_employment
├── profile_family_reference
├── profile_hobby_interest
├── profile_lifestyle
├── profile_photo
├── profile_property
└── profile_search_preference

Social Features (4)
├── profile_views
├── profile_favorites
├── profile_contacted
└── profile_saved_for_later

Stripe Integration (18)
├── stripe_customers
├── stripe_subscriptions
├── stripe_payment_methods
├── stripe_payment_intents
├── stripe_charges
└── ... (13 more)

Partner Management (2)
├── registered_partner
└── api_clients

Reference Data (3)
├── lookup_table
├── country
└── state, zip_code
```

### Stored Procedures (85+ total)

```
Authentication (7)
- Account creation, login validation
- OTP verification, password reset

Profile Management (40+)
- CRUD for all profile components
- Complete profile retrieval

Social Features (12)
- Views, favorites, contacts, saved

Search & Matching (4)
- Search preferences, profile search

Partner Management (4)
- Partner registration, API clients

Utilities (6)
- Lookups, logging, account details

Stripe Sync (10+)
- Webhook data synchronization
```

---

## 🔑 Key Concepts

### 1. Profile Components
Profiles are modular - each component (education, employment, photos) is stored in a separate table with one-to-many relationship to `profile_personal`.

### 2. Self-Referencing Social Tables
Tables like `profile_views` and `profile_favorites` have two profile references: `from_profile_id` (actor) and `to_profile_id` (target).

### 3. Soft Deletes
Most tables support soft deletion via `is_active`, `is_deleted`, or `softdelete` flags. Data is never permanently removed.

### 4. Stored Procedure Pattern
All data access goes through stored procedures which:
- Validate input parameters
- Handle errors with custom codes
- Log activities and errors
- Return standardized responses

### 5. Error Code System
Custom error codes in format `NNNNN_DESCRIPTION` where NNNNN is in range 45000-69999. Each module has its own 1000-code range.

### 6. Lookup Tables
The `lookup_table` provides reference data for dropdowns and categories. Always query it for current values rather than hardcoding IDs.

---

## 💡 Common Use Cases

### User Registration Flow
```
eb_account_login_create
  → Creates account + login
  → Returns account_id and account_code
    → eb_profile_personal_create
      → Creates core profile
        → eb_profile_education_create
        → eb_profile_employment_create
        → eb_profile_photo_create
        → Profile complete!
```

### Profile Search Flow
```
eb_profile_search_preference_create
  → Save search criteria
    → eb_profile_search_get
      → Returns matching profiles
        → User clicks profile
          → eb_profile_views_create (track view)
            → User actions:
              → eb_profile_favorites_create
              → eb_profile_contacted_create
              → eb_profile_saved_for_later_create
```

### Payment Flow
```
User subscribes on Stripe
  → Stripe webhook fires
    → Application receives webhook
      → stripe_sync procedures
        → Update stripe_customers
        → Update stripe_subscriptions
        → Update stripe_invoices
        → Update account subscription status
```

---

## 🛠️ Development Guidelines

### Adding New Features

1. **Design Phase**
   - Identify required tables and relationships
   - Define error codes (allocate range)
   - Document business rules

2. **Implementation Phase**
   - Create table SQL in `/database/tables/`
   - Create stored procedures in `/database/procedures/`
   - Add error codes to `error_codes.md`
   - Write tests

3. **Documentation Phase**
   - Update relevant documentation files
   - Add examples to QUICK_START_GUIDE.md
   - Update this README if needed

### Naming Conventions

**Tables**: `lowercase_with_underscores`
```sql
profile_personal
profile_education
stripe_subscriptions
```

**Procedures**: `[prefix]_[entity]_[action]`
```sql
eb_profile_personal_create      -- External facing
admin_api_clients_create        -- Admin operations
lkp_get_LookupData             -- Lookup queries
common_log_error               -- Utility functions
```

**Columns**: `lowercase_with_underscores`
```sql
account_id
first_name
created_date
is_active
```

**Error Codes**: `NNNNN_UPPERCASE_DESCRIPTION`
```sql
45001_MISSING_EMAIL
46009_INVALID_AGE
58006_DUPLICATE_FAVORITE
```

---

## 🔒 Security Best Practices

### 1. Never Store Plain Text Passwords
Hash passwords in application layer before calling `eb_account_login_create`.

### 2. Validate Input
Double validation - once in application, once in stored procedure.

### 3. Use Parameterized Queries
Always use stored procedures with parameters. Never concatenate SQL strings.

### 4. Protect API Keys
API keys in `api_clients` table should be hashed or encrypted. Return plain text only once during creation.

### 5. Log Sensitive Operations
Use `common_log_activity` for account changes, profile updates, payments.

### 6. Implement Rate Limiting
Application layer should rate limit login attempts, OTP requests, API calls.

---

## 📊 Performance Considerations

### Indexing Strategy
- All primary keys indexed automatically
- Foreign keys indexed for JOINs
- Unique constraints on email, account_code, api_key
- Composite indexes on frequently queried column combinations

### Query Optimization
- Use stored procedures (pre-compiled execution plans)
- Avoid SELECT * - specify needed columns
- Use LIMIT for large result sets
- Partition large tables (activity_log, login_history)

### Caching Strategy
- Cache lookup table data (changes infrequently)
- Cache country/state lists
- Cache frequently accessed profiles
- Use Redis or similar for session data

---

## 🧪 Testing

### Unit Tests
Test each stored procedure independently:
- Valid input cases
- Invalid input cases
- Boundary conditions
- Error conditions

### Integration Tests
Test workflows:
- Complete registration flow
- Profile creation with all components
- Search and interaction flow
- Payment processing flow

### Performance Tests
- Load test search with 100k+ profiles
- Concurrent user registrations
- High-volume profile viewing
- Stress test API endpoints

### Security Tests
- SQL injection attempts
- Invalid authentication
- Parameter tampering
- Rate limiting

---

## 📈 Monitoring

### Key Metrics to Track

**Database Performance**
- Query execution times
- Connection pool usage
- Table sizes and growth
- Index usage statistics

**Application Metrics**
- User registrations per day
- Profile views per day
- Search queries per day
- Active subscriptions

**Error Monitoring**
- Error frequency by error_code
- Failed login attempts
- Failed Stripe webhooks
- Database connection errors

---

## 🔧 Maintenance

### Daily Tasks
- Review `activity_log` for errors
- Monitor database performance
- Check backup completion

### Weekly Tasks
- Archive old activity logs (keep 90 days)
- Review slow query log
- Check database size and growth trends

### Monthly Tasks
- Update table statistics: `ANALYZE TABLE`
- Review and optimize indexes
- Update lookup table data if needed
- Review security logs

### Quarterly Tasks
- Database performance audit
- Security review
- Backup/restore test
- Documentation updates

---

## 🆘 Troubleshooting

### Common Issues

**Issue**: "Duplicate email" error
**Solution**: Check `account` table for existing email. Use forgot password flow if user already registered.

**Issue**: Age validation error
**Solution**: User must be 20+ years old. Check birth_date parameter.

**Issue**: Profile not found
**Solution**: Ensure profile was created successfully after account creation. Check `profile_personal` table.

**Issue**: Search returns no results
**Solution**: Check search criteria - may be too restrictive. Use -1 to ignore specific filters.

**Issue**: Stripe webhook fails
**Solution**: Check `stripe_events` table for webhook data. Re-process manually if needed.

---

## 📞 Support

### Getting Help

**Database Schema Questions**
→ See [TABLE_REFERENCE.md](./TABLE_REFERENCE.md)

**Stored Procedure Usage**
→ See [PROCEDURES_REFERENCE.md](./PROCEDURES_REFERENCE.md)

**Error Code Meanings**
→ See [error_codes.md](./error_codes.md)

**Implementation Examples**
→ See [QUICK_START_GUIDE.md](./QUICK_START_GUIDE.md)

**Architecture Questions**
→ See [DATABASE_OVERVIEW.md](./DATABASE_OVERVIEW.md)

---

## 📝 Change Log

### Version History

**v1.0 - Initial Release**
- Core authentication and account management
- Profile management with 11 components
- Social features (views, favorites, contacts)
- Search and matching functionality
- Stripe payment integration
- Partner API management
- Reference data tables

---

## 🎯 Roadmap

### Planned Enhancements
- [ ] Advanced search with AI-based matching
- [ ] Real-time messaging system
- [ ] Video call integration
- [ ] Profile verification system
- [ ] Multi-language support
- [ ] Mobile app optimizations
- [ ] Analytics dashboard tables
- [ ] Recommendation engine

---

## 📄 License & Usage

This database schema and documentation is proprietary to the Matrimony Services platform.

**For Internal Use Only**
- Development team members
- Authorized contractors
- Approved partners (with signed agreement)

**Restrictions**
- Do not share outside organization
- Do not use for competing services
- Maintain data privacy and security

---

## ✅ Quick Checklist for New Developers

Before you start coding, make sure you've:

- [ ] Read DATABASE_OVERVIEW.md
- [ ] Reviewed TABLE_REFERENCE.md for tables you'll use
- [ ] Read PROCEDURES_REFERENCE.md for procedures you'll call
- [ ] Set up local database with test data
- [ ] Understand error code system
- [ ] Know how to use stored procedures
- [ ] Understand the authentication flow
- [ ] Know where to log activities and errors

---

**Last Updated**: November 27, 2025  
**Documentation Version**: 1.0  
**Database Version**: MySQL 5.7+ / MariaDB 10.3+

---

## 🎓 Learning Path

### Week 1: Fundamentals
- Day 1-2: Read DATABASE_OVERVIEW.md and understand architecture
- Day 3-4: Study TABLE_REFERENCE.md, focus on core tables
- Day 5: Work through QUICK_START_GUIDE.md examples

### Week 2: Deep Dive
- Day 1-2: Master authentication procedures
- Day 3-4: Master profile management procedures
- Day 5: Practice with search and social features

### Week 3: Advanced Topics
- Day 1-2: Stripe integration and webhooks
- Day 3-4: Partner API integration
- Day 5: Performance optimization and testing

### Week 4: Production Ready
- Day 1-2: Error handling and logging
- Day 3-4: Security best practices
- Day 5: Deploy and monitor

---

**Happy Coding! 🚀**
