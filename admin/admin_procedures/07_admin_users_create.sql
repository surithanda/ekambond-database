-- =============================================
-- Procedure: admin_users_create
-- Purpose: Create new admin user
-- Parameters:
--   p_username: Username
--   p_email: Email address
--   p_password_hash: Hashed password
--   p_role: User role (viewer, approver, admin)
--   p_created_by: Admin who created this user
-- Returns: New admin user details
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_users_create`$$

CREATE PROCEDURE `admin_users_create`(
    IN p_username VARCHAR(50),
    IN p_email VARCHAR(150),
    IN p_password_hash VARCHAR(255),
    IN p_role VARCHAR(20),
    IN p_created_by VARCHAR(45),
    OUT p_error_code VARCHAR(10),
    OUT p_error_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_admin_id INT;
    DECLARE v_username_exists INT DEFAULT 0;
    DECLARE v_email_exists INT DEFAULT 0;
    DECLARE v_start_time DATETIME;
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
        VALUES ('ERROR', 'admin_users_create failed: SQL Exception', p_created_by, v_start_time, NOW(), 'ADMIN_USER_CREATE_ERROR');
        
        SET p_error_code = '50001';
        SET p_error_message = 'Failed to create admin user due to system error';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET p_error_code = NULL;
    SET p_error_message = NULL;
    
    -- Validate role
    IF p_role NOT IN ('viewer', 'approver', 'admin') THEN
        SET p_error_code = '50002';
        SET p_error_message = 'Invalid role. Must be viewer, approver, or admin';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if username already exists
    SELECT COUNT(*) INTO v_username_exists
    FROM admin_users
    WHERE username = p_username;
    
    IF v_username_exists > 0 THEN
        SET p_error_code = '50003';
        SET p_error_message = 'Username already exists';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if email already exists
    SELECT COUNT(*) INTO v_email_exists
    FROM admin_users
    WHERE email = p_email;
    
    IF v_email_exists > 0 THEN
        SET p_error_code = '50004';
        SET p_error_message = 'Email already exists';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Insert new admin user
    INSERT INTO admin_users (username, email, password_hash, role, is_active, created_by)
    VALUES (p_username, p_email, p_password_hash, p_role, 1, p_created_by);
    
    SET v_admin_id = LAST_INSERT_ID();
    
    -- Log admin user creation
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
    VALUES ('INFO', CONCAT('Admin user created: ', p_username, ' (ID: ', v_admin_id, ')'), p_created_by, v_start_time, NOW(), 'ADMIN_USER_CREATED');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id, action_details)
    VALUES (
        (SELECT admin_id FROM admin_users WHERE username = p_created_by LIMIT 1),
        'CREATE_ADMIN_USER',
        'ADMIN_USER',
        v_admin_id,
        JSON_OBJECT('username', p_username, 'email', p_email, 'role', p_role)
    );
    
    -- Queue welcome notification
    INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
    VALUES (
        p_email,
        'Welcome to Admin Portal',
        CONCAT('Your admin account has been created. Username: ', p_username, '. Please login and change your password.'),
        'ADMIN_WELCOME',
        p_created_by
    );
    
    -- Return new admin user details
    SELECT 
        admin_id,
        username,
        email,
        role,
        is_active,
        created_at,
        NULL AS error_code,
        NULL AS error_message
    FROM admin_users
    WHERE admin_id = v_admin_id;
    
END proc_label$$

DELIMITER ;
