DELIMITER //
DROP PROCEDURE IF EXISTS `admin_registered_partner_update_v1`;
CREATE PROCEDURE `admin_registered_partner_update_v1`(
    IN p_reg_partner_id INT,
    IN p_business_name VARCHAR(155),
    IN p_alias VARCHAR(45),
    IN p_business_email VARCHAR(155),
    IN p_primary_phone VARCHAR(10),
    IN p_primary_phone_country_code INT,
    IN p_secondary_phone VARCHAR(10),
    IN p_address_line1 VARCHAR(150),
    IN p_city VARCHAR(45),
    IN p_state INT,
    IN p_country INT,
    IN p_zip VARCHAR(8),
    IN p_business_registration_number VARCHAR(155),
    IN p_business_ITIN VARCHAR(155),
    IN p_business_description VARCHAR(255),
    IN p_primary_contact_first_name VARCHAR(45),
    IN p_primary_contact_last_name VARCHAR(45),
    IN p_primary_contact_gender INT,
    IN p_primary_contact_date_of_birth DATE,
    IN p_primary_contact_email VARCHAR(45),
    IN p_business_linkedin VARCHAR(155),
    IN p_business_website VARCHAR(155),
    IN p_business_facebook VARCHAR(155),
    IN p_business_whatsapp VARCHAR(155),
    IN p_isverified INT,
    IN p_Is_active BIT,
    IN p_domain_root_url VARCHAR(255),
    IN p_verification_comment VARCHAR(255),
    IN p_verification_status VARCHAR(45),
    IN p_modified_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    DECLARE partner_exists INT DEFAULT 0;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'REGISTERED_PARTNER_UPDATE', 
            CONCAT('Error Code: ', error_code),
            start_time, NOW(), TIMESTAMPDIFF(MICROSECOND, start_time, NOW()) / 1000
        );
        
        SELECT 
            'fail' AS status,
            'SQL Exception' as error_type,
            error_code,
            error_message;            
    END;
    
    -- Declare handler for custom errors
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        ROLLBACK;
        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'REGISTERED_PARTNER_UPDATE', 
            CONCAT('Error Code: ', error_code),
            start_time, NOW(), TIMESTAMPDIFF(MICROSECOND, start_time, NOW()) / 1000
        );
        
        SELECT 
            'fail' AS status,
            'Validation Exception' as error_type,
            error_code,
            error_message;
    END;
    
    -- Record start time for performance tracking
    SET start_time = NOW();
    
    -- Start transaction
    START TRANSACTION;
    
    -- Validation: Ensure reg_partner_id is provided
    IF p_reg_partner_id IS NULL OR p_reg_partner_id <= 0 THEN
        SET error_code = '48201';
        SET error_message = 'Partner ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if partner exists
    SELECT COUNT(*) INTO partner_exists
    FROM registered_partner
    WHERE reg_partner_id = p_reg_partner_id;
    
    IF partner_exists = 0 THEN
        SET error_code = '48202';
        SET error_message = 'Partner with the provided ID does not exist.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the registered partner
    UPDATE registered_partner
    SET 
        business_name = CASE WHEN p_business_name IS NOT NULL THEN p_business_name ELSE business_name END,
        alias = CASE WHEN p_alias IS NOT NULL THEN p_alias ELSE alias END,
        business_email = CASE WHEN p_business_email IS NOT NULL THEN p_business_email ELSE business_email END,
        primary_phone = CASE WHEN p_primary_phone IS NOT NULL THEN p_primary_phone ELSE primary_phone END,
        primary_phone_country_code = CASE WHEN p_primary_phone_country_code IS NOT NULL THEN p_primary_phone_country_code ELSE primary_phone_country_code END,
        secondary_phone = CASE WHEN p_secondary_phone IS NOT NULL THEN p_secondary_phone ELSE secondary_phone END,
        address_line1 = CASE WHEN p_address_line1 IS NOT NULL THEN p_address_line1 ELSE address_line1 END,
        city = CASE WHEN p_city IS NOT NULL THEN p_city ELSE city END,
        state = CASE WHEN p_state IS NOT NULL THEN p_state ELSE state END,
        country = CASE WHEN p_country IS NOT NULL THEN p_country ELSE country END,
        zip = CASE WHEN p_zip IS NOT NULL THEN p_zip ELSE zip END,
        business_registration_number = CASE WHEN p_business_registration_number IS NOT NULL THEN p_business_registration_number ELSE business_registration_number END,
        business_ITIN = CASE WHEN p_business_ITIN IS NOT NULL THEN p_business_ITIN ELSE business_ITIN END,
        business_description = CASE WHEN p_business_description IS NOT NULL THEN p_business_description ELSE business_description END,
        primary_contact_first_name = CASE WHEN p_primary_contact_first_name IS NOT NULL THEN p_primary_contact_first_name ELSE primary_contact_first_name END,
        primary_contact_last_name = CASE WHEN p_primary_contact_last_name IS NOT NULL THEN p_primary_contact_last_name ELSE primary_contact_last_name END,
        primary_contact_gender = CASE WHEN p_primary_contact_gender IS NOT NULL THEN p_primary_contact_gender ELSE primary_contact_gender END,
        primary_contact_date_of_birth = CASE WHEN p_primary_contact_date_of_birth IS NOT NULL THEN p_primary_contact_date_of_birth ELSE primary_contact_date_of_birth END,
        primary_contact_email = CASE WHEN p_primary_contact_email IS NOT NULL THEN p_primary_contact_email ELSE primary_contact_email END,
        business_linkedin = CASE WHEN p_business_linkedin IS NOT NULL THEN p_business_linkedin ELSE business_linkedin END,
        business_website = CASE WHEN p_business_website IS NOT NULL THEN p_business_website ELSE business_website END,
        business_facebook = CASE WHEN p_business_facebook IS NOT NULL THEN p_business_facebook ELSE business_facebook END,
        business_whatsapp = CASE WHEN p_business_whatsapp IS NOT NULL THEN p_business_whatsapp ELSE business_whatsapp END,
        isverified = CASE WHEN p_isverified IS NOT NULL THEN p_isverified ELSE isverified END,
        Is_active = CASE WHEN p_Is_active IS NOT NULL THEN p_Is_active ELSE Is_active END,
        domain_root_url = CASE WHEN p_domain_root_url IS NOT NULL THEN p_domain_root_url ELSE domain_root_url END,
        verification_comment = CASE WHEN p_verification_comment IS NOT NULL THEN p_verification_comment ELSE verification_comment END,
        verification_status = CASE WHEN p_verification_status IS NOT NULL THEN p_verification_status ELSE verification_status END,
        date_modified = NOW(),
        user_modified = p_modified_user,
        activation_date = CASE 
            WHEN p_Is_active = b'1' AND Is_active = b'0' THEN NOW() 
            ELSE activation_date 
        END
    WHERE reg_partner_id = p_reg_partner_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Registered partner updated with ID: ', p_reg_partner_id), 
        p_modified_user, 
        'REGISTERED_PARTNER_UPDATE', 
        CASE 
            WHEN p_business_name IS NOT NULL THEN CONCAT('Business Name: ', p_business_name)
            ELSE CONCAT('Partner ID: ', p_reg_partner_id)
        END,
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_reg_partner_id AS reg_partner_id,
        NULL AS error_code,
        NULL AS error_message;
    
END //
DELIMITER ;
