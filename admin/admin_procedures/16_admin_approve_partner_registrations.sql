-- =============================================
-- Procedure: admin_approve_partner_registrations
-- Purpose: Approve or reject partner registration and create API client
-- Parameters:
--   p_partner_id: Partner registration ID
--   p_action: Action to take (approve/reject)
--   p_rejection_reason: Reason for rejection (if rejecting)
--   p_api_key_expiry_days: Days until API key expires (default 365)
--   p_admin_user: Admin who approved/rejected
-- Returns: API client details if approved
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_approve_partner_registrations`$$

CREATE PROCEDURE `admin_approve_partner_registrations`(
    IN p_partner_id INT,
    IN p_action VARCHAR(20),
    IN p_rejection_reason VARCHAR(255),
    IN p_api_key_expiry_days INT,
    IN p_admin_user VARCHAR(45)
)
proc_label: BEGIN
    DECLARE v_partner_exists INT DEFAULT 0;
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_business_name VARCHAR(150);
    DECLARE v_contact_email VARCHAR(150);
    DECLARE v_api_client_id INT;
    DECLARE v_api_key VARCHAR(64);
    DECLARE v_api_key_expires DATETIME;
    DECLARE v_old_status VARCHAR(20);
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_APPROVE_PARTNER_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to approve partner') AS error_message;
    END;
    
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    SET p_api_key_expiry_days = COALESCE(p_api_key_expiry_days, 365);
    
    -- Validate action
    IF p_action NOT IN ('approve', 'reject') THEN
        SET v_error_code = '51006';
        SET v_error_message = 'Invalid action. Must be approve or reject';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if partner registration exists
    SELECT COUNT(*), approval_status, business_name, contact_email
    INTO v_partner_exists, v_current_status, v_business_name, v_contact_email
    FROM registered_partner
    WHERE id = p_partner_id;
    
    IF v_partner_exists = 0 THEN
        SET v_error_code = '51007';
        SET v_error_message = 'Partner registration not found';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if already processed
    IF v_current_status != 'pending' THEN
        SET v_error_code = '51008';
        SET v_error_message = CONCAT('Partner registration already ', v_current_status);
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    IF p_action = 'approve' THEN
        -- Check if API client already exists
        SELECT COUNT(*) INTO v_partner_exists
        FROM api_clients
        WHERE business_name = v_business_name AND contact_email = v_contact_email;
        
        IF v_partner_exists > 0 THEN
            SET v_error_code = '51009';
            SET v_error_message = 'API client already exists for this partner';
            SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
            LEAVE proc_label;
        END IF;
        
        -- Generate API key (32 character random string)
        SET v_api_key = CONCAT(
            SUBSTRING(MD5(RAND()), 1, 16),
            SUBSTRING(MD5(RAND()), 1, 16)
        );
        
        SET v_api_key_expires = DATE_ADD(NOW(), INTERVAL p_api_key_expiry_days DAY);
        
        -- Insert into api_clients
        INSERT INTO api_clients (
            business_name,
            business_type,
            registration_number,
            tax_id,
            contact_person,
            contact_email,
            contact_phone,
            contact_phone_country,
            website,
            address_line1,
            address_line2,
            city,
            state,
            country,
            zip,
            is_active,
            created_date,
            created_user
        )
        SELECT 
            business_name,
            business_type,
            registration_number,
            tax_id,
            contact_person,
            contact_email,
            contact_phone,
            contact_phone_country,
            website,
            address_line1,
            address_line2,
            city,
            state,
            country,
            zip,
            1,
            NOW(),
            p_admin_user
        FROM registered_partner
        WHERE id = p_partner_id;
        
        SET v_api_client_id = LAST_INSERT_ID();
        
        -- Insert API key
        INSERT INTO api_keys (
            client_id,
            api_key,
            key_name,
            expires_at,
            is_active,
            created_by
        )
        VALUES (
            v_api_client_id,
            v_api_key,
            'Primary API Key',
            v_api_key_expires,
            1,
            p_admin_user
        );
        
        -- Update partner registration status
        UPDATE registered_partner
        SET 
            approval_status = 'approved',
            approved_by = p_admin_user,
            approved_date = NOW(),
            modified_date = NOW(),
            modified_user = p_admin_user
        WHERE id = p_partner_id;
        
        -- Log approval
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type)
        VALUES (
            'INFO',
            CONCAT('Partner registration approved: ', v_business_name, ' (ID: ', p_partner_id, ')'),
            p_admin_user,
            v_start_time,
            NOW(),
            'ADMIN_PARTNER_APPROVED'
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
            'APPROVE_PARTNER',
            'PARTNER_REGISTRATION',
            p_partner_id,
            JSON_OBJECT('business_name', v_business_name, 'api_client_id', v_api_client_id)
        );
        
        -- Send approval notification
        INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
        VALUES (
            v_contact_email,
            'Partner Registration Approved',
            CONCAT(
                'Congratulations! Your partner registration has been approved. ',
                'Your API Key: ', v_api_key, ' (Expires: ', DATE_FORMAT(v_api_key_expires, '%Y-%m-%d'), '). ',
                'Please keep this key secure and do not share it.'
            ),
            'PARTNER_APPROVED',
            p_admin_user
        );
        
        -- Return API client details
        SELECT 
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message,
            'approved' AS action,
            v_api_client_id AS api_client_id,
            v_api_key AS api_key,
            v_api_key_expires AS api_key_expires,
            v_business_name AS business_name,
            v_contact_email AS contact_email;
        
    ELSE
        -- Reject partner registration
        IF p_rejection_reason IS NULL OR p_rejection_reason = '' THEN
            SET v_error_code = '51010';
            SET v_error_message = 'Rejection reason is required';
            SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
            LEAVE proc_label;
        END IF;
        
        -- Update partner registration status
        UPDATE registered_partner
        SET 
            approval_status = 'rejected',
            approved_by = p_admin_user,
            approved_date = NOW(),
            rejection_reason = p_rejection_reason,
            modified_date = NOW(),
            modified_user = p_admin_user
        WHERE id = p_partner_id;
        
        -- Log rejection
        INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type, activity_details)
        VALUES (
            'INFO',
            CONCAT('Partner registration rejected: ', v_business_name, ' (ID: ', p_partner_id, ')'),
            p_admin_user,
            v_start_time,
            NOW(),
            'ADMIN_PARTNER_REJECTED',
            p_rejection_reason
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
            'REJECT_PARTNER',
            'PARTNER_REGISTRATION',
            p_partner_id,
            JSON_OBJECT('business_name', v_business_name, 'reason', p_rejection_reason)
        );
        
        -- Send rejection notification
        INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
        VALUES (
            v_contact_email,
            'Partner Registration Status',
            CONCAT(
                'Thank you for your interest. Unfortunately, your partner registration has not been approved at this time. ',
                'Reason: ', p_rejection_reason, '. ',
                'Please contact support if you have any questions.'
            ),
            'PARTNER_REJECTED',
            p_admin_user
        );
        
        -- Return rejection details
        SELECT 
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message,
            'rejected' AS action,
            p_partner_id AS partner_id,
            v_business_name AS business_name,
            v_contact_email AS contact_email,
            p_rejection_reason AS rejection_reason;
    END IF;
    
END proc_label$$

DELIMITER ;
