-- =============================================
-- Procedure: admin_get_account_logins
-- Purpose: Get all logins associated with an account
-- Parameters:
--   p_account_id: Account ID to get logins for
-- Returns: List of logins for the account
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_account_logins`$$

CREATE PROCEDURE `admin_get_account_logins`(
    IN p_account_id INT
)
BEGIN
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_GET_ACCOUNT_LOGINS_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to get account logins') AS error_message;
    END;
    
    -- Validate account_id
    IF p_account_id IS NULL THEN
        SELECT 
            'fail' AS status,
            'Validation Exception' AS error_type,
            '52001' AS error_code,
            'Account ID is required' AS error_message;
    ELSE
        -- Return logins for the account
        SELECT 
            login_id,
            account_id,
            user_name,
            is_active,
            active_date,
            created_date,
            created_user,
            modified_date,
            modified_user,
            deactivation_date
        FROM login
        WHERE account_id = p_account_id
        ORDER BY created_date DESC;
    END IF;
    
END$$

DELIMITER ;
