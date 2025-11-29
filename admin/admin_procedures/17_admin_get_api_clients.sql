-- =============================================
-- Procedure: admin_get_api_clients
-- Purpose: Get API clients with related registrations and usage statistics
-- Parameters:
--   p_client_id: Filter by client ID (optional)
--   p_is_active: Filter by active status (optional)
--   p_search: Search by business name or email (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: API clients with usage statistics and account linkage
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_api_clients`$$

CREATE PROCEDURE `admin_get_api_clients`(
    IN p_client_id INT,
    IN p_is_active TINYINT(1),
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_GET_API_CLIENTS_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to get API clients') AS error_message;
    END;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM api_clients
    WHERE 
        (p_client_id IS NULL OR id = p_client_id)
        AND (p_is_active IS NULL OR is_active = p_is_active)
        AND (p_search IS NULL OR 
             business_name LIKE CONCAT('%', p_search, '%') OR 
             contact_email LIKE CONCAT('%', p_search, '%'));
    
    -- Return API clients with statistics
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        c.id AS client_id,
        c.business_name,
        c.business_type,
        c.registration_number,
        c.tax_id,
        c.contact_person,
        c.contact_email,
        c.contact_phone,
        c.contact_phone_country,
        c.website,
        c.address_line1,
        c.address_line2,
        c.city,
        c.state,
        c.country,
        c.zip,
        c.is_active,
        c.created_date,
        c.created_user,
        c.modified_date,
        c.modified_user,
        
        -- API Keys info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'key_id', k.key_id,
                'key_name', k.key_name,
                'api_key', CONCAT(SUBSTRING(k.api_key, 1, 8), '...'),
                'expires_at', k.expires_at,
                'is_active', k.is_active,
                'usage_count', k.usage_count,
                'last_used', k.last_used,
                'created_at', k.created_at
            )
        ) FROM api_keys k WHERE k.client_id = c.id) AS api_keys,
        
        -- Count of active API keys
        (SELECT COUNT(*) FROM api_keys k 
         WHERE k.client_id = c.id AND k.is_active = 1 AND k.expires_at > NOW()) AS active_keys_count,
        
        -- Count of registered accounts
        (SELECT COUNT(*) FROM account a 
         WHERE a.registered_partner_id = c.id) AS registered_accounts_count,
        
        -- Count of active accounts
        (SELECT COUNT(*) FROM account a 
         WHERE a.registered_partner_id = c.id AND a.is_active = 1) AS active_accounts_count,
        
        -- Payment statistics
        (SELECT COUNT(*) FROM stripe_payment_intents p 
         WHERE p.client_id = c.id) AS total_payments,
        
        (SELECT COUNT(*) FROM stripe_payment_intents p 
         WHERE p.client_id = c.id AND p.status = 'succeeded') AS successful_payments,
        
        (SELECT COALESCE(SUM(p.amount), 0) FROM stripe_payment_intents p 
         WHERE p.client_id = c.id AND p.status = 'succeeded') AS total_revenue,
        
        -- Last payment date
        (SELECT MAX(p.created) FROM stripe_payment_intents p 
         WHERE p.client_id = c.id) AS last_payment_date,
        
        -- Pagination info
        v_total_count AS total_count,
        p_limit AS page_limit,
        p_offset AS page_offset
        
    FROM api_clients c
    WHERE 
        (p_client_id IS NULL OR c.id = p_client_id)
        AND (p_is_active IS NULL OR c.is_active = p_is_active)
        AND (p_search IS NULL OR 
             c.business_name LIKE CONCAT('%', p_search, '%') OR 
             c.contact_email LIKE CONCAT('%', p_search, '%'))
    ORDER BY c.created_date DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
