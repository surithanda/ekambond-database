-- =============================================
-- Procedure: admin_auth_logout
-- Purpose: Logout admin user and invalidate session
-- Parameters:
--   p_session_id: Session ID to invalidate
--   p_admin_id: Admin user ID
-- Returns: Success/error status
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_auth_logout`$$

CREATE PROCEDURE `admin_auth_logout`(
    IN p_session_id VARCHAR(128),
    IN p_admin_id INT
)
proc_label: BEGIN
    DECLARE v_session_exists INT DEFAULT 0;
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
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, activity_type)
        VALUES ('ERROR', 'admin_auth_logout failed: SQL Exception', CONCAT('admin_', p_admin_id), v_start_time, v_end_time, v_execution_time, 'ADMIN_LOGOUT_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            '48005' AS error_code,
            'Logout failed due to system error' AS error_message;
    END;
    
    -- Custom error handler
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SET v_end_time = NOW();
        SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
        
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, activity_type)
        VALUES ('ERROR', v_error_message, CONCAT('admin_', p_admin_id), v_start_time, v_end_time, v_execution_time, 'ADMIN_LOGOUT_ERROR');
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Check if session exists
    SELECT COUNT(*) INTO v_session_exists
    FROM admin_sessions
    WHERE session_id = p_session_id AND admin_id = p_admin_id AND is_active = 1;
    
    IF v_session_exists = 0 THEN
        SET v_error_code = '48006';
        SET v_error_message = 'Invalid or expired session';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Invalidate session
    UPDATE admin_sessions
    SET is_active = 0
    WHERE session_id = p_session_id AND admin_id = p_admin_id;
    
    -- Log successful logout
    SET v_end_time = NOW();
    SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
    
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, activity_type)
    VALUES ('INFO', CONCAT('Admin logout: admin_id=', p_admin_id), CONCAT('admin_', p_admin_id), v_start_time, v_end_time, v_execution_time, 'ADMIN_LOGOUT_SUCCESS');
    
    -- Insert audit log
    INSERT INTO admin_audit_log (admin_id, action_type, resource_type, resource_id)
    VALUES (p_admin_id, 'LOGOUT', 'ADMIN_SESSION', p_session_id);
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        'Logged out successfully' AS message;
    
END proc_label$$

DELIMITER ;
