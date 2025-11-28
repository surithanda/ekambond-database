-- =============================================
-- Procedure: admin_users_list
-- Purpose: List admin users with filters and pagination
-- Parameters:
--   p_role: Filter by role (optional)
--   p_is_active: Filter by active status (optional)
--   p_search: Search by username or email (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: List of admin users with pagination info
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_users_list`$$

CREATE PROCEDURE `admin_users_list`(
    IN p_role VARCHAR(20),
    IN p_is_active TINYINT(1),
    IN p_search VARCHAR(150),
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    DECLARE v_total_count INT DEFAULT 0;
    DECLARE v_error_code VARCHAR(10);
    DECLARE v_error_message VARCHAR(255);
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT,
            v_error_code = MYSQL_ERRNO;
        SELECT 'fail' AS status, 'SQL Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM admin_users
    WHERE 
        (p_role IS NULL OR role = p_role)
        AND (p_is_active IS NULL OR is_active = p_is_active)
        AND (p_search IS NULL OR username LIKE CONCAT('%', p_search, '%') OR email LIKE CONCAT('%', p_search, '%'));
    
    -- Return admin users list
    SELECT 
        u.admin_id,
        u.username,
        u.email,
        u.role,
        u.is_active,
        u.last_login,
        u.failed_login_attempts,
        u.locked_until,
        u.mfa_enabled,
        u.created_at,
        u.updated_at,
        u.created_by,
        COUNT(DISTINCT s.session_id) AS active_sessions,
        v_total_count AS total_count,
        p_limit AS page_limit,
        p_offset AS page_offset
    FROM admin_users u
    LEFT JOIN admin_sessions s ON u.admin_id = s.admin_id AND s.is_active = 1 AND s.expires_at > NOW()
    WHERE 
        (p_role IS NULL OR u.role = p_role)
        AND (p_is_active IS NULL OR u.is_active = p_is_active)
        AND (p_search IS NULL OR u.username LIKE CONCAT('%', p_search, '%') OR u.email LIKE CONCAT('%', p_search, '%'))
    GROUP BY u.admin_id
    ORDER BY u.created_at DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
