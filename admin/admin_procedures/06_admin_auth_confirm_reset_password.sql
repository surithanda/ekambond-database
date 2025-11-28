-- =============================================
-- Procedure: admin_auth_confirm_reset_password
-- Purpose: Confirm password reset with token
-- Parameters:
--   p_token: Reset token
--   p_new_password_hash: New hashed password
-- Returns: Success/error status
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_auth_confirm_reset_password`$$

CREATE PROCEDURE `admin_auth_confirm_reset_password`(
    IN p_token VARCHAR(128),
    IN p_new_password_hash VARCHAR(255),
    OUT p_error_code VARCHAR(10),
    OUT p_error_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_admin_id INT;
    DECLARE v_token_id INT;
    DECLARE v_expires_at DATETIME;
    DECLARE v_is_used TINYINT(1);
    DECLARE v_start_time DATETIME;
    
    SET v_start_time = NOW();
    SET p_error_code = NULL;
    SET p_error_message = NULL;
    
    -- Find reset token
    SELECT token_id, admin_id, expires_at, is_used
    INTO v_token_id, v_admin_id, v_expires_at, v_is_used
    FROM password_reset_tokens
    WHERE token = p_token
    LIMIT 1;
    
    -- Check if token exists
    IF v_token_id IS NULL THEN
        SET p_error_code = '48013';
        SET p_error_message = 'Invalid reset token';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if token is already used
    IF v_is_used = 1 THEN
        SET p_error_code = '48014';
        SET p_error_message = 'Reset token has already been used';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if token is expired
    IF v_expires_at < NOW() THEN
        SET p_error_code = '48015';
        SET p_error_message = 'Reset token has expired';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Update password
    UPDATE admin_users
    SET password_hash = p_new_password_hash,
        failed_login_attempts = 0,
        locked_until = NULL,
        updated_at = NOW()
    WHERE admin_id = v_admin_id;
    
    -- Mark token as used
    UPDATE password_reset_tokens
    SET is_used = 1
    WHERE token_id = v_token_id;
    
    -- Invalidate all active sessions for this admin
    UPDATE admin_sessions
    SET is_active = 0
    WHERE admin_id = v_admin_id AND is_active = 1;
    
    -- Log password reset
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
    VALUES ('INFO', CONCAT('Password reset completed for admin_id=', v_admin_id), CONCAT('admin_', v_admin_id), v_start_time, NOW(), 'ADMIN_PASSWORD_RESET_COMPLETE');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id)
    VALUES (v_admin_id, 'PASSWORD_RESET_COMPLETE', 'ADMIN_USER', v_admin_id);
    
    -- Send notification
    INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
    SELECT 
        email,
        'Password Reset Successful',
        'Your password has been successfully reset. All active sessions have been terminated.',
        'PASSWORD_RESET_COMPLETE',
        'system'
    FROM admin_users
    WHERE admin_id = v_admin_id;
    
    -- Return success
    SELECT 
        'SUCCESS' AS status,
        'Password has been reset successfully' AS message,
        NULL AS error_code,
        NULL AS error_message;
    
END proc_label$$

DELIMITER ;
