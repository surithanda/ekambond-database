-- =============================================
-- Procedure: admin_auth_verify_session
-- Purpose: Verify admin session validity
-- Parameters:
--   p_session_id: Session ID to verify
-- Returns: Admin details if session is valid
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_auth_verify_session`$$

CREATE PROCEDURE `admin_auth_verify_session`(
    IN p_session_id VARCHAR(128)
)
proc_label: BEGIN
    DECLARE v_admin_id INT;
    DECLARE v_is_active TINYINT(1);
    DECLARE v_expires_at DATETIME;
    DECLARE v_session_active TINYINT(1);
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
    
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Get session details
    SELECT 
        s.admin_id,
        s.is_active,
        s.expires_at,
        u.is_active
    INTO 
        v_admin_id,
        v_session_active,
        v_expires_at,
        v_is_active
    FROM admin_sessions s
    INNER JOIN admin_users u ON s.admin_id = u.admin_id
    WHERE s.session_id = p_session_id
    LIMIT 1;
    
    -- Check if session exists
    IF v_admin_id IS NULL THEN
        SET v_error_code = '48007';
        SET v_error_message = 'Invalid session';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if session is active
    IF v_session_active = 0 THEN
        SET v_error_code = '48008';
        SET v_error_message = 'Session has been terminated';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if session is expired
    IF v_expires_at < NOW() THEN
        -- Invalidate expired session
        UPDATE admin_sessions
        SET is_active = 0
        WHERE session_id = p_session_id;
        
        SET v_error_code = '48009';
        SET v_error_message = 'Session has expired';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if admin account is active
    IF v_is_active = 0 THEN
        SET v_error_code = '48010';
        SET v_error_message = 'Admin account is inactive';
        
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Update last activity
    UPDATE admin_sessions
    SET last_activity = NOW()
    WHERE session_id = p_session_id;
    
    -- Return admin details
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        u.admin_id,
        u.username,
        u.email,
        u.role,
        u.mfa_enabled,
        s.session_id,
        s.expires_at
    FROM admin_users u
    INNER JOIN admin_sessions s ON u.admin_id = s.admin_id
    WHERE s.session_id = p_session_id;
    
END proc_label$$

DELIMITER ;
