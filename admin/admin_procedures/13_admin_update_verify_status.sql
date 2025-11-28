-- =============================================
-- Procedure: admin_update_verify_status
-- Purpose: Update verification status for profile tables
-- Parameters:
--   p_table_name: Table to update (personal, address, education, employment, photos)
--   p_record_id: Record ID to update
--   p_verification_status: New verification status
--   p_admin_user: Admin who made the verification
-- Returns: Updated verification status
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_update_verify_status`$$

CREATE PROCEDURE `admin_update_verify_status`(
    IN p_table_name VARCHAR(50),
    IN p_record_id INT,
    IN p_verification_status VARCHAR(20),
    IN p_admin_user VARCHAR(45),
    OUT p_error_code VARCHAR(10),
    OUT p_error_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_record_exists INT DEFAULT 0;
    DECLARE v_profile_id INT;
    DECLARE v_account_id INT;
    DECLARE v_email VARCHAR(150);
    DECLARE v_start_time DATETIME;
    DECLARE v_sql_query TEXT;
    
    SET v_start_time = NOW();
    SET p_error_code = NULL;
    SET p_error_message = NULL;
    
    -- Validate table name
    IF p_table_name NOT IN ('personal', 'address', 'education', 'employment', 'photos') THEN
        SET p_error_code = '51003';
        SET p_error_message = 'Invalid table name. Must be: personal, address, education, employment, or photos';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Validate verification status
    IF p_verification_status NOT IN ('pending', 'verified', 'rejected') THEN
        SET p_error_code = '51004';
        SET p_error_message = 'Invalid verification status. Must be: pending, verified, or rejected';
        
        SELECT p_error_code AS error_code, p_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Update based on table name
    CASE p_table_name
        WHEN 'personal' THEN
            -- Check if record exists
            SELECT COUNT(*), profile_id, account_id
            INTO v_record_exists, v_profile_id, v_account_id
            FROM profile_personal
            WHERE profile_id = p_record_id;
            
            IF v_record_exists = 0 THEN
                SET p_error_code = '51005';
                SET p_error_message = 'Profile personal record not found';
                SELECT p_error_code AS error_code, p_error_message AS error_message;
                LEAVE proc_label;
            END IF;
            
            -- Update verification status
            UPDATE profile_personal
            SET 
                verification_status = p_verification_status,
                verified_by = p_admin_user,
                verified_date = NOW()
            WHERE profile_id = p_record_id;
            
        WHEN 'address' THEN
            SELECT COUNT(*), profile_id
            INTO v_record_exists, v_profile_id
            FROM profile_address
            WHERE address_id = p_record_id;
            
            IF v_record_exists = 0 THEN
                SET p_error_code = '51005';
                SET p_error_message = 'Profile address record not found';
                SELECT p_error_code AS error_code, p_error_message AS error_message;
                LEAVE proc_label;
            END IF;
            
            UPDATE profile_address
            SET 
                verification_status = p_verification_status,
                verified_by = p_admin_user,
                verified_date = NOW()
            WHERE address_id = p_record_id;
            
            SELECT account_id INTO v_account_id
            FROM profile_personal WHERE profile_id = v_profile_id;
            
        WHEN 'education' THEN
            SELECT COUNT(*), profile_id
            INTO v_record_exists, v_profile_id
            FROM profile_education
            WHERE education_id = p_record_id;
            
            IF v_record_exists = 0 THEN
                SET p_error_code = '51005';
                SET p_error_message = 'Profile education record not found';
                SELECT p_error_code AS error_code, p_error_message AS error_message;
                LEAVE proc_label;
            END IF;
            
            UPDATE profile_education
            SET 
                verification_status = p_verification_status,
                verified_by = p_admin_user,
                verified_date = NOW()
            WHERE education_id = p_record_id;
            
            SELECT account_id INTO v_account_id
            FROM profile_personal WHERE profile_id = v_profile_id;
            
        WHEN 'employment' THEN
            SELECT COUNT(*), profile_id
            INTO v_record_exists, v_profile_id
            FROM profile_employment
            WHERE employment_id = p_record_id;
            
            IF v_record_exists = 0 THEN
                SET p_error_code = '51005';
                SET p_error_message = 'Profile employment record not found';
                SELECT p_error_code AS error_code, p_error_message AS error_message;
                LEAVE proc_label;
            END IF;
            
            UPDATE profile_employment
            SET 
                verification_status = p_verification_status,
                verified_by = p_admin_user,
                verified_date = NOW()
            WHERE employment_id = p_record_id;
            
            SELECT account_id INTO v_account_id
            FROM profile_personal WHERE profile_id = v_profile_id;
            
        WHEN 'photos' THEN
            SELECT COUNT(*), profile_id
            INTO v_record_exists, v_profile_id
            FROM profile_photos
            WHERE photo_id = p_record_id;
            
            IF v_record_exists = 0 THEN
                SET p_error_code = '51005';
                SET p_error_message = 'Profile photo record not found';
                SELECT p_error_code AS error_code, p_error_message AS error_message;
                LEAVE proc_label;
            END IF;
            
            UPDATE profile_photos
            SET 
                verification_status = p_verification_status,
                verified_by = p_admin_user,
                verified_date = NOW()
            WHERE photo_id = p_record_id;
            
            SELECT account_id INTO v_account_id
            FROM profile_personal WHERE profile_id = v_profile_id;
    END CASE;
    
    -- Get user email
    SELECT email INTO v_email
    FROM account
    WHERE account_id = v_account_id;
    
    -- Log verification update
    INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, activity_type, activity_details)
    VALUES (
        'INFO',
        CONCAT('Profile ', p_table_name, ' verification updated: record_id=', p_record_id, ', status=', p_verification_status),
        p_admin_user,
        v_start_time,
        NOW(),
        'ADMIN_PROFILE_VERIFICATION',
        CONCAT('table=', p_table_name, ', status=', p_verification_status)
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
        'UPDATE_VERIFICATION_STATUS',
        CONCAT('PROFILE_', UPPER(p_table_name)),
        p_record_id,
        JSON_OBJECT('status', p_verification_status, 'profile_id', v_profile_id, 'account_id', v_account_id)
    );
    
    -- Send notification to user
    IF p_verification_status IN ('verified', 'rejected') THEN
        INSERT INTO notification_queue (recipient_email, subject, message_body, notification_type, created_by)
        VALUES (
            v_email,
            CONCAT('Profile ', INITCAP(p_table_name), ' ', INITCAP(p_verification_status)),
            CONCAT(
                'Your profile ', p_table_name, ' information has been ',
                p_verification_status,
                '. Please login to view details.'
            ),
            CONCAT('PROFILE_', UPPER(p_verification_status)),
            p_admin_user
        );
    END IF;
    
    -- Return success
    SELECT 
        'SUCCESS' AS status,
        p_table_name AS table_name,
        p_record_id AS record_id,
        p_verification_status AS verification_status,
        p_admin_user AS verified_by,
        NOW() AS verified_date,
        NULL AS error_code,
        NULL AS error_message;
    
END proc_label$$

DELIMITER ;
