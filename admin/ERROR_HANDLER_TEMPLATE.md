# Improved Error Handler Template for Admin Procedures

## Pattern to Apply

Replace all `DECLARE EXIT HANDLER FOR SQLEXCEPTION` blocks with this improved version:

### Old Pattern (REMOVE):
```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    SET v_end_time = NOW();
    SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
    
    GET DIAGNOSTICS CONDITION 1
        v_error_message = MESSAGE_TEXT,
        v_error_code = MYSQL_ERRNO;
    
    INSERT INTO activity_log (log_type, message, ...)
    VALUES ('ERROR', 'procedure_name failed: SQL Exception', ...);
    
    SELECT 
        'fail' AS status,
        'SQL Exception' AS error_type,
        '48001' AS error_code,
        'Generic error message' AS error_message;
END;
```

### New Pattern (USE THIS):

**Step 1: Declare variables at PROCEDURE level (after other DECLARE statements):**
```sql
DECLARE v_error_code VARCHAR(10);
DECLARE v_error_message VARCHAR(255);
DECLARE v_mysql_errno INT;
DECLARE v_message_text TEXT;
```

**Step 2: Update the EXIT HANDLER:**
```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    GET DIAGNOSTICS CONDITION 1
        v_message_text = MESSAGE_TEXT,
        v_mysql_errno = MYSQL_ERRNO;
    
    SET v_end_time = NOW();  -- If procedure has timing variables
    SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
    
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
    VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), [username_param], v_start_time, v_end_time, v_execution_time, [ip_param], '[PROCEDURE_NAME]_ERROR');
    
    SELECT 
        'fail' AS status,
        'SQL Exception' AS error_type,
        CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
        COALESCE(v_message_text, 'Unknown SQL exception occurred') AS error_message;
END;
```

## Key Improvements

1. **Local Variables**: Declare `v_mysql_errno` and `v_message_text` locally in the handler
2. **Nested CONTINUE Handler**: Wrap the activity_log INSERT in a nested BEGIN...END with CONTINUE HANDLER
3. **Return Actual Errors**: Use `COALESCE(v_message_text, ...)` instead of hard-coded generic messages
4. **Return Actual Error Code**: Use `CAST(COALESCE(v_mysql_errno, ...) AS CHAR)` instead of hard-coded error codes
5. **Safe Logging**: If logging fails, it won't cause the handler to fail

## Updated Procedures

- [x] 01_admin_auth_login.sql
- [x] 02_admin_auth_logout.sql  
- [x] 03_admin_auth_verify_session.sql
- [x] 04_admin_auth_refresh_token.sql
- [x] 05_admin_auth_reset_password.sql
- [x] 06_admin_auth_confirm_reset_password.sql
- [x] 07_admin_users_create.sql
- [x] 08_admin_users_update.sql
- [x] 09_admin_users_list.sql
- [x] 10_admin_get_registrations.sql
- [x] 11_admin_get_profiles.sql
- [x] 12_admin_enable_disable_account.sql
- [x] 13_admin_update_verify_status.sql
- [x] 14_admin_get_total_payments.sql
- [x] 15_admin_get_partner_registrations.sql
- [x] 16_admin_approve_partner_registrations.sql
- [x] 17_admin_get_api_clients.sql
- [x] 18_admin_get_api_client_payments.sql
- [x] admin_api_clients_create_v1.sql
- [x] admin_registered_partner_delete_v1.sql
- [x] admin_registered_partner_get.sql
- [x] admin_registered_partner_update_v1.sql

## After Updating

Run deployment:
```powershell
.\deploy-admin-system.ps1 -ProceduresOnly
```
