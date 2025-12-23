-- =============================================
-- Procedure: admin_users_update
-- Purpose: Update admin user details
-- Parameters:
--   p_admin_id: Admin ID to update
--   p_email: New email (optional)
--   p_role: New role (optional)
--   p_is_active: Active status (optional)
--   p_mfa_enabled: MFA status (optional)
--   p_updated_by: Admin who made the update
-- Returns: Updated admin user details
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_users_update`$$

CREATE PROCEDURE `admin_users_update`(
    IN p_admin_id INT,
    IN p_email VARCHAR(150),
    IN p_role VARCHAR(20),
    IN p_is_active TINYINT(1),
    IN p_mfa_enabled TINYINT(1),
    IN p_updated_by VARCHAR(45)
)
proc_label: BEGIN
    DECLARE v_admin_exists INT DEFAULT 0;
    DECLARE v_email_exists INT DEFAULT 0;
    DECLARE v_old_role VARCHAR(20);
    DECLARE v_old_is_active TINYINT(1);
    DECLARE v_start_time DATETIME;
    DECLARE v_changes JSON;
    DECLARE v_error_code VARCHAR(10);
    DECLARE v_error_message VARCHAR(255);
    DECLARE v_mysql_errno INT;
    DECLARE v_message_text TEXT;
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_message_text = MESSAGE_TEXT,
            v_mysql_errno = MYSQL_ERRNO;
        
        INSERT INTO activity_log (log_type, message, activity_type)
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_USER_UPDATE_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to update admin user') AS error_message;
    END;
    
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Check if admin exists
    SELECT COUNT(*), MAX(role), MAX(is_active)
    INTO v_admin_exists, v_old_role, v_old_is_active
    FROM admin_users
    WHERE admin_id = p_admin_id;
    
    IF v_admin_exists = 0 THEN
        SET v_error_code = '50005';
        SET v_error_message = 'Admin user not found';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Validate role if provided
    IF p_role IS NOT NULL AND p_role NOT IN ('viewer', 'approver', 'admin') THEN
        SET v_error_code = '50002';
        SET v_error_message = 'Invalid role. Must be viewer, approver, or admin';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if email already exists (if changing email)
    IF p_email IS NOT NULL THEN
        SELECT COUNT(*) INTO v_email_exists
        FROM admin_users
        WHERE email = p_email AND admin_id != p_admin_id;
        
        IF v_email_exists > 0 THEN
            SET v_error_code = '50004';
            SET v_error_message = 'Email already exists';
            SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
            LEAVE proc_label;
        END IF;
    END IF;
    
    -- Build changes JSON
    SET v_changes = JSON_OBJECT();
    
    IF p_email IS NOT NULL THEN
        SET v_changes = JSON_SET(v_changes, '$.email', p_email);
    END IF;
    
    IF p_role IS NOT NULL THEN
        SET v_changes = JSON_SET(v_changes, '$.role', p_role);
    END IF;
    
    IF p_is_active IS NOT NULL THEN
        SET v_changes = JSON_SET(v_changes, '$.is_active', p_is_active);
    END IF;
    
    IF p_mfa_enabled IS NOT NULL THEN
        SET v_changes = JSON_SET(v_changes, '$.mfa_enabled', p_mfa_enabled);
    END IF;
    
    -- Update admin user
    UPDATE admin_users
    SET 
        email = COALESCE(p_email, email),
        role = COALESCE(p_role, role),
        is_active = COALESCE(p_is_active, is_active),
        mfa_enabled = COALESCE(p_mfa_enabled, mfa_enabled),
        updated_at = NOW()
    WHERE admin_id = p_admin_id;
    
    -- If account is deactivated, invalidate all sessions
    IF p_is_active = 0 AND v_old_is_active = 1 THEN
        UPDATE admin_sessions
        SET is_active = 0
        WHERE admin_id = p_admin_id AND is_active = 1;
    END IF;
    
    -- Log admin user update
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
    VALUES ('INFO', CONCAT('Admin user updated: admin_id=', p_admin_id), p_updated_by, v_start_time, NOW(), 'ADMIN_USER_UPDATED');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id, action_details)
    VALUES (
        (SELECT admin_id FROM admin_users WHERE username = p_updated_by LIMIT 1),
        'UPDATE_ADMIN_USER',
        'ADMIN_USER',
        p_admin_id,
        v_changes
    );
    
    -- Send notification if role or status changed
    IF (p_role IS NOT NULL AND p_role != v_old_role) OR (p_is_active IS NOT NULL AND p_is_active != v_old_is_active) THEN
        INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
        SELECT 
            email,
            'Account Update Notification',
            CONCAT('Your admin account has been updated. Role: ', role, ', Status: ', IF(is_active = 1, 'Active', 'Inactive')),
            'ADMIN_ACCOUNT_UPDATE',
            p_updated_by
        FROM admin_users
        WHERE admin_id = p_admin_id;
    END IF;
    
    -- Return updated admin user details
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        admin_id,
        username,
        email,
        role,
        is_active,
        mfa_enabled,
        last_login,
        created_at,
        updated_at
    FROM admin_users
    WHERE admin_id = p_admin_id;
    
END proc_label$$

DELIMITER ;
