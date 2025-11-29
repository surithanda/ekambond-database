-- =============================================
-- Procedure: admin_enable_disable_account
-- Purpose: Enable or disable account and related login status
-- Parameters:
--   p_account_id: Account ID to update
--   p_is_active: New active status (1=enable, 0=disable)
--   p_reason: Reason for status change
--   p_admin_user: Admin who made the change
-- Returns: Updated account status
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_enable_disable_account`$$

CREATE PROCEDURE `admin_enable_disable_account`(
    IN p_account_id INT,
    IN p_is_active TINYINT(1),
    IN p_reason VARCHAR(255),
    IN p_admin_user VARCHAR(45)
)
proc_label: BEGIN
    DECLARE v_account_exists INT DEFAULT 0;
    DECLARE v_current_status TINYINT(1);
    DECLARE v_old_is_active TINYINT(1);
    DECLARE v_email VARCHAR(150);
    DECLARE v_start_time DATETIME;
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_ACCOUNT_STATUS_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to update account status') AS error_message;
    END;
    
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Check if account exists
    SELECT COUNT(*), is_active, email
    INTO v_account_exists, v_current_status, v_email
    FROM account
    WHERE account_id = p_account_id AND (is_deleted IS NULL OR is_deleted = 0);
    
    IF v_account_exists = 0 THEN
        SET v_error_code = '51001';
        SET v_error_message = 'Account not found';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if status is already the same
    IF v_current_status = p_is_active THEN
        SET v_error_code = '51002';
        SET v_error_message = CONCAT('Account is already ', IF(p_is_active = 1, 'active', 'inactive'));
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Update account status
    IF p_is_active = 1 THEN
        -- Enable account
        UPDATE account
        SET 
            is_active = 1,
            activation_date = NOW(),
            activated_user = p_admin_user,
            deactivated_date = NULL,
            deactivated_user = NULL,
            deactivation_reason = NULL,
            modified_date = NOW(),
            modified_user = p_admin_user
        WHERE account_id = p_account_id;
        
        -- Enable related logins
        UPDATE login
        SET 
            is_active = 1,
            modified_date = NOW(),
            modified_user = p_admin_user
        WHERE account_id = p_account_id;
        
    ELSE
        -- Disable account
        UPDATE account
        SET 
            is_active = 0,
            deactivated_date = NOW(),
            deactivated_user = p_admin_user,
            deactivation_reason = p_reason,
            modified_date = NOW(),
            modified_user = p_admin_user
        WHERE account_id = p_account_id;
        
        -- Disable related logins
        UPDATE login
        SET 
            is_active = 0,
            modified_date = NOW(),
            modified_user = p_admin_user
        WHERE account_id = p_account_id;
    END IF;
    
    -- Log account status change
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type, activity_details)
    VALUES (
        'INFO',
        CONCAT('Account ', IF(p_is_active = 1, 'enabled', 'disabled'), ': account_id=', p_account_id),
        p_admin_user,
        v_start_time,
        NOW(),
        CONCAT('ADMIN_ACCOUNT_', IF(p_is_active = 1, 'ENABLED', 'DISABLED')),
        p_reason
    );
    
    -- Insert audit log
    INSERT INTO admin_audit_log (
        admin_id,
        action_type,
        resource_type,
        resource_id,
        action_details
    )
    VALUES (
        (SELECT admin_id FROM admin_users WHERE username = p_admin_user LIMIT 1),
        IF(p_is_active = 1, 'ENABLE_ACCOUNT', 'DISABLE_ACCOUNT'),
        'ACCOUNT',
        p_account_id,
        JSON_OBJECT('reason', p_reason, 'email', v_email)
    );
    
    -- Send notification to user
    INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
    VALUES (
        v_email,
        CONCAT('Account ', IF(p_is_active = 1, 'Activated', 'Deactivated')),
        CONCAT(
            'Your account has been ', 
            IF(p_is_active = 1, 'activated', 'deactivated'),
            IF(p_is_active = 0, CONCAT('. Reason: ', p_reason), ''),
            '. Please contact support if you have any questions.'
        ),
        CONCAT('ACCOUNT_', IF(p_is_active = 1, 'ENABLED', 'DISABLED')),
        p_admin_user
    );
    
    -- Return updated account status
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        account_id,
        account_code,
        email,
        first_name,
        last_name,
        is_active,
        activation_date,
        activated_user,
        deactivated_date,
        deactivated_user,
        deactivation_reason
    FROM account
    WHERE account_id = p_account_id;
    
END proc_label$$

DELIMITER ;
