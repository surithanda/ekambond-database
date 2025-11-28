DELIMITER //
DROP PROCEDURE IF EXISTS `admin_eb_registered_partner_get`;
CREATE PROCEDURE `admin_eb_registered_partner_get`(
    IN p_business_name VARCHAR(155),
    IN p_primary_phone VARCHAR(20),
    IN p_business_website VARCHAR(255),
    IN p_business_itin VARCHAR(20),
    IN p_registration_number VARCHAR(50),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'REGISTERED_PARTNER_GET', 
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
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'REGISTERED_PARTNER_GET', 
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
    
    -- Validation: Ensure at least one search parameter is provided
    IF p_business_name IS NULL AND p_primary_phone IS NULL AND p_business_website IS NULL AND p_business_itin IS NULL AND p_registration_number IS NULL THEN
        SET error_code = '48101';
        SET error_message = 'At least one search parameter must be provided.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_business_name IS NOT NULL AND p_primary_phone IS NOT NULL THEN
        -- Get partners by both business name and primary phone
        SELECT 
            rp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM registered_partner rp
        WHERE rp.business_name LIKE CONCAT('%', p_business_name, '%')
        AND rp.primary_phone = p_primary_phone;
        
    ELSEIF p_business_name IS NOT NULL THEN
        -- Get partners by business name
        SELECT 
            rp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM registered_partner rp
        WHERE rp.business_name LIKE CONCAT('%', p_business_name, '%');
        
    ELSEIF p_primary_phone IS NOT NULL THEN
        -- Get partners by primary phone
        SELECT 
            rp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM registered_partner rp
        WHERE rp.primary_phone = p_primary_phone;
        
    ELSEIF p_business_website IS NOT NULL THEN
        -- Get partners by business website
        SELECT 
            rp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM registered_partner rp
        WHERE rp.business_website LIKE CONCAT('%', p_business_website, '%');
        
    ELSEIF p_business_itin IS NOT NULL THEN
        -- Get partners by business ITIN
        SELECT 
            rp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM registered_partner rp
        WHERE rp.business_itin = p_business_itin;
        
    ELSEIF p_registration_number IS NOT NULL THEN
        -- Get partners by registration number
        SELECT 
            rp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM registered_partner rp
        WHERE rp.registration_number = p_registration_number;
    END IF;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful read
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ', 
        CASE 
            WHEN p_business_name IS NOT NULL AND p_primary_phone IS NOT NULL THEN 'Partners retrieved by business name and primary phone'
            WHEN p_business_name IS NOT NULL THEN 'Partners retrieved by business name'
            WHEN p_primary_phone IS NOT NULL THEN 'Partners retrieved by primary phone'
            WHEN p_business_website IS NOT NULL THEN 'Partners retrieved by business website'
            WHEN p_business_itin IS NOT NULL THEN 'Partners retrieved by business ITIN'
            WHEN p_registration_number IS NOT NULL THEN 'Partners retrieved by registration number'
            ELSE 'Partners retrieved'
        END, 
        p_created_user, 
        'REGISTERED_PARTNER_GET', 
        CASE 
            WHEN p_business_name IS NOT NULL AND p_primary_phone IS NOT NULL THEN CONCAT('Business Name: ', p_business_name, ', Primary Phone: ', p_primary_phone)
            WHEN p_business_name IS NOT NULL THEN CONCAT('Business Name: ', p_business_name)
            WHEN p_primary_phone IS NOT NULL THEN CONCAT('Primary Phone: ', p_primary_phone)
            WHEN p_business_website IS NOT NULL THEN CONCAT('Business Website: ', p_business_website)
            WHEN p_business_itin IS NOT NULL THEN CONCAT('Business ITIN: ', p_business_itin)
            WHEN p_registration_number IS NOT NULL THEN CONCAT('Registration Number: ', p_registration_number)
            ELSE 'All partners'
        END,
        start_time, end_time, execution_time
    );
    
END //
DELIMITER ;
