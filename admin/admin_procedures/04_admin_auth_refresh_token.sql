-- =============================================
-- Procedure: admin_auth_refresh_token
-- Purpose: Refresh admin session token
-- Parameters:
--   p_session_id: Current session ID
--   p_admin_id: Admin user ID
-- Returns: New session details
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_auth_refresh_token`$$

CREATE PROCEDURE `admin_auth_refresh_token`(
    IN p_session_id VARCHAR(128),
    IN p_admin_id INT
)
proc_label: BEGIN
    DECLARE v_session_exists INT DEFAULT 0;
    DECLARE v_expires_at DATETIME;
    DECLARE v_new_expires_at DATETIME;
    DECLARE v_error_code VARCHAR(10);
    DECLARE v_error_message VARCHAR(255);
    DECLARE v_start_time DATETIME;
    
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
    
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    SET v_start_time = NOW();
    
    -- Check if session exists and is active
    SELECT COUNT(*) INTO v_session_exists
    FROM admin_sessions s
    INNER JOIN admin_users u ON s.admin_id = u.admin_id
    WHERE s.session_id = p_session_id 
      AND s.admin_id = p_admin_id 
      AND s.is_active = 1
      AND u.is_active = 1
      AND s.expires_at > NOW();
    
    IF v_session_exists = 0 THEN
        SET v_error_code = '48011';
        SET v_error_message = 'Invalid or expired session';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Extend session expiration
    SET v_new_expires_at = DATE_ADD(NOW(), INTERVAL 8 HOUR);
    
    UPDATE admin_sessions
    SET expires_at = v_new_expires_at,
        last_activity = NOW()
    WHERE session_id = p_session_id AND admin_id = p_admin_id;
    
    -- Log token refresh
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
    VALUES ('INFO', CONCAT('Token refreshed for admin_id=', p_admin_id), CONCAT('admin_', p_admin_id), v_start_time, NOW(), 'ADMIN_TOKEN_REFRESH');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id)
    VALUES (p_admin_id, 'TOKEN_REFRESH', 'ADMIN_SESSION', p_session_id);
    
    -- Return refreshed session details
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        u.admin_id,
        u.username,
        u.email,
        u.role,
        s.session_id,
        v_new_expires_at AS expires_at
    FROM admin_sessions s
    INNER JOIN admin_users u ON s.admin_id = u.admin_id
    WHERE s.session_id = p_session_id;
    
END proc_label$$

DELIMITER ;
