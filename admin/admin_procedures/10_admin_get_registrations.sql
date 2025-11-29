-- =============================================
-- Procedure: admin_get_registrations
-- Purpose: Get all or specific account registrations with login info
-- Parameters:
--   p_email: Filter by email (optional)
--   p_account_id: Filter by account ID (optional)
--   p_is_active: Filter by active status (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: Account details with login information
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_registrations`$$

CREATE PROCEDURE `admin_get_registrations`(
    IN p_email VARCHAR(150),
    IN p_account_id INT,
    IN p_is_active TINYINT(1),
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    DECLARE v_total_count INT DEFAULT 0;
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_GET_REGISTRATIONS_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to get registrations') AS error_message;
    END;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM account a
    WHERE 
        (p_email IS NULL OR a.email = p_email)
        AND (p_account_id IS NULL OR a.account_id = p_account_id)
        AND (p_is_active IS NULL OR a.is_active = p_is_active)
        AND (a.is_deleted IS NULL OR a.is_deleted = 0);
    
    -- Return account registrations with login info
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        a.account_id,
        a.account_code,
        a.email,
        a.first_name,
        a.middle_name,
        a.last_name,
        a.birth_date,
        a.gender,
        a.primary_phone,
        a.primary_phone_country,
        a.secondary_phone,
        a.secondary_phone_country,
        a.address_line1,
        a.address_line2,
        a.city,
        a.state,
        a.zip,
        a.country,
        a.is_active,
        a.activation_date,
        a.activated_user,
        a.deactivated_date,
        a.deactivated_user,
        a.deactivation_reason,
        a.created_date,
        a.created_user,
        a.modified_date,
        a.modified_user,
        a.registered_partner_id,
        -- Login information
        GROUP_CONCAT(
            DISTINCT CONCAT(
                '{"login_id":', l.login_id,
                ',"username":"', l.username,
                '","is_active":', COALESCE(l.is_active, 0),
                ',"last_login":"', COALESCE(l.last_login, ''),
                '","created_date":"', l.created_date,
                '"}'
            ) SEPARATOR ','
        ) AS login_info,
        COUNT(DISTINCT l.login_id) AS login_count,
        -- Pagination info
        v_total_count AS total_count,
        p_limit AS page_limit,
        p_offset AS page_offset
    FROM account a
    LEFT JOIN login l ON a.account_id = l.account_id
    WHERE 
        (p_email IS NULL OR a.email = p_email)
        AND (p_account_id IS NULL OR a.account_id = p_account_id)
        AND (p_is_active IS NULL OR a.is_active = p_is_active)
        AND (a.is_deleted IS NULL OR a.is_deleted = 0)
    GROUP BY a.account_id
    ORDER BY a.created_date DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
