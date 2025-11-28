# Admin System Deployment Guide

## Overview
This deployment script installs the admin system for the matrimony services platform, including authentication, user management, and operational capabilities.

## Prerequisites
- MySQL Server 8.0 or higher
- matrimony_services database must exist
- Windows PowerShell 5.1 or higher
- Appropriate MySQL user permissions (CREATE, DROP, ALTER, INSERT)

## Quick Start

### Option 1: Using PowerShell
```powershell
cd admin
.\deploy-admin-system.ps1
```

### Option 2: Using Batch File
```batch
cd admin
deploy-admin-system.bat
```

## What Gets Deployed

### Admin Tables (6 tables)
1. **admin_users** - Admin user accounts with roles (viewer, approver, admin)
2. **admin_sessions** - Session management with 8-hour expiration
3. **api_keys** - Enhanced API key management with expiration tracking
4. **notification_queue** - Email notification queue with retry logic
5. **admin_audit_log** - Comprehensive audit trail for all admin actions
6. **password_reset_tokens** - Secure password reset token management

### Admin Procedures (22 procedures)
- **Authentication (6)**: Login, logout, session management, password reset
- **User Management (3)**: Create, update, list admin users
- **Account Management (4)**: View registrations, enable/disable accounts, verify profiles
- **Partner Management (5)**: Approve/reject partners, manage partner data
- **Financial (2)**: Payment analytics and tracking
- **API Management (2)**: API client management

### Initial Data
- Default admin user:
  - Username: `admin`
  - Email: `admin@matrimony.com`
  - Password: `Admin@123` ⚠️ **Change immediately!**

## Deployment Options

### Standard Deployment (Full Install)
```powershell
.\deploy-admin-system.ps1
```
Deploys everything with default settings.

### Custom MySQL Credentials
```powershell
.\deploy-admin-system.ps1 -MySQLUser "myuser" -MySQLPassword "mypassword"
```

### Drop and Recreate Tables
```powershell
.\deploy-admin-system.ps1 -DropTables
```
⚠️ **Warning**: This will delete all admin tables and data!

### Schema Only (Tables + Data)
```powershell
.\deploy-admin-system.ps1 -SchemaOnly
```
Creates tables and initial data, skips procedures.

### Procedures Only
```powershell
.\deploy-admin-system.ps1 -ProceduresOnly
```
Creates/updates procedures, skips schema.

### Update Procedures Without Schema
```powershell
.\deploy-admin-system.ps1 -SkipSchema
```
Useful for updating procedures without affecting existing data.

### Reset Admin Password
```powershell
.\deploy-admin-system.ps1 -UpdatePassword
```
Resets the default admin password to `Admin@123`.

## Post-Deployment Steps

### 1. Change Default Password (Critical!)
**IMPORTANT**: Change the default admin password immediately!

```sql
USE matrimony_services;

-- Update password (use bcrypt hash from your application)
UPDATE admin_users 
SET password_hash = '$2b$10$YOUR_BCRYPT_HASH_HERE',
    failed_login_attempts = 0,
    locked_until = NULL
WHERE username = 'admin';
```

### 2. Create Additional Admin Users
Use the `admin_users_create` procedure:

```sql
CALL admin_users_create(
    'johndoe',                          -- username
    'john@example.com',                 -- email
    '$2b$10$BCRYPT_HASH',              -- password_hash
    'approver',                         -- role (viewer/approver/admin)
    'admin',                            -- created_by
    @error_code,
    @error_message
);

SELECT @error_code, @error_message;
```

### 3. Verify Deployment
```sql
-- Check all admin tables
SHOW TABLES LIKE 'admin%';
SHOW TABLES LIKE '%notification%';
SHOW TABLES LIKE '%api_keys%';
SHOW TABLES LIKE '%password_reset%';

-- Check procedures
SHOW PROCEDURE STATUS WHERE Db = 'matrimony_services' AND Name LIKE 'admin%';

-- Verify default admin user
SELECT admin_id, username, email, role, is_active, created_at 
FROM admin_users;

-- Check audit log table structure
DESCRIBE admin_audit_log;
```

## Role-Based Access Control

### Viewer Role
- Read-only access to the system
- Can view registrations, profiles, and partner applications
- Cannot modify any data
- Ideal for: Support staff, analysts

### Approver Role
- All viewer permissions
- Can approve/reject partner registrations
- Can verify profile information (personal, address, education, employment, photos)
- Cannot manage admin users or system settings
- Ideal for: Content moderators, verification team

### Admin Role
- Full system access
- Can create and manage admin users
- Can enable/disable user accounts
- All approver permissions
- Access to all system functions
- Ideal for: System administrators, technical leads

## File Structure
```
admin/
├── admin-schema.sql                   # Schema definition + initial data
├── update-admin-password.sql          # Password reset utility
├── deploy-admin-system.ps1            # Main deployment script
├── deploy-admin-system.bat            # Batch wrapper for convenience
├── README.md                          # This file
└── admin_procedures/                  # 22 stored procedures
    ├── 01_admin_auth_login.sql
    ├── 02_admin_auth_logout.sql
    ├── 03_admin_auth_verify_session.sql
    ├── 04_admin_auth_refresh_token.sql
    ├── 05_admin_auth_reset_password.sql
    ├── 06_admin_auth_confirm_reset_password.sql
    ├── 07_admin_users_create.sql
    ├── 08_admin_users_update.sql
    ├── 09_admin_users_list.sql
    ├── 10_admin_get_registrations.sql
    ├── 11_admin_get_profiles.sql
    ├── 12_admin_enable_disable_account.sql
    ├── 13_admin_update_verify_status.sql
    ├── 14_admin_get_total_payments.sql
    ├── 15_admin_get_partner_registrations.sql
    ├── 16_admin_approve_partner_registrations.sql
    ├── 17_admin_get_api_clients.sql
    ├── 18_admin_get_api_client_payments.sql
    ├── admin_api_clients_create_v1.sql
    ├── admin_eb_registered_partner_get.sql
    ├── admin_registered_partner_delete_v1.sql
    └── admin_registered_partner_update_v1.sql
```

## Security Best Practices

### 1. Password Management
- ✅ Always use bcrypt for password hashing
- ✅ Minimum 12 characters with complexity requirements
- ✅ Never store passwords in plain text
- ✅ Rotate passwords regularly

### 2. Session Management
- ✅ Sessions expire after 8 hours of inactivity
- ✅ Sessions are tied to IP address and user agent
- ✅ Failed login attempts trigger account lockout (5 attempts = 30 min lock)

### 3. API Key Management
- ✅ Set expiration dates for all API keys
- ✅ Rotate keys regularly (recommended: every 90 days)
- ✅ Track usage with `usage_count` and `last_used` fields
- ✅ Deactivate unused keys

### 4. Audit Trail
- ✅ All admin actions are logged to `admin_audit_log`
- ✅ Review audit logs regularly for suspicious activity
- ✅ Retain logs for compliance requirements

### 5. Network Security
- ✅ Restrict MySQL access to trusted networks
- ✅ Use SSL/TLS for database connections
- ✅ Implement firewall rules

### 6. Multi-Factor Authentication (MFA)
- ✅ MFA infrastructure is ready (`mfa_secret`, `mfa_enabled` columns)
- ✅ Implement TOTP (Time-based One-Time Password) in your application layer

## Troubleshooting

### MySQL Binary Not Found
**Error**: `MySQL binary not found at: C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe`

**Solution**: Update the `$MySQLBin` variable in `deploy-admin-system.ps1`:
```powershell
$MySQLBin = "C:\Your\MySQL\Path\bin\mysql.exe"
```

### Database Does Not Exist
**Error**: `Database 'matrimony_services' does not exist`

**Solution**: Run the main database deployment first:
```powershell
cd ..\Deploy
.\deploy-prod-database.ps1 -CreateDatabase
```

### Permission Denied
**Error**: `Access denied for user`

**Solution**: Grant appropriate privileges:
```sql
GRANT ALL PRIVILEGES ON matrimony_services.* TO 'your_user'@'localhost';
FLUSH PRIVILEGES;
```

### Table Already Exists
**Error**: `Table 'admin_users' already exists`

**Solution**: Use `-DropTables` to remove existing tables:
```powershell
.\deploy-admin-system.ps1 -DropTables
```

### Procedure Creation Failed
**Error**: Failed to execute procedure file

**Solution**: Check for syntax errors or use `-ProceduresOnly` to redeploy just procedures:
```powershell
.\deploy-admin-system.ps1 -ProceduresOnly
```

## Integration Examples

### Node.js/Express Example
```javascript
const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');

// Admin login
async function adminLogin(username, password, ipAddress, userAgent) {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'password',
    database: 'matrimony_services'
  });

  // Hash password with bcrypt
  const passwordHash = await bcrypt.hash(password, 10);

  // Call stored procedure
  const [results] = await connection.execute(
    'CALL admin_auth_login(?, ?, ?, ?, @error_code, @error_message)',
    [username, passwordHash, ipAddress, userAgent]
  );

  // Get output parameters
  const [[{ error_code, error_message }]] = await connection.execute(
    'SELECT @error_code as error_code, @error_message as error_message'
  );

  await connection.end();

  if (error_code) {
    throw new Error(error_message);
  }

  return results[0][0]; // Return session data
}

// Verify session
async function verifySession(sessionId, ipAddress) {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'password',
    database: 'matrimony_services'
  });

  const [results] = await connection.execute(
    'CALL admin_auth_verify_session(?, ?, @error_code, @error_message)',
    [sessionId, ipAddress]
  );

  await connection.end();

  return results[0][0];
}
```

### Python Example
```python
import mysql.connector
import bcrypt

def admin_login(username, password, ip_address, user_agent):
    conn = mysql.connector.connect(
        host='localhost',
        user='root',
        password='password',
        database='matrimony_services'
    )
    
    cursor = conn.cursor(dictionary=True)
    
    # Hash password
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    
    # Call procedure
    cursor.callproc('admin_auth_login', [
        username,
        password_hash,
        ip_address,
        user_agent,
        None,  # @error_code
        None   # @error_message
    ])
    
    # Get results
    for result in cursor.stored_results():
        session_data = result.fetchone()
    
    cursor.close()
    conn.close()
    
    return session_data
```

## Maintenance

### Regular Tasks
1. **Weekly**: Review audit logs for suspicious activity
2. **Monthly**: Check for expired API keys and sessions
3. **Quarterly**: Rotate API keys and review admin user accounts
4. **Annually**: Full security audit

### Backup Strategy
```bash
# Backup admin tables
mysqldump -u root -p matrimony_services \
  admin_users admin_sessions api_keys notification_queue \
  admin_audit_log password_reset_tokens \
  > admin_backup_$(date +%Y%m%d).sql
```

### Update Procedures
To update procedures without affecting data:
```powershell
.\deploy-admin-system.ps1 -ProceduresOnly
```

## Support & Documentation
- Review procedure comments for detailed parameter documentation
- Check `admin_audit_log` for deployment events
- Refer to error_codes.md for error code meanings

## License
Internal use only - Matrimony Services Platform
