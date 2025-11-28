-- =============================================
-- Procedure: admin_get_api_client_payments
-- Purpose: Get payment records filtered by API client for revenue tracking
-- Parameters:
--   p_client_id: API client ID
--   p_status: Filter by payment status (optional)
--   p_start_date: Start date for filtering (optional)
--   p_end_date: End date for filtering (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: Payment records with client and account details
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_api_client_payments`$$

CREATE PROCEDURE `admin_get_api_client_payments`(
    IN p_client_id INT,
    IN p_status VARCHAR(50),
    IN p_start_date DATETIME,
    IN p_end_date DATETIME,
    IN p_limit INT,
    IN p_offset INT
)
proc_label: BEGIN
    DECLARE v_total_count INT DEFAULT 0;
    DECLARE v_total_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_successful_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_total_payments INT DEFAULT 0;
    DECLARE v_error_code VARCHAR(10);
    DECLARE v_error_message VARCHAR(255);
    DECLARE v_client_exists INT DEFAULT 0;
    
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
    
    -- Check if client exists
    SELECT COUNT(*) INTO v_client_exists
    FROM api_clients
    WHERE id = p_client_id;
    
    IF v_client_exists = 0 THEN
        SELECT 
            'fail' AS status,
            'Client Not Found' AS error_type,
            '51011' AS error_code,
            'API client not found' AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Get aggregate statistics for this client
    SELECT 
        COUNT(*),
        COALESCE(SUM(amount), 0),
        COALESCE(SUM(CASE WHEN status = 'succeeded' THEN amount ELSE 0 END), 0)
    INTO 
        v_total_count,
        v_total_amount,
        v_successful_amount
    FROM stripe_payment_intents
    WHERE 
        client_id = p_client_id
        AND (p_status IS NULL OR status = p_status)
        AND (p_start_date IS NULL OR created >= p_start_date)
        AND (p_end_date IS NULL OR created <= p_end_date);
    
    -- Return payment records
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        pi.id,
        pi.payment_intent_id,
        pi.amount,
        pi.currency,
        pi.status,
        pi.client_id,
        pi.account_id,
        pi.description,
        pi.created,
        pi.updated,
        
        -- Client info
        c.business_name,
        c.contact_email AS client_email,
        c.contact_person,
        
        -- Account info
        a.account_code,
        a.email AS account_email,
        a.first_name,
        a.last_name,
        a.primary_phone,
        
        -- Statistics
        v_total_count AS total_payments,
        v_total_amount AS total_amount,
        v_successful_amount AS successful_amount,
        
        -- Pagination info
        p_limit AS page_limit,
        p_offset AS page_offset
        
    FROM stripe_payment_intents pi
    INNER JOIN api_clients c ON pi.client_id = c.id
    LEFT JOIN account a ON pi.account_id = a.account_id
    WHERE 
        pi.client_id = p_client_id
        AND (p_status IS NULL OR pi.status = p_status)
        AND (p_start_date IS NULL OR pi.created >= p_start_date)
        AND (p_end_date IS NULL OR pi.created <= p_end_date)
    ORDER BY pi.created DESC
    LIMIT p_limit OFFSET p_offset;
    
END proc_label$$

DELIMITER ;
