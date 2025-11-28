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
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT,
            v_error_code = MYSQL_ERRNO;
        SELECT 'fail' AS status, 'SQL Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM registered_partner
    WHERE 
        (p_status IS NULL OR approval_status = p_status)
        AND (p_search IS NULL OR 
             business_name LIKE CONCAT('%', p_search, '%') OR 
             contact_email LIKE CONCAT('%', p_search, '%') OR
             contact_person LIKE CONCAT('%', p_search, '%'));
    
    -- Return partner registration requests
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        rp.id,
        rp.business_name,
        rp.business_type,
        rp.registration_number,
        rp.tax_id,
        rp.contact_person,
        rp.contact_email,
        rp.contact_phone,
        rp.contact_phone_country,
        rp.website,
        rp.address_line1,
        rp.address_line2,
        rp.city,
        rp.state,
        rp.country,
        rp.zip,
        rp.approval_status,
        rp.approved_by,
        rp.approved_date,
        rp.rejection_reason,
        rp.created_date,
        rp.created_user,
        rp.modified_date,
        rp.modified_user,
        -- Check if already converted to API client
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM api_clients ac 
                WHERE ac.business_name = rp.business_name 
                AND ac.contact_email = rp.contact_email
            ) THEN 1
            ELSE 0
        END AS is_api_client,
        -- Get API client ID if exists
        (SELECT id FROM api_clients ac 
         WHERE ac.business_name = rp.business_name 
         AND ac.contact_email = rp.contact_email
         LIMIT 1) AS api_client_id,
        -- Pagination info
        v_total_count AS total_count,
        p_limit AS page_limit,
        p_offset AS page_offset
    FROM registered_partner rp
    WHERE 
        (p_status IS NULL OR rp.approval_status = p_status)
        AND (p_search IS NULL OR 
             rp.business_name LIKE CONCAT('%', p_search, '%') OR 
             rp.contact_email LIKE CONCAT('%', p_search, '%') OR
             rp.contact_person LIKE CONCAT('%', p_search, '%'))
    ORDER BY 
        CASE rp.approval_status
            WHEN 'pending' THEN 1
            WHEN 'approved' THEN 2
            WHEN 'rejected' THEN 3
        END,
        rp.created_date DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
