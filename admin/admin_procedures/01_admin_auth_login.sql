-- =============================================
-- Procedure: admin_auth_login
-- Purpose: Authenticate admin user and create session
-- Parameters:
--   p_username: Admin username or email
--   p_password_hash: Hashed password from client
--   p_ip_address: Client IP address
--   p_user_agent: Client user agent
-- Returns: Admin details with session token
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_auth_login`$$

CREATE PROCEDURE `admin_auth_login`(
    IN p_username VARCHAR(150),
    IN p_password_hash VARCHAR(255),
    IN p_ip_address VARCHAR(45),
    IN p_user_agent TEXT
)
proc_label: BEGIN
    DECLARE v_admin_id INT;
    DECLARE v_stored_password_hash VARCHAR(255);
    DECLARE v_is_active TINYINT(1);
    DECLARE v_failed_attempts INT;
    DECLARE v_locked_until DATETIME;
    DECLARE v_mfa_enabled TINYINT(1);
    DECLARE v_role VARCHAR(20);
    DECLARE v_session_id VARCHAR(128);
    DECLARE v_expires_at DATETIME;
    DECLARE v_log_id INT;
    DECLARE v_start_time DATETIME;
    DECLARE v_end_time DATETIME;
    DECLARE v_execution_time INT;
    DECLARE v_error_code VARCHAR(10);
    DECLARE v_error_message VARCHAR(255);
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET v_end_time = NOW();
        SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
        
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT,
            v_error_code = MYSQL_ERRNO;
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
        VALUES ('ERROR', 'admin_auth_login failed: SQL Exception', p_username, v_start_time, v_end_time, v_execution_time, p_ip_address, 'ADMIN_LOGIN_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            '48001' AS error_code,
            'Authentication failed due to system error' AS error_message;
    END;
    
    -- Custom error handler
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SET v_end_time = NOW();
        SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
        VALUES ('ERROR', v_error_message, p_username, v_start_time, v_end_time, v_execution_time, p_ip_address, 'ADMIN_LOGIN_ERROR');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Find admin user by username or email
    SELECT 
        admin_id, 
        password_hash, 
        is_active, 
        failed_login_attempts, 
        locked_until,
        mfa_enabled,
        role
    INTO 
        v_admin_id, 
        v_stored_password_hash, 
        v_is_active, 
        v_failed_attempts, 
        v_locked_until,
        v_mfa_enabled,
        v_role
    FROM admin_users
    WHERE (username = p_username OR email = p_username)
    LIMIT 1;
    
    -- Check if user exists
    IF v_admin_id IS NULL THEN
        SET v_error_code = '48002';
        SET v_error_message = 'Invalid username or password';
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
        VALUES ('WARNING', CONCAT('Failed login attempt for username: ', p_username), p_username, v_start_time, NOW(), 0, p_ip_address, 'ADMIN_LOGIN_FAILED');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if account is locked
    IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
        SET v_error_code = '48003';
        SET v_error_message = CONCAT('Account is locked until ', DATE_FORMAT(v_locked_until, '%Y-%m-%d %H:%i:%s'));
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
        VALUES ('WARNING', CONCAT('Login attempt on locked account: ', p_username), p_username, v_start_time, NOW(), 0, p_ip_address, 'ADMIN_LOGIN_LOCKED');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if account is active
    IF v_is_active = 0 THEN
        SET v_error_code = '48004';
        SET v_error_message = 'Account is inactive';
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
        VALUES ('WARNING', CONCAT('Login attempt on inactive account: ', p_username), p_username, v_start_time, NOW(), 0, p_ip_address, 'ADMIN_LOGIN_INACTIVE');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Verify password (Note: Password verification should be done in application layer)
    -- This is a simplified check - actual bcrypt comparison should be done in Node.js
    IF v_stored_password_hash != p_password_hash THEN
        -- Increment failed login attempts
        UPDATE admin_users 
        SET failed_login_attempts = failed_login_attempts + 1,
            locked_until = CASE 
                WHEN failed_login_attempts + 1 >= 5 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
                ELSE NULL
            END
        WHERE admin_id = v_admin_id;
        
        SET v_error_code = '48002';
        SET v_error_message = 'Invalid username or password';
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
        VALUES ('WARNING', CONCAT('Failed login - invalid password for: ', p_username), p_username, v_start_time, NOW(), 0, p_ip_address, 'ADMIN_LOGIN_INVALID_PASSWORD');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Generate session ID
    SET v_session_id = UUID();
    SET v_expires_at = DATE_ADD(NOW(), INTERVAL 8 HOUR);
    
    -- Create session
    INSERT INTO admin_sessions (session_id, admin_id, ip_address, user_agent, expires_at, is_active)
    VALUES (v_session_id, v_admin_id, p_ip_address, p_user_agent, v_expires_at, 1);
    
    -- Update admin user
    UPDATE admin_users 
    SET last_login = NOW(),
        failed_login_attempts = 0,
        locked_until = NULL
    WHERE admin_id = v_admin_id;
    
    -- Log successful login
    SET v_end_time = NOW();
    SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
    
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
    VALUES ('INFO', CONCAT('Successful admin login: ', p_username), p_username, v_start_time, v_end_time, v_execution_time, p_ip_address, 'ADMIN_LOGIN_SUCCESS');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id, ip_address, user_agent)
    VALUES (v_admin_id, 'LOGIN', 'ADMIN_SESSION', v_session_id, p_ip_address, p_user_agent);
    
    -- Return success with user details
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        v_admin_id AS admin_id,
        u.username,
        u.email,
        u.role,
        v_session_id AS session_id,
        v_expires_at AS expires_at,
        v_mfa_enabled AS mfa_enabled
    FROM admin_users u
    WHERE u.admin_id = v_admin_id;
    
END proc_label$$

DELIMITER ;
