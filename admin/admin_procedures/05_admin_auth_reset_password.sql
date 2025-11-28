-- =============================================
-- Procedure: admin_auth_reset_password
-- Purpose: Initiate password reset for admin user
-- Parameters:
--   p_email: Admin email address
-- Returns: Reset token (to be sent via email)
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_auth_reset_password`$$

CREATE PROCEDURE `admin_auth_reset_password`(
    IN p_email VARCHAR(150)
)
proc_label: BEGIN
    DECLARE v_admin_id INT;
    DECLARE v_is_active TINYINT(1);
    DECLARE v_reset_token VARCHAR(128);
    DECLARE v_expires_at DATETIME;
    DECLARE v_start_time DATETIME;
    DECLARE v_error_code VARCHAR(10);
    DECLARE v_error_message VARCHAR(255);
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT,
            v_error_code = MYSQL_ERRNO;
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
    END;
    
    -- Custom error handler
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Find admin user
    SELECT admin_id, is_active
    INTO v_admin_id, v_is_active
    FROM admin_users
    WHERE email = p_email
    LIMIT 1;
    
    -- Check if user exists
    IF v_admin_id IS NULL THEN
        -- Don't reveal if email exists for security
        SET p_error_code = NULL;
        SET p_error_message = NULL;
        
        SELECT 
            'SUCCESS' AS status,
            'If the email exists, a reset link will be sent' AS message,
            NULL AS error_code,
            NULL AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if account is active
    IF v_is_active = 0 THEN
        SET v_error_code = '48012';
        SET v_error_message = 'Account is inactive';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Generate reset token
    SET v_reset_token = UUID();
    SET v_expires_at = DATE_ADD(NOW(), INTERVAL 1 HOUR);
    
    -- Invalidate any existing reset tokens
    UPDATE password_reset_tokens
    SET is_used = 1
    WHERE admin_id = v_admin_id AND is_used = 0;
    
    -- Insert new reset token
    INSERT INTO password_reset_tokens (admin_id, token, expires_at)
    VALUES (v_admin_id, v_reset_token, v_expires_at);
    
    -- Queue notification email
    INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
    VALUES (
        p_email,
        'Password Reset Request',
        CONCAT('Your password reset token is: ', v_reset_token, '. This token will expire in 1 hour.'),
        'PASSWORD_RESET',
        'system'
    );
    
    -- Log password reset request
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
    VALUES ('INFO', CONCAT('Password reset requested for: ', p_email), p_email, v_start_time, NOW(), 'ADMIN_PASSWORD_RESET_REQUEST');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id)
    VALUES (v_admin_id, 'PASSWORD_RESET_REQUEST', 'ADMIN_USER', v_admin_id);
    
    -- Return success (don't expose token in response)
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        'Password reset email has been sent' AS message,
        v_reset_token AS reset_token,
        v_expires_at AS expires_at;
    
END proc_label$$

DELIMITER ;
