-- =============================================
-- Procedure: admin_get_partner_registrations
-- Purpose: List all partner registration requests
-- Parameters:
--   p_status: Filter by approval status (optional)
--   p_search: Search by business name or email (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: Partner registration requests with business details
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_partner_registrations`$$

CREATE PROCEDURE `admin_get_partner_registrations`(
    IN p_status VARCHAR(20),
    IN p_search VARCHAR(150),
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_GET_PARTNERS_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to get partner registrations') AS error_message;
    END;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM registered_partner
    WHERE 
        (p_status IS NULL OR verification_status = p_status)
        AND (p_search IS NULL OR 
             business_name LIKE CONCAT('%', p_search, '%') OR 
             primary_contact_email LIKE CONCAT('%', p_search, '%') OR
             business_email LIKE CONCAT('%', p_search, '%') OR
             CONCAT(primary_contact_first_name, ' ', primary_contact_last_name) LIKE CONCAT('%', p_search, '%'));
    
    -- Return partner registration requests
    SELECT 
        rp.reg_partner_id AS id,
        rp.business_name,
        rp.business_description AS business_type,
        rp.business_registration_number AS registration_number,
        rp.business_ITIN AS tax_id,
        CONCAT(rp.primary_contact_first_name, ' ', rp.primary_contact_last_name) AS contact_person,
        rp.primary_contact_email AS contact_email,
        rp.primary_phone AS contact_phone,
        CAST(rp.primary_phone_country_code AS CHAR) AS contact_phone_country,
        rp.business_website AS website,
        rp.verification_status AS approval_status,
        rp.user_modified AS approved_by,
        rp.date_modified AS approved_date,
        rp.verification_comment AS rejection_reason,
        rp.date_created AS created_date,
        -- Pagination info
        v_total_count AS total_count
    FROM registered_partner rp
    WHERE 
        (p_status IS NULL OR rp.verification_status = p_status)
        AND (p_search IS NULL OR 
             rp.business_name LIKE CONCAT('%', p_search, '%') OR 
             rp.primary_contact_email LIKE CONCAT('%', p_search, '%') OR
             rp.business_email LIKE CONCAT('%', p_search, '%') OR
             CONCAT(rp.primary_contact_first_name, ' ', rp.primary_contact_last_name) LIKE CONCAT('%', p_search, '%'))
    ORDER BY 
        CASE rp.verification_status
            WHEN 'pending' THEN 1
            WHEN 'approved' THEN 2
            WHEN 'rejected' THEN 3
        END,
        rp.date_created DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
