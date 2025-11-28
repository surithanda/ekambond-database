-- =============================================
-- Procedure: admin_get_total_payments
-- Purpose: Get payment summaries by status, date range, API client
-- Parameters:
--   p_status: Filter by payment status (optional)
--   p_client_id: Filter by API client ID (optional)
--   p_start_date: Start date for filtering (optional)
--   p_end_date: End date for filtering (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: Payment records with aggregate statistics
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_total_payments`$$

CREATE PROCEDURE `admin_get_total_payments`(
    IN p_status VARCHAR(50),
    IN p_client_id INT,
    IN p_start_date DATETIME,
    IN p_end_date DATETIME,
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    DECLARE v_total_count INT DEFAULT 0;
    DECLARE v_total_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_successful_count INT DEFAULT 0;
    DECLARE v_successful_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_pending_count INT DEFAULT 0;
    DECLARE v_pending_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_failed_count INT DEFAULT 0;
    DECLARE v_failed_amount DECIMAL(10,2) DEFAULT 0;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get aggregate statistics
    SELECT 
        COUNT(*),
        COALESCE(SUM(amount), 0),
        COALESCE(SUM(CASE WHEN status = 'succeeded' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status = 'succeeded' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status IN ('pending', 'processing') THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status IN ('pending', 'processing') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status IN ('failed', 'canceled') THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status IN ('failed', 'canceled') THEN amount ELSE 0 END), 0)
    INTO 
        v_total_count,
        v_total_amount,
        v_successful_count,
        v_successful_amount,
        v_pending_count,
        v_pending_amount,
        v_failed_count,
        v_failed_amount
    FROM stripe_payment_intents
    WHERE 
        (p_status IS NULL OR status = p_status)
        AND (p_client_id IS NULL OR client_id = p_client_id)
        AND (p_start_date IS NULL OR created >= p_start_date)
        AND (p_end_date IS NULL OR created <= p_end_date);
    
    -- Return payment records with details
    SELECT 
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
        c.business_name AS client_business_name,
        c.contact_email AS client_email,
        -- Account info
        a.account_code,
        a.email AS account_email,
        a.first_name,
        a.last_name,
        -- Aggregate statistics
        v_total_count AS total_count,
        v_total_amount AS total_amount,
        v_successful_count AS successful_count,
        v_successful_amount AS successful_amount,
        v_pending_count AS pending_count,
        v_pending_amount AS pending_amount,
        v_failed_count AS failed_count,
        v_failed_amount AS failed_amount,
        -- Pagination info
        p_limit AS page_limit,
        p_offset AS page_offset
    FROM stripe_payment_intents pi
    LEFT JOIN api_clients c ON pi.client_id = c.id
    LEFT JOIN account a ON pi.account_id = a.account_id
    WHERE 
        (p_status IS NULL OR pi.status = p_status)
        AND (p_client_id IS NULL OR pi.client_id = p_client_id)
        AND (p_start_date IS NULL OR pi.created >= p_start_date)
        AND (p_end_date IS NULL OR pi.created <= p_end_date)
    ORDER BY pi.created DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
