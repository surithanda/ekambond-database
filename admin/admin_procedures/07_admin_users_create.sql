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
    IN p_created_by VARCHAR(45)
)
proc_label: BEGIN
    DECLARE v_admin_id INT;
    DECLARE v_username_exists INT DEFAULT 0;
    DECLARE v_email_exists INT DEFAULT 0;
    DECLARE v_start_time DATETIME;
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
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), p_created_by, v_start_time, NOW(), 'ADMIN_USER_CREATE_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 50001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to create admin user') AS error_message;
    END;
    
    -- Custom error handler
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
        VALUES ('ERROR', v_error_message, p_created_by, v_start_time, NOW(), 'ADMIN_USER_CREATE_ERROR');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Validate role
    IF p_role NOT IN ('viewer', 'approver', 'admin') THEN
        SET v_error_code = '50002';
        SET v_error_message = 'Invalid role. Must be viewer, approver, or admin';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if username already exists
    SELECT COUNT(*) INTO v_username_exists
    FROM admin_users
    WHERE username = p_username;
    
    IF v_username_exists > 0 THEN
        SET v_error_code = '50003';
        SET v_error_message = 'Username already exists';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if email already exists
    SELECT COUNT(*) INTO v_email_exists
    FROM admin_users
    WHERE email = p_email;
    
    IF v_email_exists > 0 THEN
        SET v_error_code = '50004';
        SET v_error_message = 'Email already exists';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
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
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        admin_id,
        username,
        email,
        role,
        is_active,
        created_at
    FROM admin_users
    WHERE admin_id = v_admin_id;
    
END proc_label$$

DELIMITER ;
