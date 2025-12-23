-- Stored Procedures and Functions

-- Procedure: account_profile_get
DROP PROCEDURE IF EXISTS `account_profile_get`;

DELIMITER $$
CREATE PROCEDURE `account_profile_get`(IN p_account_id BIGINT)
BEGIN
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;

    SET error_code = '45017_ACCOUNT_ID_DOES_NOT_EXIST';
    SET error_message = 'No profile_personal record exists for the given account_id';

    IF EXISTS (
        SELECT 1 
        FROM matrimony_services.profile_personal 
        WHERE account_id = p_account_id
    ) THEN
        SELECT * 
        FROM matrimony_services.profile_personal 
        WHERE account_id = p_account_id;
    ELSE
        SELECT error_code AS error_code, error_message AS error_message;
    END IF;
END$$
DELIMITER ;

-- Procedure: admin_api_clients_create
DROP PROCEDURE IF EXISTS `admin_api_clients_create`;

DELIMITER $$
CREATE PROCEDURE `admin_api_clients_create`(
    IN p_partner_id INT,
    IN p_partner_root_domain VARCHAR(50),
    IN p_partner_admin_url VARCHAR(100),
    IN p_activation_notes VARCHAR(255),
    IN p_activated_by INT
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    -- Check if partner exists and get partner name
    DECLARE v_partner_name VARCHAR(255) DEFAULT NULL;
    DECLARE v_partner_exists INT DEFAULT 0;    
    -- Generate random PIN (4-6 digits)
    DECLARE v_partner_pin INT;
    -- Generate api_key
    DECLARE p_api_key VARCHAR(64);
    -- Declare handler for SQL exceptions
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;            
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, 
            activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_activated_by, 'API_CLIENTS_CREATE', 
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
            'ERROR', error_message, p_activated_by, 'API_CLIENTS_CREATE', 
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
    
    -- Validation: Ensure required fields are provided
    /*
    IF p_partner_id IS NULL OR p_partner_id <= 0 THEN
        SET error_code = '49001';
        SET error_message = 'Partner ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    

    
    SELECT COUNT(*), business_name INTO v_partner_exists, v_partner_name
    FROM registered_partner
    WHERE reg_partner_id = p_partner_id
    AND Is_active = b'1';
    
    IF v_partner_exists = 0 THEN
        SET error_code = '49004';
        SET error_message = CONCAT('Partner with ID ', p_partner_id, ' does not exist or is not active.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    */
    

    -- set v_partner_name = "inernal Partner account";
    IF p_partner_root_domain IS NULL OR p_partner_root_domain = '' THEN
        SET error_code = '49002';
        SET error_message = 'Partner root domain is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    IF p_activation_notes IS NULL OR p_activation_notes = '' THEN
        SET error_code = '49003';
        SET error_message = 'Activation notes are required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    

    SET v_partner_pin = FLOOR(RAND() * 900000) + 100000;
    
    -- Generate UUID for API key
    SET p_api_key = UUID();
    -- Remove dashes to make it more compact
    SET p_api_key = REPLACE(p_api_key, '-', '');

    -- Insert new API client
    INSERT INTO api_clients (
        partner_name,
        api_key,
        is_active,
        partner_id,
        partner_root_domain,
        partner_admin_url,
        partner_pin,
        activated_date,
        activation_notes,
        activated_by
    ) VALUES (
        v_partner_name,
        p_api_key,
        1, -- Active by default
        p_partner_id,
        p_partner_root_domain,
        p_partner_admin_url,
        v_partner_pin,
        NOW(),
        p_activation_notes,
        p_activated_by
    );
  
    -- Get the ID of the newly inserted client
    SET @new_client_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('API client created: ', v_partner_name), 
        p_activated_by, 
        'API_CLIENTS_CREATE', 
        CONCAT('Client ID: ', @new_client_id, ', API Key: ', p_api_key, ', PIN: ', v_partner_pin),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;

    -- Return success with the new client details
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        @new_client_id AS client_id,
        p_api_key AS api_key;
    
END$$
DELIMITER ;

-- Procedure: admin_registered_partner_delete
DROP PROCEDURE IF EXISTS `admin_registered_partner_delete`;

DELIMITER $$
CREATE PROCEDURE `admin_registered_partner_delete`(
    IN p_reg_partner_id INT,
    IN p_created_user VARCHAR(45),
    IN p_verification_comment VARCHAR(255)
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
            'ERROR', error_message, p_created_user, 'ADMIN_REGISTERED_PARTNER_DELETE', 
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
            'ERROR', error_message, p_created_user, 'ADMIN_REGISTERED_PARTNER_DELETE', 
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
        SET error_code = '48301';
        SET error_message = 'Partner ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if partner exists
    SELECT COUNT(*) INTO partner_exists
    FROM registered_partner
    WHERE reg_partner_id = p_reg_partner_id;
    
    IF partner_exists = 0 THEN
        SET error_code = '48302';
        SET error_message = 'Partner with the provided ID does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Soft delete - mark as inactive, update verification status and comment
    UPDATE registered_partner
    SET 
        Is_active = b'0',
        verification_status = 'deleted',
        verification_comment = p_verification_comment,
        date_modified = NOW(),
        user_modified = p_created_user
    WHERE reg_partner_id = p_reg_partner_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful deletion
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'DELETE', 
        CONCAT('Registered partner deleted with ID: ', p_reg_partner_id), 
        p_created_user, 
        'ADMIN_REGISTERED_PARTNER_DELETE', 
        CONCAT('Partner ID: ', p_reg_partner_id, ', Verification Comment: ', p_verification_comment),
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
    
END$$
DELIMITER ;

-- Procedure: admin_registered_partner_update
DROP PROCEDURE IF EXISTS `admin_registered_partner_update`;

DELIMITER $$
CREATE PROCEDURE `admin_registered_partner_update`(
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
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if partner exists
    SELECT COUNT(*) INTO partner_exists
    FROM registered_partner
    WHERE reg_partner_id = p_reg_partner_id;
    
    IF partner_exists = 0 THEN
        SET error_code = '48202';
        SET error_message = 'Partner with the provided ID does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
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
    
END$$
DELIMITER ;

-- Procedure: api_clients_create
DROP PROCEDURE IF EXISTS `api_clients_create`;

DELIMITER $$
CREATE PROCEDURE `api_clients_create`(
    IN p_partner_name VARCHAR(255),
    IN p_partner_id INT,
    IN p_partner_root_domain VARCHAR(50),
    IN p_partner_admin_url VARCHAR(100),
    IN p_activation_notes VARCHAR(255),
    IN p_activated_by INT,
    OUT p_api_key VARCHAR(64),
    OUT p_partner_pin INT
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
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_activated_by, 'API_CLIENTS_CREATE', 
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
            'ERROR', error_message, p_activated_by, 'API_CLIENTS_CREATE', 
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
    
    -- Validation: Ensure required fields are provided
    IF p_partner_name IS NULL OR p_partner_name = '' THEN
        SET error_code = '49001';
        SET error_message = 'Partner name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Generate random PIN (4-6 digits)
    SET p_partner_pin = FLOOR(RAND() * 900000) + 100000;
    
    -- Generate UUID for API key
    SET p_api_key = UUID();
    -- Remove dashes to make it more compact
    SET p_api_key = REPLACE(p_api_key, '-', '');
    
    -- Insert new API client
    INSERT INTO api_clients (
        partner_name,
        api_key,
        is_active,
        partner_id,
        partner_root_domain,
        partner_admin_url,
        partner_pin,
        activated_date,
        activation_notes,
        activated_by
    ) VALUES (
        p_partner_name,
        p_api_key,
        1, -- Active by default
        p_partner_id,
        p_partner_root_domain,
        p_partner_admin_url,
        p_partner_pin,
        NOW(),
        p_activation_notes,
        p_activated_by
    );
    
    -- Get the ID of the newly inserted client
    SET @new_client_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('API client created: ', p_partner_name), 
        p_activated_by, 
        'API_CLIENTS_CREATE', 
        CONCAT('Client ID: ', @new_client_id, ', API Key: ', p_api_key, ', PIN: ', p_partner_pin),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new client details
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        @new_client_id AS client_id,
        p_api_key AS api_key,
        p_partner_pin AS partner_pin;
    
END$$
DELIMITER ;

-- Procedure: api_clients_get
DROP PROCEDURE IF EXISTS `api_clients_get`;

DELIMITER $$
CREATE PROCEDURE `api_clients_get`(
    IN p_api_key VARCHAR(255),
    IN p_domain  VARCHAR(255)
)
BEGIN
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;

    -- normalized parameters: treat empty strings as NULL
    DECLARE v_api_key VARCHAR(255) DEFAULT NULL;
    DECLARE v_domain  VARCHAR(255) DEFAULT NULL;

    SET v_api_key = NULLIF(TRIM(p_api_key), '');
    SET v_domain  = NULLIF(TRIM(p_domain), '');

    IF v_api_key IS NOT NULL OR v_domain IS NOT NULL THEN
        -- user asked for a specific match (return full row(s))
        SET error_code = '45018_API_CLIENT_NOT_FOUND';
        SET error_message = 'No active API client found for the provided parameters';

        IF EXISTS (
            SELECT 1
            FROM matrimony_services.api_clients
            WHERE (v_api_key IS NULL OR api_key = v_api_key)
              AND (v_domain IS NULL  OR partner_root_domain = v_domain)
        ) THEN
            SELECT *
            FROM matrimony_services.api_clients
            WHERE (v_api_key IS NULL OR api_key = v_api_key)
              AND (v_domain IS NULL  OR partner_root_domain = v_domain);
        ELSE
            SELECT error_code AS error_code, error_message AS error_message;
        END IF;

    ELSE
        -- no params: return list of active partner_root_domain values (non-null, non-empty)
        SET error_code = '45016_NO_ACTIVE_API_CLIENTS';
        SET error_message = 'No active API clients found';

        IF EXISTS (
            SELECT 1
            FROM matrimony_services.api_clients
            WHERE is_active = 1
              AND partner_root_domain IS NOT NULL
              AND partner_root_domain != ''
        ) THEN
            SELECT partner_root_domain
            FROM matrimony_services.api_clients
            WHERE is_active = 1
              AND partner_root_domain IS NOT NULL
              AND partner_root_domain != '';
        ELSE
            SELECT error_code AS error_code, error_message AS error_message;
        END IF;
    END IF;
END$$
DELIMITER ;

-- Procedure: common_log_activity
DROP PROCEDURE IF EXISTS `common_log_activity`;

DELIMITER $$
CREATE PROCEDURE `common_log_activity`(
    IN p_log_type VARCHAR(45),           -- 'CREATE', 'UPDATE', 'DELETE', 'ERROR', etc.
    IN p_message VARCHAR(255),           -- Description of the activity
    IN p_created_by VARCHAR(150),        -- User who performed the action
    IN p_activity_type VARCHAR(100),     -- Type of activity (e.g., 'PROFILE_ADDRESS_CREATE')
    IN p_activity_details VARCHAR(255),  -- Additional details about the activity
    IN p_start_time DATETIME,            -- When the activity started
    IN p_end_time DATETIME               -- When the activity ended (NULL for ongoing)
)
BEGIN
    -- Calculate execution time in milliseconds
    DECLARE execution_time INT;
    
    -- If end_time is NULL, use current time
    IF p_end_time IS NULL THEN
        SET p_end_time = NOW();
    END IF;
    
    -- Calculate execution time
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, p_start_time, p_end_time) / 1000;
    
    -- Insert into activity_log table
    INSERT INTO activity_log (
        log_type, 
        message, 
        created_by, 
        activity_type, 
        activity_details,
        start_time, 
        end_time, 
        execution_time
    ) VALUES (
        p_log_type,
        p_message,
        p_created_by,
        p_activity_type,
        p_activity_details,
        p_start_time,
        p_end_time,
        execution_time
    );
END$$
DELIMITER ;

-- Procedure: common_log_error
DROP PROCEDURE IF EXISTS `common_log_error`;

DELIMITER $$
CREATE PROCEDURE `common_log_error`(
    IN p_error_code VARCHAR(100),        -- Error code (e.g., '47001')
    IN p_error_message VARCHAR(255),     -- Error message
    IN p_created_by VARCHAR(150),        -- User who performed the action
    IN p_activity_type VARCHAR(100),     -- Type of activity (e.g., 'PROFILE_ADDRESS_CREATE')
    IN p_start_time DATETIME             -- When the activity started
)
BEGIN
    -- Log error to activity_log
    CALL common_log_activity(
        'ERROR',                                  -- log_type
        p_error_message,                          -- message
        p_created_by,                             -- created_by
        p_activity_type,                          -- activity_type
        CONCAT('Error Code: ', p_error_code),     -- activity_details
        p_start_time,                             -- start_time
        NOW()                                     -- end_time
    );
END$$
DELIMITER ;

-- Procedure: eb_account_login_create
DROP PROCEDURE IF EXISTS `eb_account_login_create`;

DELIMITER $$
CREATE PROCEDURE `eb_account_login_create`(
   IN p_email VARCHAR(150),
    IN p_user_pwd VARCHAR(150),
    IN p_first_name VARCHAR(45),
    IN p_middle_name VARCHAR(45),
    IN p_last_name VARCHAR(45),
    IN p_birth_date DATE,
    IN p_gender INT,
    IN p_primary_phone VARCHAR(10),
    IN p_primary_phone_country VARCHAR(5),
    IN p_primary_phone_type INT,
    IN p_secondary_phone VARCHAR(10),
    IN p_secondary_phone_country VARCHAR(5),
    IN p_secondary_phone_type INT,
    IN p_address_line1 VARCHAR(45),
	IN p_address_line2 VARCHAR(45),
    IN p_city VARCHAR(45),
    IN p_state VARCHAR(45),
    IN p_zip VARCHAR(45),
    IN p_country VARCHAR(45),
    IN p_photo VARCHAR(45),
    IN p_secret_question VARCHAR(45),
    IN p_secret_answer VARCHAR(45),
    IN p_partner_id INT

)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_account_id INT;
    DECLARE sno VARCHAR(25) DEFAULT '';
    DECLARE account_code VARCHAR(50);
	DECLARE min_birth_date DATE;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
	
  -- Declare handler for SQL exceptions 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
		GET DIAGNOSTICS CONDITION 1
			error_message = MESSAGE_TEXT,
			error_code = MYSQL_ERRNO;
        ROLLBACK;		
		-- Log error using common_log_error procedure
		CALL common_log_error(
			error_code,
			error_message,
			p_email,
			'ACCOUNT_LOGIN_CREATE',
			start_time
		);
		
		SELECT 
			'fail' AS status,
			'SQL Exception' as error_type,
			null AS account_id,
			null AS account_code,
			null AS email,
            error_code,
            error_message;	            
    END;
    
    -- Declare handler for custom errors (SQLSTATE starting with '45')
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        ROLLBACK;
        
        -- Log error using common_log_error procedure
        CALL common_log_error(
            error_code,
            error_message,
            p_email,
            'ACCOUNT_LOGIN_CREATE',
            start_time
        );
        
        -- Return error information
		SELECT 
            'fail' AS status,
			'Validation Exception' as error_type,
			null AS account_id,
			null AS account_code,
			null AS email,
            error_code,
            error_message;	
    END;
    
    -- Record start time for performance tracking
    SET start_time = NOW();
    
    -- Start transaction at the beginning
    START TRANSACTION;
    -- Calculate the minimum birth date (20 years ago from today)
    SET min_birth_date = DATE_SUB(CURDATE(), INTERVAL 20 YEAR);
    
    -- Validation logic
    -- Check if email is provided
    IF p_email IS NULL OR p_email = '' THEN
        SET error_code = '45001_MISSING_EMAIL';
        SET error_message = 'Email is required';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if password is provided
    IF p_user_pwd IS NULL OR p_user_pwd = '' THEN
        SET error_code = '45002_MISSING_PASSWORD';
        SET error_message = 'Password is required';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if first name is provided
    IF p_first_name IS NULL OR p_first_name = '' THEN
        SET error_code = '45003_MISSING_FIRST_NAME';
        SET error_message = 'First name is required';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if last name is provided
    IF p_last_name IS NULL OR p_last_name = '' THEN
        SET error_code = '45004_MISSING_LAST_NAME';
        SET error_message = 'Last name is required';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
       
    -- Check if birth date is in the future
    IF p_birth_date > CURDATE() THEN
        SET error_code = '45007_INVALID_BIRTH_DATE';
        SET error_message = 'Birth date cannot be in the future';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if user is at least 20 years old
    IF p_birth_date > min_birth_date THEN
        SET error_code = '45008_UNDERAGE';
        SET error_message = 'User must be at least 20 years old';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM account a WHERE a.email = p_email) THEN
        SET error_code = '45005_DUPLICATE_EMAIL';
        SET error_message = 'Email already exists';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if phone already exists
    IF EXISTS(SELECT 1 FROM account as a WHERE a.primary_phone = p_primary_phone) THEN
        SET error_code = '45006_DUPLICATE_PHONE';
        SET error_message = 'Primary phone number already exists';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
		-- Get today created account count to prepare account_id
		SELECT COUNT(*) + 1
		INTO sno
		FROM account
		WHERE DATE_FORMAT(created_date, '%Y-%m-%d') = DATE_FORMAT(NOW(), '%Y-%m-%d');
		
		-- Assign Account Code
		SET account_code = CONCAT(DATE_FORMAT(NOW(), '%Y%m%d-%H%i%s'), CONCAT('-', sno));	
		-- Insert into account table
		INSERT INTO account (
			account_code,
			email, 
			first_name,
			middle_name,
			last_name,
			primary_phone,
			primary_phone_country,
			primary_phone_type,
			secondary_phone,
			secondary_phone_country,
			secondary_phone_type,
			birth_date,
			gender,
			address_line1,
			address_line2,
			city,
			state,
			zip,
			country,
			photo,
			secret_question,
			secret_answer,
            registered_partner_id
		)
		VALUES (
			account_code,
			p_email,
			p_first_name,
			p_middle_name,
			p_last_name,
			p_primary_phone,
			p_primary_phone_country,
			p_primary_phone_type,
			p_secondary_phone,
			p_secondary_phone_country,
			p_secondary_phone_type,
			p_birth_date,
			p_gender,
			p_address_line1,
			p_address_line2,
			p_city,
			p_state,
			p_zip,
			p_country,
			p_photo,
			p_secret_question,
			p_secret_answer,
            p_partner_id
		);
		
		-- Get latest account table inserted record id
		SET new_account_id = LAST_INSERT_ID();	
		-- Insert into login table
		INSERT INTO login (
			account_id,
			user_name,
			password
            -- p_account_type
		)
		VALUES (
			new_account_id,
			p_email, -- Using email as username
			p_user_pwd
            -- p_account_type
		);
    
    -- If we got here, everything succeeded, so commit
    COMMIT;  
    call matrimony_services.eb_enable_disable_account(new_account_id, 1, 'Auto account verify enabled', 'system');
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    CALL common_log_activity(
        'CREATE', 
        CONCAT('Account created: ', p_email), 
        p_email, 
        'ACCOUNT_LOGIN_CREATE', 
        CONCAT('Account ID: ', new_account_id, ', Account Code: ', account_code),
        start_time,
        end_time
    );	 
    
    -- Return success results
	SELECT 
        'success' AS status,
        null as error_type,
		new_account_id AS account_id,
		account_code,
		p_email AS email,
		null as error_code,
		null as error_message;		


END$$
DELIMITER ;

-- Procedure: eb_account_profile_get
DROP PROCEDURE IF EXISTS `eb_account_profile_get`;

DELIMITER $$
CREATE PROCEDURE `eb_account_profile_get`(
    IN p_account_id INT,
    IN p_email VARCHAR(100),
    IN p_username VARCHAR(45),
    IN p_created_user VARCHAR(100)
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
            'ERROR', error_message, p_created_user, 'ACCOUNT_PROFILE_GET', 
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
            'ERROR', error_message, p_created_user, 'ACCOUNT_PROFILE_GET', 
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
    IF p_account_id IS NULL AND p_email IS NULL AND p_username IS NULL THEN
        SET error_code = '47001';
        SET error_message = 'At least one search parameter (account_id, email, or username) must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    SELECT 
        a.*,                                  -- All account fields
        l.login_id,                           -- Login information
        l.user_name,
        l.is_active AS login_is_active,
        l.active_date AS login_active_date,
        l.created_date AS login_created_date,
        l.modified_date AS login_modified_date,
        l.deactivation_date AS login_deactivation_date,
        pp.profile_id,                        -- Profile personal information
        pp.gender AS profile_gender,
        pp.birth_date AS profile_birth_date,
        pp.phone_mobile AS profile_phone_mobile,
        pp.phone_home AS profile_phone_home,
        pp.phone_emergency AS profile_phone_emergency,
        pp.email_id AS profile_email,
        pp.marital_status,
        pp.religion,
        pp.nationality,
        pp.caste,
        pp.height_inches,
        pp.height_cms,
        pp.weight,
        pp.weight_units,
        pp.complexion,
        pp.linkedin,
        pp.facebook,
        pp.instagram,
        pp.whatsapp_number,
        pp.profession,
        pp.disability,
        photo.url,
        pp.is_active AS profile_is_active,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message
    FROM 
        account a
    LEFT JOIN 
        login l ON a.account_id = l.account_id
    LEFT JOIN 
        profile_personal pp ON a.account_id = pp.account_id
	LEFT JOIN 
		(SELECT profile_id, photo_type, url FROM profile_photo INNER JOIN lookup_table on photo_type = id where caption ='Clear Headshot') photo  ON pp.profile_id = photo.profile_id
    WHERE 
        (p_account_id IS NULL OR a.account_id = p_account_id)
        AND (p_email IS NULL OR a.email = p_email)
        AND (p_username IS NULL OR l.user_name = p_username)
        AND (pp.is_active = 1 OR pp.is_active IS NULL);
    
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
            WHEN p_account_id IS NOT NULL THEN CONCAT('Account profile retrieved by ID: ', p_account_id)
            WHEN p_email IS NOT NULL THEN CONCAT('Account profile retrieved by email: ', p_email)
            ELSE CONCAT('Account profile retrieved by username: ', p_username)
        END, 
        p_created_user, 
        'ACCOUNT_PROFILE_GET', 
        CONCAT(
            IFNULL(CONCAT('Account ID: ', p_account_id), ''),
            IFNULL(CONCAT(', Email: ', p_email), ''),
            IFNULL(CONCAT(', Username: ', p_username), '')
        ),
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_account_update
DROP PROCEDURE IF EXISTS `eb_account_update`;

DELIMITER $$
CREATE PROCEDURE `eb_account_update`(
    IN p_account_code VARCHAR(36),
    IN p_email VARCHAR(150),
    IN p_first_name VARCHAR(50),
    IN p_middle_name VARCHAR(50),
    IN p_last_name VARCHAR(50),
    IN p_primary_phone VARCHAR(20),
    IN p_primary_phone_country VARCHAR(5),
    IN p_primary_phone_type VARCHAR(20),
    IN p_birth_date DATE,
    IN p_gender VARCHAR(10),
    IN p_address_line1 VARCHAR(100),
    IN p_address_line2 VARCHAR(100),
    IN p_city VARCHAR(50),
    IN p_state VARCHAR(50),
    IN p_zip VARCHAR(10),
    IN p_country VARCHAR(50),
    IN p_photo VARCHAR(255),
    IN p_secondary_phone VARCHAR(20),
    IN p_secondary_phone_country VARCHAR(5),
    IN p_secondary_phone_type VARCHAR(20)
)
BEGIN
    UPDATE account
    SET 
        first_name = COALESCE(p_first_name, first_name),
        middle_name = COALESCE(p_middle_name, middle_name),
        last_name = COALESCE(p_last_name, last_name),
        primary_phone = COALESCE(p_primary_phone, primary_phone),
        primary_phone_country = COALESCE(p_primary_phone_country, primary_phone_country),
        primary_phone_type = COALESCE(p_primary_phone_type, primary_phone_type),
        birth_date = COALESCE(p_birth_date, birth_date),
        gender = COALESCE(p_gender, gender),
        address_line1 = COALESCE(p_address_line1, address_line1),
        address_line2 = COALESCE(p_address_line2, address_line2),
        city = COALESCE(p_city, city),
        state = COALESCE(p_state, state),
        zip = COALESCE(p_zip, zip),
        country = COALESCE(p_country, country),
        photo = COALESCE(p_photo, photo),
        secondary_phone = COALESCE(p_secondary_phone, secondary_phone),
        secondary_phone_country = COALESCE(p_secondary_phone_country, secondary_phone_country),
        secondary_phone_type = COALESCE(p_secondary_phone_type, secondary_phone_type),
        modified_date = NOW(),
        modified_user = 'SYSTEM'
    WHERE account_code = p_account_code
    AND email = p_email;
    
     -- If we got here, everything succeeded, so commit
    COMMIT;
    
    -- Return success results
	SELECT 
		ROW_COUNT() as affected_rows,
        'success' AS status,
        null as error_type,
		p_account_code,
		p_email AS email,
		null as error_code,
		null as error_message;	
END$$
DELIMITER ;

-- Procedure: eb_enable_disable_account
DROP PROCEDURE IF EXISTS `eb_enable_disable_account`;

DELIMITER $$
CREATE PROCEDURE `eb_enable_disable_account`(
    IN p_account_id INT,
    IN p_is_active TINYINT,
    IN p_reason VARCHAR(255),
    IN p_modified_user VARCHAR(50)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE account_exists INT DEFAULT 0;
    
    -- Variables for activity tracking
    DECLARE start_time DATETIME DEFAULT NOW();
    DECLARE end_time DATETIME;
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    -- Record start time for activity tracking
    BEGIN
    
        -- Only get SQL diagnostic info if we don't already have a custom error
        IF error_code IS NULL THEN
            GET DIAGNOSTICS CONDITION 1
                @sqlstate = RETURNED_SQLSTATE,
                @errno = MYSQL_ERRNO,
                @text = MESSAGE_TEXT;                
            SET error_code = CONCAT('SQL_ERROR_', @errno);
            SET error_message = @text;
		ELSE 
			set error_message = error_message; 
        END IF;
        
        -- Rollback the transaction
        ROLLBACK;
        

        -- Log error using common_log_error procedure
        CALL common_log_error(
            error_code,
            error_message,
            p_modified_user,
            'ENABLE_DISABLE_ACCOUNT',
            start_time
        );
        
        -- Return error information in result sets
        SELECT NULL AS account_id;
        SELECT error_code AS error_code, error_message AS error_message;
        -- Ensure client sees the error
		RESIGNAL;
    END;
    
     -- Check if account_id is provided
    IF p_account_id IS NULL THEN
        SET error_code = '45010_MISSING_ACCOUNT_ID';
        SET error_message = 'Account ID is required';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if is_active is provided
    IF p_is_active IS NULL THEN
        SET error_code = '45060_MISSING_IS_ACTIVE';
        SET error_message = 'Active status is required';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if account exists
    SELECT COUNT(*) INTO account_exists 
    FROM account 
    WHERE account_id = p_account_id 
    AND (is_deleted IS NULL OR is_deleted = 0);
    
    
    IF account_exists = 0 THEN
        SET error_code = '45011_ACCOUNT_NOT_FOUND';
        SET error_message = 'Account not found';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
 
    -- Start transaction
    START TRANSACTION;
    
    -- Update account status
    UPDATE account
    SET 
        is_active = p_is_active,
        modified_date = NOW(),
        modified_user = p_modified_user,
        -- Set activation or deactivation information based on the status
        activation_date = CASE WHEN p_is_active = 1 THEN NOW() ELSE activation_date END,
        activated_user = CASE WHEN p_is_active = 1 THEN p_modified_user ELSE activated_user END,
        deactivated_date = CASE WHEN p_is_active = 0 THEN NOW() ELSE deactivated_date END,
        deactivated_user = CASE WHEN p_is_active = 0 THEN p_modified_user ELSE deactivated_user END,
        deactivation_reason = CASE WHEN p_is_active = 0 THEN p_reason ELSE deactivation_reason END
    WHERE 
        account_id = p_account_id;
	
   
    -- Update login status
    UPDATE login
    SET 
        is_active = p_is_active,
        active_date = NOW(),
        modified_date = NOW(),
        modified_user = p_modified_user
    WHERE 
        account_id = p_account_id
	LIMIT 1;

     -- Commit the transaction
    COMMIT;
    
    -- Record end time for activity tracking
    SET end_time = NOW();
    
    -- Log the successful account status change
    CALL common_log_activity(
        CASE WHEN p_is_active = 1 THEN 'ENABLE' ELSE 'DISABLE' END, 
        CASE WHEN p_is_active = 1 THEN 'Account enabled' ELSE 'Account disabled' END, 
        p_modified_user, 
        'ENABLE_DISABLE_ACCOUNT', 
        CONCAT('Account ID: ', p_account_id, CASE WHEN p_is_active = 0 AND p_reason IS NOT NULL THEN CONCAT(', Reason: ', p_reason) ELSE '' END),
        start_time,
        end_time
    );
     
    -- Return success results
    /* SELECT 
        p_account_id AS account_id,
        CASE WHEN p_is_active = 1 THEN 'Account enabled successfully' ELSE 'Account disabled successfully' END AS message;
    
    SELECT 
        NULL AS error_code,
        NULL AS error_message;
	*/
END$$
DELIMITER ;

-- Procedure: eb_login_validate
DROP PROCEDURE IF EXISTS `eb_login_validate`;

DELIMITER $$
CREATE PROCEDURE `eb_login_validate`(
    IN email VARCHAR(45), 
    IN pwd VARCHAR(150),
    IN ip VARCHAR(20), 
    IN sysname VARCHAR(45), 
    IN usragent VARCHAR(150), 
    IN location VARCHAR(45))
BEGIN
    DECLARE id_login INT;
    DECLARE email_otp INT;
    DECLARE start_date DATETIME;
    DECLARE id_account INT;
    
    -- Variables for activity tracking
    DECLARE log_start_time DATETIME;
    DECLARE log_end_time DATETIME;
    DECLARE error_code VARCHAR(100);
    DECLARE error_message VARCHAR(255);
    
    -- Record start time for activity tracking
    SET log_start_time = NOW();
    
    IF EXISTS(SELECT  login_id,  a.account_id 
        FROM account a INNER JOIN login l on a.account_id = l.account_id 
        WHERE user_name = email 
        and (COALESCE(a.is_active,0) = 0)) THEN
        -- Insert failed login attempt into login_history
        INSERT INTO login_history(
            login_name,
            login_date, 
            login_status, 
            email_otp, 
            ip_address,
            system_name,
            user_agent,
            location)
        VALUES(
            email,
            NOW(), 
            0,
            -1,
            ip, 
            sysname, 
            usragent,
            location);

        -- Log failed login attempt
        SET error_code = '45100_INACTIVE_ACCOUNT_EMAIL';
        SET error_message = 'Either Account or Login was not enabled.';
        
        CALL common_log_error(
            error_code,
            error_message,
            email,
            'LOGIN_VALIDATE_INACTIVE',
            log_start_time
        );
        
        -- Return -1 for OTP and NULL for Account ID if login fails
        SELECT
        'Fail' AS status,
        null AS otp, 
        NULL AS account_id,
        error_code AS error_code,
        error_message AS error_message;
    -- Check if the username and password match 
    ELSEIF EXISTS (
    SELECT  login_id,  a.account_id 
        FROM account a INNER JOIN login l on a.account_id = l.account_id 
        WHERE user_name = email 
        AND BINARY password = pwd and COALESCE(l.is_active,0) = 1 and COALESCE(a.is_active,0) = 1) THEN
        /*
		-- Will uncomment below code if OTP is duplicated.
		REPEAT
		  SET email_otp = FLOOR(1000 + RAND() * 9000);
		  -- Check if this OTP exists and is still valid
		  SET @otp_exists = (SELECT COUNT(*) FROM login_history 
							WHERE email_otp = email_otp 
							AND email_otp_valid_end > NOW());
		UNTIL @otp_exists = 0 END REPEAT;
		*/
        
        -- Generate email OTP 
        SET email_otp = FLOOR(1000 + RAND() * 9000);
        SET start_date = NOW();

        -- Get Login ID and Account ID 
        SELECT 
        login_id, 
        a.account_id INTO id_login, id_account
        FROM account a INNER JOIN login l on a.account_id = l.account_id 
        WHERE user_name = email 
        AND BINARY password = pwd and COALESCE(l.is_active,0) = 1 and COALESCE(a.is_active,0) = 1 ;

        -- Insert into login_history table
        INSERT INTO login_history(
            login_name,
            login_date, 
            login_status, 
            email_otp, 
            ip_address,
            system_name,
            user_agent,
            location,
            login_id_on_success,
            email_otp_valid_start,
            email_otp_valid_end)
        VALUES(
            email,
            NOW(), 
            1,
            email_otp,
            ip, 
            sysname, 
            usragent,
            location,
            id_login,
            start_date,
            DATE_ADD(start_date, INTERVAL 2 MINUTE));

        -- Log successful login
        SET log_end_time = NOW();
        
        CALL common_log_activity(
            'LOGIN', 
            CONCAT('Successful login: ', email), 
            email, 
            'LOGIN_VALIDATE', 
            CONCAT('Account ID: ', id_account, ', OTP generated: ', email_otp),
            log_start_time,
            log_end_time
        );
        
        -- Return the OTP and Account ID
        SELECT 
        'success' as status,
        email_otp AS otp, 
        id_account AS account_id,
        null AS error_code,
        null AS error_message;

    ELSE 
        -- Insert failed login attempt into login_history
        INSERT INTO login_history(
            login_name,
            login_date, 
            login_status, 
            email_otp, 
            ip_address,
            system_name,
            user_agent,
            location)
        VALUES(
            email,
            NOW(), 
            0,
            -1,
            ip, 
            sysname, 
            usragent,
            location);

        -- Log failed login attempt
        SET error_code = '45100_INVLID_EMAIL_PASSWORD';
        SET error_message = 'Email or Password is NOT Correct';
        
        CALL common_log_error(
            error_code,
            error_message,
            email,
            'LOGIN_VALIDATE',
            log_start_time
        );
        
        -- Return -1 for OTP and NULL for Account ID if login fails
        SELECT
        'Fail' AS status,
        null AS otp, 
        NULL AS account_id,
        error_code AS error_code,
        error_message AS error_message;
    END IF;
END$$
DELIMITER ;

-- Procedure: eb_payment_create
DROP PROCEDURE IF EXISTS `eb_payment_create`;

DELIMITER $$
CREATE PROCEDURE `eb_payment_create`(
    IN p_account_id INT,
    IN p_client_reference_id VARCHAR(100),
    IN p_session_id VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_name VARCHAR(100),
    IN p_address VARCHAR(256),
    IN p_country VARCHAR(100),
    IN p_state VARCHAR(100),
    IN p_city VARCHAR(100),
    IN p_zip_code VARCHAR(100),
    IN p_amount DECIMAL(10,2),
    IN p_currency VARCHAR(10),
    IN p_payment_status VARCHAR(50),
    IN p_payment_mode VARCHAR(50),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- All DECLARE statements must come first
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_payment_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;

    -- Exception handlers
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;

        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PAYMENT_CREATE',
            CONCAT('Error Code: ', error_code),
            start_time, NOW(), TIMESTAMPDIFF(MICROSECOND, start_time, NOW()) / 1000
        );

        SELECT 'fail' AS status, 'SQL Exception' AS error_type, error_code, error_message;
    END;

    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        ROLLBACK;

        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PAYMENT_CREATE',
            CONCAT('Error Code: ', error_code),
            start_time, NOW(), TIMESTAMPDIFF(MICROSECOND, start_time, NOW()) / 1000
        );

        SELECT 'fail' AS status, 'Validation Exception' AS error_type, error_code, error_message;
    END;

    -- Start time
    SET start_time = NOW();

    -- Start transaction
    START TRANSACTION;

    -- Validations
    IF p_account_id IS NULL OR p_account_id <= 0 THEN
        SET error_code = '49000';
        SET error_message = 'Account ID is required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF p_client_reference_id IS NULL OR TRIM(p_client_reference_id) = '' THEN
        SET error_code = '49001';
        SET error_message = 'Client reference ID is required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SET error_code = '49002';
        SET error_message = 'Amount must be a positive value.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF p_currency IS NULL OR TRIM(p_currency) = '' THEN
        SET error_code = '49003';
        SET error_message = 'Currency is required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Insert payment
    INSERT INTO stripe_payment_intents (
        account_id,
        client_reference_id,
        session_id,
        email,
        name,
        address,
        country,
        state,
        city,
        zip_code,
        amount,
        currency,
        payment_status,
        payment_mode,
        payment_start_date
    ) VALUES (
        p_account_id,
        p_client_reference_id,
        p_session_id,
        p_email,
        p_name,
        p_address,
        p_country,
        p_state,
        p_city,
        p_zip_code,
        p_amount,
        p_currency,
        p_payment_status,
        p_payment_mode,
        NOW()
    );

    SET new_payment_id = LAST_INSERT_ID();

    -- End time & execution
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000;

    -- Log success
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE',
        CONCAT('Payment created for client_reference_id: ', p_client_reference_id),
        p_created_user,
        'PAYMENT_CREATE',
        CONCAT('Payment ID: ', new_payment_id, ', Amount: ', p_amount, ' ', p_currency),
        start_time, end_time, execution_time
    );

    -- Commit transaction
    COMMIT;

    -- Return success
    SELECT 'success' AS status, NULL AS error_type, new_payment_id AS payment_id,
           NULL AS error_code, NULL AS error_message;

END$$
DELIMITER ;

-- Procedure: eb_payment_update_status
DROP PROCEDURE IF EXISTS `eb_payment_update_status`;

DELIMITER $$
CREATE PROCEDURE `eb_payment_update_status`(
    IN p_client_reference_id VARCHAR(100),
    IN p_new_status VARCHAR(50),
    IN p_updated_user VARCHAR(45)
)
BEGIN
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    DECLARE rows_updated INT;
	DECLARE v_account_id INT;

    -- Exception handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;

        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_updated_user, 'PAYMENT_UPDATE_STATUS',
            CONCAT('Error Code: ', error_code, ', ClientRefID: ', p_client_reference_id),
            start_time, NOW(), TIMESTAMPDIFF(MICROSECOND, start_time, NOW()) / 1000
        );

        SELECT 'fail' AS status, 'SQL Exception' AS error_type, error_code, error_message;
    END;

    -- Record start time
    SET start_time = NOW();

    -- Start transaction
    START TRANSACTION;

    -- Validation
    IF p_client_reference_id IS NULL OR TRIM(p_client_reference_id) = '' THEN
        SET error_code = '49100';
        SET error_message = 'Client reference ID is required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF p_new_status IS NULL OR TRIM(p_new_status) = '' THEN
        SET error_code = '49101';
        SET error_message = 'New status is required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Update payment status
    UPDATE stripe_payment_intents
    SET payment_status = p_new_status,
        payment_stop_date = NOW(),
        updated_at = NOW()
    WHERE client_reference_id = p_client_reference_id;

    SET rows_updated = ROW_COUNT();

    -- Record end time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000;



	-- Fetch account_id for the given client_reference_id
	SELECT account_id INTO v_account_id
	FROM stripe_payment_intents
	WHERE client_reference_id = p_client_reference_id
	LIMIT 1;
    
    -- Log success
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Payment status updated for ClientRefID: ', p_client_reference_id), 
        p_updated_user, 
        'PAYMENT_UPDATE_STATUS', 
        CONCAT('Rows affected: ', rows_updated, ', New status: ', p_new_status),
        start_time, end_time, execution_time
    );

    -- Commit
    COMMIT;

    -- Return success
    SELECT 'success' AS status, rows_updated AS affected_rows, p_new_status AS new_status;

END$$
DELIMITER ;

-- Procedure: eb_profile_address_create
DROP PROCEDURE IF EXISTS `eb_profile_address_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_address_create`(
    IN p_profile_id INT,
    IN p_address_type INT,
    IN p_address_line1 VARCHAR(100),
    IN p_address_line2 VARCHAR(100),
    IN p_city VARCHAR(100),
    IN p_state INT,
    IN p_country_id INT,
    IN p_zip VARCHAR(100),
    IN p_landmark1 VARCHAR(100),
    IN p_landmark2 VARCHAR(100),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_address_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_ADDRESS_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_ADDRESS_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '47001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '47002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate address_type
    IF p_address_type IS NULL THEN
        SET error_code = '47003';
        SET error_message = 'Address type is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate address_line1
    IF p_address_line1 IS NULL OR TRIM(p_address_line1) = '' THEN
        SET error_code = '47004';
        SET error_message = 'Address line 1 is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state
    IF p_state IS NULL OR TRIM(p_state) = '' THEN
        SET error_code = '47005';
        SET error_message = 'State is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country_id
    IF p_country_id IS NULL OR p_country_id <= 0 THEN
        SET error_code = '47006';
        SET error_message = 'Country ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip
    IF p_zip IS NULL OR TRIM(p_zip) = '' THEN
        SET error_code = '47007';
        SET error_message = 'ZIP code is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate country_id
    IF p_state IS NULL OR p_state <= 0 THEN
        SET error_code = '47008';
        SET error_message = 'State ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;

    
    -- Insert the new address
    INSERT INTO profile_address (
        profile_id,
        address_type,
        address_line1,
        address_line2,
        city,
        state,
        country_id,
        zip,
        landmark1,
        landmark2,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified
    ) VALUES (
        p_profile_id,
        p_address_type,
        p_address_line1,
        p_address_line2,
        p_city,
        p_state,
        p_country_id,
        p_zip,
        p_landmark1,
        p_landmark2,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0 -- Not verified by default
    );
    
    -- Get the new address ID
    SET new_address_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Address created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_ADDRESS_CREATE', 
        CONCAT('Address ID: ', new_address_id, ', Type: ', p_address_type),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new address ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_address_id AS profile_address_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_address_get
DROP PROCEDURE IF EXISTS `eb_profile_address_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_address_get`(
    IN p_profile_id INT,
    IN p_profile_address_id INT,
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
            'ERROR', error_message, p_created_user, 'PROFILE_ADDRESS_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_ADDRESS_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or profile_address_id is provided
    IF p_profile_id IS NULL AND p_profile_address_id IS NULL THEN
        SET error_code = '47008';
        SET error_message = 'Either profile_id or profile_address_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_address_id IS NOT NULL THEN
        -- Get specific address by ID
        SELECT 
            pa.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_address pa
        WHERE pa.profile_address_id = p_profile_address_id;
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all addresses for a profile
        SELECT 
            pa.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_address pa
        WHERE pa.profile_id = p_profile_id;
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
            WHEN p_profile_address_id IS NOT NULL THEN CONCAT('Address retrieved by ID: ', p_profile_address_id)
            ELSE CONCAT('Addresses retrieved for profile ID: ', p_profile_id)
        END, 
        p_created_user, 
        'PROFILE_ADDRESS_GET', 
        CASE 
            WHEN p_profile_address_id IS NOT NULL THEN CONCAT('Address ID: ', p_profile_address_id)
            ELSE CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_address_update
DROP PROCEDURE IF EXISTS `eb_profile_address_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_address_update`(
    IN p_profile_address_id INT,
    IN p_address_type INT,
    IN p_address_line1 VARCHAR(100),
    IN p_address_line2 VARCHAR(100),
    IN p_city VARCHAR(100),
    IN p_state INT,
    IN p_country_id INT,
    IN p_zip VARCHAR(100),
    IN p_landmark1 VARCHAR(100),
    IN p_landmark2 VARCHAR(100),
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
    DECLARE address_exists INT DEFAULT 0;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'PROFILE_ADDRESS_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Address ID: ', p_profile_address_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_ADDRESS_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Address ID: ', p_profile_address_id),
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
    
    -- Validation: Ensure profile_address_id is valid
    IF p_profile_address_id IS NULL OR p_profile_address_id <= 0 THEN
        SET error_code = '47009';
        SET error_message = 'Invalid profile_address_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the address exists
    SELECT COUNT(*) INTO address_exists FROM profile_address WHERE profile_address_id = p_profile_address_id;
    
    IF address_exists = 0 THEN
        SET error_code = '47010';
        SET error_message = CONCAT('Address with ID ', p_profile_address_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate address_type if provided
    IF p_address_type IS NOT NULL AND p_address_type <= 0 THEN
        SET error_code = '47011';
        SET error_message = 'Invalid address type.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate address_line1 if provided
    IF p_address_line1 IS NOT NULL AND TRIM(p_address_line1) = '' THEN
        SET error_code = '47012';
        SET error_message = 'Address line 1 cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state if provided
    IF p_state IS NOT NULL AND TRIM(p_state) = '' THEN
        SET error_code = '47013';
        SET error_message = 'State cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country_id if provided
    IF p_country_id IS NOT NULL AND p_country_id <= 0 THEN
        SET error_code = '47014';
        SET error_message = 'Country ID must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip if provided
    IF p_zip IS NOT NULL AND TRIM(p_zip) = '' THEN
        SET error_code = '47015';
        SET error_message = 'ZIP code cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the address with non-null values
    UPDATE profile_address
    SET 
        address_type = IFNULL(p_address_type, address_type),
        address_line1 = IFNULL(p_address_line1, address_line1),
        address_line2 = IFNULL(p_address_line2, address_line2),
        city = IFNULL(p_city, city),
        state = IFNULL(p_state, state),
        country_id = IFNULL(p_country_id, country_id),
        zip = IFNULL(p_zip, zip),
        landmark1 = IFNULL(p_landmark1, landmark1),
        landmark2 = IFNULL(p_landmark2, landmark2),
        date_modified = NOW(),
        user_modified = p_modified_user
    WHERE profile_address_id = p_profile_address_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Address updated with ID: ', p_profile_address_id), 
        p_modified_user, 
        'PROFILE_ADDRESS_UPDATE', 
        CONCAT('Address ID: ', p_profile_address_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_profile_address_id AS profile_address_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_contact_create
DROP PROCEDURE IF EXISTS `eb_profile_contact_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_contact_create`(
    IN p_profile_id INT,
    IN p_contact_type INT,
    IN p_contact_value VARCHAR(255),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_contact_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_CONTACT_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_CONTACT_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '48001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '48002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate contact_type
    IF p_contact_type IS NULL THEN
        SET error_code = '48003';
        SET error_message = 'Contact type is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate contact_value
    IF p_contact_value IS NULL OR TRIM(p_contact_value) = '' THEN
        SET error_code = '48004';
        SET error_message = 'Contact value is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new contact
    INSERT INTO profile_contact (
        profile_id,
        contact_type,
        contact_value,
        date_created,
        isverified,
        isvalid
    ) VALUES (
        p_profile_id,
        p_contact_type,
        p_contact_value,
        NOW(),
        0, -- Not verified by default
        0  -- Not validated by default
    );
    
    -- Get the new contact ID
    SET new_contact_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Contact created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_CONTACT_CREATE', 
        CONCAT('Contact ID: ', new_contact_id, ', Type: ', p_contact_type),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new contact ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_contact_id AS contact_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_contact_get
DROP PROCEDURE IF EXISTS `eb_profile_contact_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_contact_get`(
    IN p_profile_id INT,
    IN p_contact_id INT,
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
            'ERROR', error_message, p_created_user, 'PROFILE_CONTACT_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_CONTACT_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or contact_id is provided
    IF p_profile_id IS NULL AND p_contact_id IS NULL THEN
        SET error_code = '48005';
        SET error_message = 'Either profile_id or contact_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_contact_id IS NOT NULL THEN
        -- Get specific contact by ID
        SELECT 
            pc.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_contact pc
        WHERE pc.id = p_contact_id
        AND (pc.isverified != -1 OR pc.isverified IS NULL); -- Exclude soft-deleted records
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all contacts for a profile
        SELECT 
            pc.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_contact pc
        WHERE pc.profile_id = p_profile_id
        AND (pc.isverified != -1 OR pc.isverified IS NULL); -- Exclude soft-deleted records
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
            WHEN p_contact_id IS NOT NULL THEN CONCAT('Contact retrieved by ID: ', p_contact_id)
            ELSE CONCAT('Contacts retrieved for profile ID: ', p_profile_id)
        END, 
        p_created_user, 
        'PROFILE_CONTACT_GET', 
        CASE 
            WHEN p_contact_id IS NOT NULL THEN CONCAT('Contact ID: ', p_contact_id)
            ELSE CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_contact_update
DROP PROCEDURE IF EXISTS `eb_profile_contact_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_contact_update`(
    IN p_contact_id INT,
    IN p_contact_type INT,
    IN p_contact_value VARCHAR(255),
    IN p_isverified INT,
    IN p_isvalid INT,
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
    DECLARE contact_exists INT DEFAULT 0;
    
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
            'ERROR', error_message, p_modified_user, 'PROFILE_CONTACT_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Contact ID: ', p_contact_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_CONTACT_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Contact ID: ', p_contact_id),
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
    
    -- Validation: Ensure contact_id is valid
    IF p_contact_id IS NULL OR p_contact_id <= 0 THEN
        SET error_code = '48006';
        SET error_message = 'Invalid contact_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the contact exists
    SELECT COUNT(*) INTO contact_exists FROM profile_contact WHERE id = p_contact_id;
    
    IF contact_exists = 0 THEN
        SET error_code = '48007';
        SET error_message = CONCAT('Contact with ID ', p_contact_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate contact_type if provided
    IF p_contact_type IS NOT NULL AND p_contact_type <= 0 THEN
        SET error_code = '48008';
        SET error_message = 'Invalid contact type.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate contact_value if provided
    IF p_contact_value IS NOT NULL AND TRIM(p_contact_value) = '' THEN
        SET error_code = '48009';
        SET error_message = 'Contact value cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the contact with non-null values
    UPDATE profile_contact
    SET 
        contact_type = IFNULL(p_contact_type, contact_type),
        contact_value = IFNULL(p_contact_value, contact_value),
        isverified = IFNULL(p_isverified, isverified),
        isvalid = IFNULL(p_isvalid, isvalid)
    WHERE id = p_contact_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Contact updated with ID: ', p_contact_id), 
        p_modified_user, 
        'PROFILE_CONTACT_UPDATE', 
        CONCAT('Contact ID: ', p_contact_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_contact_id AS contact_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_education_create
DROP PROCEDURE IF EXISTS `eb_profile_education_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_education_create`(
    IN p_profile_id INT,
    IN p_education_level INT,
    IN p_year_completed INT,
    IN p_institution_name VARCHAR(255),
    IN p_address_line1 VARCHAR(100),
    IN p_city VARCHAR(45),
    IN p_state_id INT,
    IN p_country_id INT,
    IN p_zip VARCHAR(8),
    IN p_field_of_study INT,
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_education_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_EDUCATION_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_EDUCATION_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '49001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '49002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate education_level
    IF p_education_level IS NULL THEN
        SET error_code = '49003';
        SET error_message = 'Education level is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate year_completed
    IF p_year_completed IS NULL OR p_year_completed <= 0 THEN
        SET error_code = '49004';
        SET error_message = 'Year completed is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate institution_name
    IF p_institution_name IS NULL OR TRIM(p_institution_name) = '' THEN
        SET error_code = '49005';
        SET error_message = 'Institution name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state_id
    IF p_state_id IS NULL OR p_state_id <= 0 THEN
        SET error_code = '49006';
        SET error_message = 'State ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country_id
    IF p_country_id IS NULL OR p_country_id <= 0 THEN
        SET error_code = '49007';
        SET error_message = 'Country ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip
    IF p_zip IS NULL OR TRIM(p_zip) = '' THEN
        SET error_code = '49008';
        SET error_message = 'ZIP code is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate field_of_study
    IF p_field_of_study IS NULL THEN
        SET error_code = '49009';
        SET error_message = 'Field of study is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new education record
    INSERT INTO profile_education (
        profile_id,
        education_level,
        year_completed,
        institution_name,
        address_line1,
        city,
        state_id,
        country_id,
        zip,
        field_of_study,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified
    ) VALUES (
        p_profile_id,
        p_education_level,
        p_year_completed,
        p_institution_name,
        p_address_line1,
        p_city,
        p_state_id,
        p_country_id,
        p_zip,
        p_field_of_study,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0 -- Not verified by default
    );
    
    -- Get the new education ID
    SET new_education_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Education record created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_EDUCATION_CREATE', 
        CONCAT('Education ID: ', new_education_id, ', Institution: ', p_institution_name),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new education ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_education_id AS profile_education_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_education_get
DROP PROCEDURE IF EXISTS `eb_profile_education_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_education_get`(
    IN p_profile_id INT,
    IN p_profile_education_id INT,
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
            'ERROR', error_message, p_created_user, 'PROFILE_EDUCATION_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_EDUCATION_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or profile_education_id is provided
    IF p_profile_id IS NULL AND p_profile_education_id IS NULL THEN
        SET error_code = '49010';
        SET error_message = 'Either profile_id or profile_education_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_education_id IS NOT NULL THEN
        -- Get specific education record by ID
        SELECT 
            pe.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_education pe
        WHERE pe.profile_education_id = p_profile_education_id
        AND (pe.isverified != -1 OR pe.isverified IS NULL); -- Exclude soft-deleted records
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all education records for a profile
        SELECT 
            pe.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_education pe
        WHERE pe.profile_id = p_profile_id
        AND (pe.isverified != -1 OR pe.isverified IS NULL); -- Exclude soft-deleted records
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
            WHEN p_profile_education_id IS NOT NULL THEN CONCAT('Education record retrieved by ID: ', p_profile_education_id)
            ELSE CONCAT('Education records retrieved for profile ID: ', p_profile_id)
        END, 
        p_created_user, 
        'PROFILE_EDUCATION_GET', 
        CASE 
            WHEN p_profile_education_id IS NOT NULL THEN CONCAT('Education ID: ', p_profile_education_id)
            ELSE CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_education_update
DROP PROCEDURE IF EXISTS `eb_profile_education_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_education_update`(
    IN p_profile_education_id INT,
    IN p_education_level INT,
    IN p_year_completed INT,
    IN p_institution_name VARCHAR(255),
    IN p_address_line1 VARCHAR(100),
    IN p_city VARCHAR(45),
    IN p_state_id INT,
    IN p_country_id INT,
    IN p_zip VARCHAR(8),
    IN p_field_of_study INT,
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
    DECLARE education_exists INT DEFAULT 0;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'PROFILE_EDUCATION_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Education ID: ', p_profile_education_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_EDUCATION_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Education ID: ', p_profile_education_id),
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
    
    -- Validation: Ensure profile_education_id is valid
    IF p_profile_education_id IS NULL OR p_profile_education_id <= 0 THEN
        SET error_code = '49011';
        SET error_message = 'Invalid profile_education_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the education record exists
    SELECT COUNT(*) INTO education_exists FROM profile_education WHERE profile_education_id = p_profile_education_id;
    
    IF education_exists = 0 THEN
        SET error_code = '49012';
        SET error_message = CONCAT('Education record with ID ', p_profile_education_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate year_completed if provided
    IF p_year_completed IS NOT NULL AND p_year_completed <= 0 THEN
        SET error_code = '49013';
        SET error_message = 'Year completed must be a valid year.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate institution_name if provided
    IF p_institution_name IS NOT NULL AND TRIM(p_institution_name) = '' THEN
        SET error_code = '49014';
        SET error_message = 'Institution name cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state_id if provided
    IF p_state_id IS NOT NULL AND p_state_id <= 0 THEN
        SET error_code = '49015';
        SET error_message = 'State ID must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country_id if provided
    IF p_country_id IS NOT NULL AND p_country_id <= 0 THEN
        SET error_code = '49016';
        SET error_message = 'Country ID must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip if provided
    IF p_zip IS NOT NULL AND TRIM(p_zip) = '' THEN
        SET error_code = '49017';
        SET error_message = 'ZIP code cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the education record with non-null values
    UPDATE profile_education
    SET 
        education_level = IFNULL(p_education_level, education_level),
        year_completed = IFNULL(p_year_completed, year_completed),
        institution_name = IFNULL(p_institution_name, institution_name),
        address_line1 = IFNULL(p_address_line1, address_line1),
        city = IFNULL(p_city, city),
        state_id = IFNULL(p_state_id, state_id),
        country_id = IFNULL(p_country_id, country_id),
        zip = IFNULL(p_zip, zip),
        field_of_study = IFNULL(p_field_of_study, field_of_study),
        date_modified = NOW(),
        user_modified = p_modified_user
    WHERE profile_education_id = p_profile_education_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Education record updated with ID: ', p_profile_education_id), 
        p_modified_user, 
        'PROFILE_EDUCATION_UPDATE', 
        CONCAT('Education ID: ', p_profile_education_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_profile_education_id AS profile_education_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_employment_create
DROP PROCEDURE IF EXISTS `eb_profile_employment_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_employment_create`(
    IN p_profile_id INT,
    IN p_institution_name VARCHAR(255),
    IN p_address_line1 VARCHAR(100),
    IN p_city VARCHAR(45),
    IN p_state_id INT,
    IN p_country_id INT,
    IN p_zip VARCHAR(8),
    IN p_start_year INT,
    IN p_end_year INT,
    IN p_job_title_id INT,
    IN p_other_title VARCHAR(50),
    IN p_last_salary_drawn DECIMAL,
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_employment_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_EMPLOYMENT_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_EMPLOYMENT_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '50001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '50002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate institution_name
    IF p_institution_name IS NULL OR TRIM(p_institution_name) = '' THEN
        SET error_code = '50003';
        SET error_message = 'Institution name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate city
    IF p_city IS NULL OR TRIM(p_city) = '' THEN
        SET error_code = '50004';
        SET error_message = 'City is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state_id
    IF p_state_id IS NULL OR p_state_id <= 0 THEN
        SET error_code = '50005';
        SET error_message = 'State ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country_id
    IF p_country_id IS NULL OR p_country_id <= 0 THEN
        SET error_code = '50006';
        SET error_message = 'Country ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip
    IF p_zip IS NULL OR TRIM(p_zip) = '' THEN
        SET error_code = '50007';
        SET error_message = 'ZIP code is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate start_year
    IF p_start_year IS NULL OR p_start_year <= 0 THEN
        SET error_code = '50008';
        SET error_message = 'Start year is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate job_title_id
    IF p_job_title_id IS NULL OR p_job_title_id <= 0 THEN
        SET error_code = '50009';
        SET error_message = 'Job title ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate last_salary_drawn
    IF p_last_salary_drawn IS NULL OR p_last_salary_drawn < 0 THEN
        SET error_code = '50010';
        SET error_message = 'Last salary drawn is required and must be non-negative.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate end_year if provided (must be greater than or equal to start_year)
    IF p_end_year IS NOT NULL AND p_end_year < p_start_year THEN
        SET error_code = '50011';
        SET error_message = 'End year must be greater than or equal to start year.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new employment record
    INSERT INTO profile_employment (
        profile_id,
        institution_name,
        address_line1,
        city,
        state_id,
        country_id,
        zip,
        start_year,
        end_year,
        job_title_id,
        other_title,
        last_salary_drawn,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified
    ) VALUES (
        p_profile_id,
        p_institution_name,
        p_address_line1,
        p_city,
        p_state_id,
        p_country_id,
        p_zip,
        p_start_year,
        p_end_year,
        p_job_title_id,
        p_other_title,
        p_last_salary_drawn,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0 -- Not verified by default
    );
    
    -- Get the new employment ID
    SET new_employment_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Employment record created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_EMPLOYMENT_CREATE', 
        CONCAT('Employment ID: ', new_employment_id, ', Institution: ', p_institution_name),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new employment ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_employment_id AS profile_employment_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_employment_get
DROP PROCEDURE IF EXISTS `eb_profile_employment_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_employment_get`(
    IN p_profile_id INT,
    IN p_profile_employment_id INT,
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
            'ERROR', error_message, p_created_user, 'PROFILE_EMPLOYMENT_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_EMPLOYMENT_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or profile_employment_id is provided
    IF p_profile_id IS NULL AND p_profile_employment_id IS NULL THEN
        SET error_code = '50012';
        SET error_message = 'Either profile_id or profile_employment_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_employment_id IS NOT NULL THEN
        -- Get specific employment record by ID
        SELECT 
            pe.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_employment pe
        WHERE pe.profile_employment_id = p_profile_employment_id
        AND (pe.isverified != -1 OR pe.isverified IS NULL); -- Exclude soft-deleted records
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all employment records for a profile
        SELECT 
            pe.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_employment pe
        WHERE pe.profile_id = p_profile_id
        AND (pe.isverified != -1 OR pe.isverified IS NULL); -- Exclude soft-deleted records
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
            WHEN p_profile_employment_id IS NOT NULL THEN CONCAT('Employment record retrieved by ID: ', p_profile_employment_id)
            ELSE CONCAT('Employment records retrieved for profile ID: ', p_profile_id)
        END, 
        p_created_user, 
        'PROFILE_EMPLOYMENT_GET', 
        CASE 
            WHEN p_profile_employment_id IS NOT NULL THEN CONCAT('Employment ID: ', p_profile_employment_id)
            ELSE CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_employment_update
DROP PROCEDURE IF EXISTS `eb_profile_employment_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_employment_update`(
    IN p_profile_employment_id INT,
    IN p_institution_name VARCHAR(255),
    IN p_address_line1 VARCHAR(100),
    IN p_city VARCHAR(45),
    IN p_state_id INT,
    IN p_country_id INT,
    IN p_zip VARCHAR(8),
    IN p_start_year INT,
    IN p_end_year INT,
    IN p_job_title_id INT,
    IN p_other_title VARCHAR(50),
    IN p_last_salary_drawn DECIMAL,
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
    DECLARE employment_exists INT DEFAULT 0;
    DECLARE current_start_year INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'PROFILE_EMPLOYMENT_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Employment ID: ', p_profile_employment_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_EMPLOYMENT_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Employment ID: ', p_profile_employment_id),
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
    
    -- Validation: Ensure profile_employment_id is valid
    IF p_profile_employment_id IS NULL OR p_profile_employment_id <= 0 THEN
        SET error_code = '50013';
        SET error_message = 'Invalid profile_employment_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the employment record exists
    SELECT COUNT(*), start_year INTO employment_exists, current_start_year 
    FROM profile_employment 
    WHERE profile_employment_id = p_profile_employment_id
    group by start_year;
    
    IF employment_exists = 0 THEN
        SET error_code = '50014';
        SET error_message = CONCAT('Employment record with ID ', p_profile_employment_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate institution_name if provided
    IF p_institution_name IS NOT NULL AND TRIM(p_institution_name) = '' THEN
        SET error_code = '50015';
        SET error_message = 'Institution name cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate city if provided
    IF p_city IS NOT NULL AND TRIM(p_city) = '' THEN
        SET error_code = '50016';
        SET error_message = 'City cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state_id if provided
    IF p_state_id IS NOT NULL AND p_state_id <= 0 THEN
        SET error_code = '50017';
        SET error_message = 'State ID must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country_id if provided
    IF p_country_id IS NOT NULL AND p_country_id <= 0 THEN
        SET error_code = '50018';
        SET error_message = 'Country ID must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip if provided
    IF p_zip IS NOT NULL AND TRIM(p_zip) = '' THEN
        SET error_code = '50019';
        SET error_message = 'ZIP code cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate start_year if provided
    IF p_start_year IS NOT NULL AND p_start_year <= 0 THEN
        SET error_code = '50020';
        SET error_message = 'Start year must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate job_title_id if provided
    IF p_job_title_id IS NOT NULL AND p_job_title_id <= 0 THEN
        SET error_code = '50021';
        SET error_message = 'Job title ID must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate last_salary_drawn if provided
    IF p_last_salary_drawn IS NOT NULL AND p_last_salary_drawn < 0 THEN
        SET error_code = '50022';
        SET error_message = 'Last salary drawn must be non-negative if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate end_year if provided (must be greater than or equal to start_year)
    IF p_end_year IS NOT NULL AND p_start_year IS NULL AND p_end_year < current_start_year THEN
        SET error_code = '50023';
        SET error_message = 'End year must be greater than or equal to start year.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate end_year and start_year if both provided
    IF p_end_year IS NOT NULL AND p_start_year IS NOT NULL AND p_end_year < p_start_year THEN
        SET error_code = '50024';
        SET error_message = 'End year must be greater than or equal to start year.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the employment record with non-null values
    UPDATE profile_employment
    SET 
        institution_name = IFNULL(p_institution_name, institution_name),
        address_line1 = IFNULL(p_address_line1, address_line1),
        city = IFNULL(p_city, city),
        state_id = IFNULL(p_state_id, state_id),
        country_id = IFNULL(p_country_id, country_id),
        zip = IFNULL(p_zip, zip),
        start_year = IFNULL(p_start_year, start_year),
        end_year = IFNULL(p_end_year, end_year),
        job_title_id = IFNULL(p_job_title_id, job_title_id),
        other_title = IFNULL(p_other_title, other_title),
        last_salary_drawn = IFNULL(p_last_salary_drawn, last_salary_drawn),
        date_modified = NOW(),
        user_modified = p_modified_user
    WHERE profile_employment_id = p_profile_employment_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Employment record updated with ID: ', p_profile_employment_id), 
        p_modified_user, 
        'PROFILE_EMPLOYMENT_UPDATE', 
        CONCAT('Employment ID: ', p_profile_employment_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_profile_employment_id AS profile_employment_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_family_reference_create
DROP PROCEDURE IF EXISTS `eb_profile_family_reference_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_family_reference_create`(
    IN p_profile_id INT,
    IN p_first_name VARCHAR(45),
    IN p_last_name VARCHAR(45),
    IN p_reference_type INT,
    IN p_primary_phone VARCHAR(15),
    IN p_email VARCHAR(45),
    IN p_address_line1 VARCHAR(100),
    IN p_city VARCHAR(45),
    IN p_state INT,
    IN p_country INT,
    IN p_zip VARCHAR(8),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_reference_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_FAMILY_REFERENCE_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_FAMILY_REFERENCE_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '51001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '51002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate first_name
    IF p_first_name IS NULL OR TRIM(p_first_name) = '' THEN
        SET error_code = '51003';
        SET error_message = 'First name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate last_name
    IF p_last_name IS NULL OR TRIM(p_last_name) = '' THEN
        SET error_code = '51004';
        SET error_message = 'Last name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate reference_type
    IF p_reference_type IS NULL OR p_reference_type <= 0 THEN
        SET error_code = '51005';
        SET error_message = 'Reference type is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate primary_phone
    IF p_primary_phone IS NULL OR TRIM(p_primary_phone) = '' THEN
        SET error_code = '51006';
        SET error_message = 'Primary phone number is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate email format if provided
    IF p_email IS NOT NULL AND p_email NOT LIKE '%_@_%._%' THEN
        SET error_code = '51007';
        SET error_message = 'Invalid email format.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new family reference record
    INSERT INTO profile_family_reference (
        profile_id,
        first_name,
        last_name,
        reference_type,
        primary_phone,
        can_communicate,
        email,
        address_line1,
        city,
        state,
        country,
        zip,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified
    ) VALUES (
        p_profile_id,
        p_first_name,
        p_last_name,
        p_reference_type,
        p_primary_phone,
        1,
        p_email,
        p_address_line1,
        p_city,
        p_state,
        p_country,
        p_zip,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0 -- Not verified by default
    );
    
    -- Get the new reference ID
    SET new_reference_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Family reference created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_FAMILY_REFERENCE_CREATE', 
        CONCAT('Reference ID: ', new_reference_id, ', Name: ', p_first_name, ' ', p_last_name),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new reference ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_reference_id AS profile_family_reference_id,
        NULL AS error_code,
        NULL AS error_message;

    
END$$
DELIMITER ;

-- Procedure: eb_profile_family_reference_get
DROP PROCEDURE IF EXISTS `eb_profile_family_reference_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_family_reference_get`(
    IN p_profile_id INT,
    IN p_category VARCHAR(45), -- 'family' or 'reference' or 'friend'
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
            'ERROR', error_message, p_created_user, 'PROFILE_FAMILY_REFERENCE_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_FAMILY_REFERENCE_GET', 
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
    
    -- Validation: Ensure profile_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '51008';
        SET error_message = 'Profile ID must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validation: Ensure category is provided and valid
    IF p_category IS NULL OR (p_category != 'family' AND p_category != 'reference') THEN
        SET error_code = '51009';
        SET error_message = 'Category must be either "family" or "reference".';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Get all records for a profile matching the specified category (family or reference)
    SELECT 
        pfr.*,
        lt.name AS type_name,
        lt.description AS type_description,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message
    FROM profile_family_reference pfr
    INNER JOIN lookup_table lt ON pfr.reference_type = lt.id AND lt.category = p_category
    WHERE pfr.profile_id = p_profile_id
    AND (pfr.isverified != -1 OR pfr.isverified IS NULL); -- Exclude soft-deleted records
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful read
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ', 
        CONCAT(p_category, ' records retrieved for profile ID: ', p_profile_id),
        p_created_user, 
        'PROFILE_FAMILY_REFERENCE_GET', 
        CONCAT('Profile ID: ', p_profile_id, ', Category: ', p_category),
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_family_reference_update
DROP PROCEDURE IF EXISTS `eb_profile_family_reference_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_family_reference_update`(
	IN p_profile_id INT,
    IN p_profile_family_reference_id INT,
	IN p_first_name VARCHAR(45),
    IN p_last_name VARCHAR(45),
    IN p_reference_type INT,
    IN p_primary_phone VARCHAR(15),
    IN p_email VARCHAR(45),
    IN p_address_line1 VARCHAR(100),
    IN p_city VARCHAR(45),
    IN p_state INT,
    IN p_country INT,
    IN p_zip VARCHAR(8),
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
    DECLARE reference_exists INT DEFAULT 0;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'PROFILE_FAMILY_REFERENCE_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Reference ID: ', p_profile_family_reference_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_FAMILY_REFERENCE_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Reference ID: ', p_profile_family_reference_id),
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
    
    -- Validation: Ensure profile_family_reference_id is valid
    IF p_profile_family_reference_id IS NULL OR p_profile_family_reference_id <= 0 THEN
        SET error_code = '51009';
        SET error_message = 'Invalid profile_family_reference_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the family reference record exists
    SELECT COUNT(*) INTO reference_exists FROM profile_family_reference WHERE profile_family_reference_id = p_profile_family_reference_id;
    
    IF reference_exists = 0 THEN
        SET error_code = '51010';
        SET error_message = CONCAT('Family reference with ID ', p_profile_family_reference_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate first_name if provided
    IF p_first_name IS NOT NULL AND TRIM(p_first_name) = '' THEN
        SET error_code = '51011';
        SET error_message = 'First name cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate last_name if provided
    IF p_last_name IS NOT NULL AND TRIM(p_last_name) = '' THEN
        SET error_code = '51012';
        SET error_message = 'Last name cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate reference_type if provided
    IF p_reference_type IS NOT NULL AND p_reference_type <= 0 THEN
        SET error_code = '51013';
        SET error_message = 'Reference type must be valid if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate primary_phone if provided
    IF p_primary_phone IS NOT NULL AND TRIM(p_primary_phone) = '' THEN
        SET error_code = '51014';
        SET error_message = 'Primary phone number cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate email format if provided
    IF p_email IS NOT NULL AND p_email NOT LIKE '%_@_%._%' THEN
        SET error_code = '51015';
        SET error_message = 'Invalid email format.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the family reference record with non-null values
    UPDATE profile_family_reference
    SET 
        first_name = IFNULL(p_first_name, first_name),
        last_name = IFNULL(p_last_name, last_name),
        reference_type = IFNULL(p_reference_type, reference_type),
        primary_phone = IFNULL(p_primary_phone, primary_phone),
        email = IFNULL(p_email, email),
        address_line1 = IFNULL(p_address_line1, address_line1),
        city = IFNULL(p_city, city),
        state = IFNULL(p_state, state),
        country = IFNULL(p_country, country),
        zip = IFNULL(p_zip, zip),
        date_modified = NOW(),
        user_modified = p_modified_user
    WHERE profile_family_reference_id = p_profile_family_reference_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Family reference updated with ID: ', p_profile_family_reference_id), 
        p_modified_user, 
        'PROFILE_FAMILY_REFERENCE_UPDATE', 
        CONCAT('Reference ID: ', p_profile_family_reference_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_profile_family_reference_id AS profile_family_reference_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_favorites_create
DROP PROCEDURE IF EXISTS `eb_profile_favorites_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_favorites_create`(
    IN p_from_profile_id INT,
    IN p_to_profile_id INT,
    IN p_account_id INT
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_favorite_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
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
            'ERROR', error_message, p_account_id, 'PROFILE_FAVORITES_CREATE', 
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
            'ERROR', error_message, p_account_id, 'PROFILE_FAVORITES_CREATE', 
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
    
    -- Validation: Ensure from_profile_id is valid
    IF p_from_profile_id IS NULL OR p_from_profile_id <= 0 THEN
        SET error_code = '58001';
        SET error_message = 'Invalid from_profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if from profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_from_profile_id) THEN
        SET error_code = '58002';
        SET error_message = 'From profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate to_profile_id
    IF p_to_profile_id IS NULL OR p_to_profile_id <= 0 THEN
        SET error_code = '58003';
        SET error_message = 'To profile ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if to profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_to_profile_id) THEN
        SET error_code = '58004';
        SET error_message = 'To profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if profile is trying to favorite itself
    IF p_from_profile_id = p_to_profile_id THEN
        SET error_code = '58005';
        SET error_message = 'A profile cannot favorite itself.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if this profile has already favorited the other profile
    IF EXISTS (
        SELECT 1 
        FROM profile_favorites 
        WHERE from_profile_id = p_from_profile_id 
        AND to_profile_id = p_to_profile_id
        AND is_active = b'1'
    ) THEN
        SET error_code = '58006';
        SET error_message = 'This profile has already favorited the specified profile.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate account_id
    IF p_account_id IS NULL OR p_account_id <= 0 THEN
        SET error_code = '58007';
        SET error_message = 'Account ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new favorite record
    INSERT INTO profile_favorites (
        from_profile_id,
        to_profile_id,
        date_created,
        is_active,
        date_updated,
        account_id
    ) VALUES (
        p_from_profile_id,
        p_to_profile_id,
        NOW(),
        b'1',
        NOW(),
        p_account_id
    );
    
    -- Get the new favorite ID
    SET new_favorite_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Profile ', p_from_profile_id, ' favorited profile ', p_to_profile_id), 
        CONCAT('Account ID: ', p_account_id), 
        'PROFILE_FAVORITES_CREATE', 
        CONCAT('From Profile ID: ', p_from_profile_id, ', To Profile ID: ', p_to_profile_id, ', Account ID: ', p_account_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new favorite ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_favorite_id AS id,
        NULL AS error_code,
        NULL AS error_message;

    
END$$
DELIMITER ;

-- Procedure: eb_profile_favorites_delete
DROP PROCEDURE IF EXISTS `eb_profile_favorites_delete`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_favorites_delete`(
    IN p_id INT,
    IN p_account_id INT
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    DECLARE record_exists INT DEFAULT 0;
    DECLARE from_profile_id_val INT;
    DECLARE to_profile_id_val INT;
    
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
            'ERROR', error_message, p_account_id, 'PROFILE_FAVORITES_DELETE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_id),
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
            'ERROR', error_message, p_account_id, 'PROFILE_FAVORITES_DELETE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_id),
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
    
    -- Validation: Ensure id is valid
    IF p_id IS NULL OR p_id <= 0 THEN
        SET error_code = '58014';
        SET error_message = 'Invalid id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the favorite record exists and get the profile_id and favorite_profile_id
    SELECT COUNT(*), from_profile_id, to_profile_id INTO record_exists, from_profile_id_val, to_profile_id_val
    FROM profile_favorites 
    WHERE profile_favorite_id = p_id;
    
    IF record_exists = 0 THEN
        SET error_code = '58015';
        SET error_message = CONCAT('Favorite record with ID ', p_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Soft delete by setting isverified = -1
    UPDATE profile_favorites
    SET 
        is_active = 0,
        date_updated = NOW(),
        account_id = p_account_id
    WHERE profile_favorite_id = p_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful deletion
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'DELETE', 
        CONCAT('Favorite record deleted with ID: ', p_id), 
        p_account_id, 
        'PROFILE_FAVORITES_DELETE', 
        CONCAT('ID: ', p_id, ', Profile ID: ', from_profile_id_val, ', Favorite Profile ID: ', to_profile_id_val),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_id AS id,
        NULL AS error_code,
        NULL AS error_message;
END$$
DELIMITER ;

-- Procedure: eb_profile_favorites_get
DROP PROCEDURE IF EXISTS `eb_profile_favorites_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_favorites_get`(
    IN p_profile_id INT,
    IN p_account_id INT
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
            'ERROR', error_message, p_account_id, 'PROFILE_FAVORITES_GET', 
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
            'ERROR', error_message, p_account_id, 'PROFILE_FAVORITES_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or id is provided
    IF p_profile_id IS NULL AND p_account_id IS NULL THEN
        SET error_code = '58007';
        SET error_message = 'Either profile_id or id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_account_id IS NOT NULL THEN
        -- Get specific favorite by ID
        SELECT 
            pf.*,
            pp.first_name, 
            pp.last_name,
            pp.gender,
            pp.birth_date,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_favorites pf
        LEFT JOIN profile_personal pp ON pf.account_id = pp.account_id
        WHERE pf.from_profile_id = p_profile_id
        AND (pf.is_active > 0 OR pf.is_active IS NULL); -- Exclude soft-deleted records
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all favorites for a profile
        SELECT 
            pf.*,
            pp.first_name, 
            pp.last_name,
            pp.gender,
            pp.birth_date,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_favorites pf
        LEFT JOIN profile_personal pp ON pf.from_profile_id = pp.profile_id
        WHERE pf.from_profile_id = p_profile_id
        AND (pf.is_active > 0  OR pf.is_active IS NULL) -- Exclude soft-deleted records
        ORDER BY pf.date_created DESC;
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
            WHEN p_account_id IS NOT NULL THEN CONCAT('Favorite retrieved by ID: ', p_account_id)
            ELSE CONCAT('Favorites retrieved for profile ID: ', p_profile_id)
        END, 
        p_account_id, 
        'PROFILE_FAVORITES_GET', 
        CASE 
            WHEN p_profile_id IS NOT NULL THEN CONCAT('Profile ID: ', p_profile_id)
            ELSE CONCAT('Account ID: ', p_account_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_get_complete_data
DROP PROCEDURE IF EXISTS `eb_profile_get_complete_data`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_get_complete_data`(
    IN p_profile_id INT,
    IN p_created_user VARCHAR(100)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare variables for metrics
    DECLARE address_count INT DEFAULT 0;
    DECLARE contact_count INT DEFAULT 0;
    DECLARE education_count INT DEFAULT 0;
    DECLARE employment_count INT DEFAULT 0;
    DECLARE profiles_viewed_by_me_count INT DEFAULT 0;
    DECLARE profiles_viewed_me_count INT DEFAULT 0;
    DECLARE favorites_count INT DEFAULT 0;
    
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
            'ERROR', error_message, p_created_user, 'PROFILE_GET_COMPLETE_DATA', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_GET_COMPLETE_DATA', 
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
    
    -- Validation: Ensure profile_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '59009';
        SET error_message = 'Profile ID must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Get count of addresses
    SELECT COUNT(*) INTO address_count
    FROM profile_address
    WHERE profile_id = p_profile_id;
    
    -- Get count of contacts
    SELECT COUNT(*) INTO contact_count
    FROM profile_contact
    WHERE profile_id = p_profile_id;
    
    -- Get count of education entries
    SELECT COUNT(*) INTO education_count
    FROM profile_education
    WHERE profile_id = p_profile_id;
    
    -- Get count of employment entries
    SELECT COUNT(*) INTO employment_count
    FROM profile_employment
    WHERE profile_id = p_profile_id;
    
    -- Get count of profiles viewed by me
    SELECT COUNT(DISTINCT to_profile_id) INTO profiles_viewed_by_me_count
    FROM profile_views
    WHERE from_profile_id = p_profile_id;
    
    -- Get count of profiles that viewed me
    SELECT COUNT(DISTINCT from_profile_id) INTO profiles_viewed_me_count
    FROM profile_views
    WHERE to_profile_id = p_profile_id;
    
    -- Get count of favorites    
    SELECT COUNT(DISTINCT to_profile_id) INTO favorites_count 
    FROM profile_favorites
    WHERE from_profile_id = p_profile_id;
        
    -- Get complete profile data with all metrics
    SELECT 
        pp.profile_id,
        pp.account_id,
        pp.first_name,
        pp.last_name,
        pp.middle_name,
        pp.prefix,
        pp.suffix,
        pp.gender,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.gender AND lt.category = 'Gender') AS gender_text,
        pp.birth_date,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) AS age,
        pp.phone_mobile,
        pp.phone_home,
        pp.phone_emergency,
        pp.email_id,
        pp.marital_status,
        profile_photo.url AS profile_photo_url,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.marital_status AND lt.category = 'Marital Status') AS marital_status_text,
        pp.religion,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.religion AND lt.category = 'Religion') AS religion_text,
        pp.nationality,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.nationality AND lt.category = 'Nationality') AS nationality_text,
        pp.caste,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.caste AND lt.category = 'Caste') AS caste_text,
        pp.height_inches,
        pp.height_cms,
        pp.weight,
        pp.weight_units,
        pp.complexion,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.complexion AND lt.category = 'Complexion') AS complexion_text,
        pp.linkedin,
        pp.facebook,
        pp.instagram,
        pp.whatsapp_number,
        pp.profession,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.profession AND lt.category = 'Profession') AS profession_text,
        pp.disability,
        (SELECT lt.name FROM lookup_table lt WHERE lt.id = pp.disability AND lt.category = 'Disability') AS disability_text,
        pp.created_user,
        pp.created_date,
        pp.updated_date,
        pp.is_active,
        -- Metrics
        address_count AS number_of_addresses,
        contact_count AS number_of_contacts,
        education_count AS number_of_education_entries,
        employment_count AS number_of_employment_entries,
        profiles_viewed_by_me_count AS profiles_viewed_by_me,
        profiles_viewed_me_count AS profiles_viewed_me,
        favorites_count AS profile_favorites,
        -- Additional profile information
        (SELECT GROUP_CONCAT(DISTINCT c.country_name SEPARATOR ', ')
         FROM profile_address pa
         JOIN country c ON pa.country_id = c.country_id
         WHERE pa.profile_id = pp.profile_id) AS countries,
        (SELECT GROUP_CONCAT(DISTINCT s.state_name SEPARATOR ', ')
         FROM profile_address pa
         JOIN state s ON pa.state = s.state_id
         WHERE pa.profile_id = pp.profile_id) AS states,
        (SELECT GROUP_CONCAT(DISTINCT pe.institution_name SEPARATOR ', ')
         FROM profile_education pe
         WHERE pe.profile_id = pp.profile_id) AS education_institutions,
        (SELECT GROUP_CONCAT(DISTINCT pe.institution_name SEPARATOR ', ')
         FROM profile_employment pe
         WHERE pe.profile_id = pp.profile_id) AS employment_institutions,
        -- Additional lookup values for address types
        (SELECT GROUP_CONCAT(DISTINCT lt.name SEPARATOR ', ')
         FROM profile_address pa
         JOIN lookup_table lt ON pa.address_type = lt.id AND lt.category = 'Address Type'
         WHERE pa.profile_id = pp.profile_id) AS address_types,
        -- Additional lookup values for contact types
        (SELECT GROUP_CONCAT(DISTINCT lt.name SEPARATOR ', ')
         FROM profile_contact pc
         JOIN lookup_table lt ON pc.contact_type = lt.id AND lt.category = 'Contact_type'
         WHERE pc.profile_id = pp.profile_id) AS contact_types,
        -- Additional lookup values for education levels
        (SELECT GROUP_CONCAT(DISTINCT lt.name SEPARATOR ', ')
         FROM profile_education pe
         JOIN lookup_table lt ON pe.education_level = lt.id AND lt.category = 'Education_level'
         WHERE pe.profile_id = pp.profile_id) AS education_levels,
        -- Additional lookup values for field of study
        (SELECT GROUP_CONCAT(DISTINCT lt.name SEPARATOR ', ')
         FROM profile_education pe
         JOIN lookup_table lt ON pe.field_of_study = lt.id AND lt.category = 'Field_of_study'
         WHERE pe.profile_id = pp.profile_id) AS fields_of_study,
        -- Additional lookup values for job titles
        (SELECT GROUP_CONCAT(DISTINCT lt.name SEPARATOR ', ')
         FROM profile_employment pe
         JOIN lookup_table lt ON pe.job_title_id = lt.id AND lt.category = 'JobTitle'
         WHERE pe.profile_id = pp.profile_id) AS job_titles,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message
    FROM profile_personal pp
    LEFT JOIN 
        (SELECT profile_photo.* FROM profile_photo 
         INNER JOIN lookup_table ON photo_type = id 
         WHERE caption = 'Clear Headshot' and softdelete = 0) AS profile_photo 
        ON pp.profile_id = profile_photo.profile_id
    WHERE pp.profile_id = p_profile_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful read
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ', 
        CONCAT('Complete profile data retrieved for profile ID: ', p_profile_id),
        p_created_user, 
        'PROFILE_GET_COMPLETE_DATA', 
        CONCAT('Profile ID: ', p_profile_id),
        start_time, end_time, execution_time
    );

    
END$$
DELIMITER ;

-- Procedure: eb_profile_hobby_interest_create
DROP PROCEDURE IF EXISTS `eb_profile_hobby_interest_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_hobby_interest_create`(
    IN p_profile_id INT,
    IN p_hobby_interest_id INT,
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_hobby_interest_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_HOBBY_INTEREST_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_HOBBY_INTEREST_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '52001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '52002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate hobby_interest_id
    IF p_hobby_interest_id IS NULL OR p_hobby_interest_id <= 0 THEN
        SET error_code = '52003';
        SET error_message = 'Hobby/Interest ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if this hobby/interest is already associated with this profile
    IF EXISTS (
        SELECT 1 
        FROM profile_hobby_interest 
        WHERE profile_id = p_profile_id 
        AND hobby_interest_id = p_hobby_interest_id
        AND (isverified != -1 OR isverified IS NULL)
    ) THEN
        SET error_code = '52004';
        SET error_message = 'This hobby/interest is already associated with this profile.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new hobby/interest record
    INSERT INTO profile_hobby_interest (
        profile_id,
        hobby_interest_id,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified
    ) VALUES (
        p_profile_id,
        p_hobby_interest_id,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0 -- Not verified by default
    );
    
    -- Get the new hobby/interest ID
    SET new_hobby_interest_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Hobby/Interest created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_HOBBY_INTEREST_CREATE', 
        CONCAT('Profile ID: ', p_profile_id, ', Hobby/Interest ID: ', p_hobby_interest_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new hobby/interest ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_hobby_interest_id AS id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_hobby_interest_delete
DROP PROCEDURE IF EXISTS `eb_profile_hobby_interest_delete`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_hobby_interest_delete`(
    IN p_id INT,
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
    DECLARE record_exists INT DEFAULT 0;
    DECLARE profile_id_val INT;
    
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
            'ERROR', error_message, p_created_user, 'PROFILE_HOBBY_INTEREST_DELETE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_id),
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
            'ERROR', error_message, p_created_user, 'PROFILE_HOBBY_INTEREST_DELETE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_id),
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
    
    -- Validation: Ensure id is valid
    IF p_id IS NULL OR p_id <= 0 THEN
        SET error_code = '52010';
        SET error_message = 'Invalid id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the hobby/interest record exists and get the profile_id
    SELECT COUNT(*), profile_id INTO record_exists, profile_id_val 
    FROM profile_hobby_interest 
    WHERE profile_hobby_intereste_id = p_id;
    
    IF record_exists = 0 THEN
        SET error_code = '52011';
        SET error_message = CONCAT('Hobby/Interest record with ID ', p_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Soft delete by setting isverified = -1
    UPDATE profile_hobby_interest
    SET 
        isverified = -1,
        date_modified = NOW(),
        user_modified = p_created_user
    WHERE profile_hobby_intereste_id = p_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful deletion
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'DELETE', 
        CONCAT('Hobby/Interest record deleted with ID: ', p_id), 
        p_created_user, 
        'PROFILE_HOBBY_INTEREST_DELETE', 
        CONCAT('ID: ', p_id, ', Profile ID: ', profile_id_val),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_id AS id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_hobby_interest_get
DROP PROCEDURE IF EXISTS `eb_profile_hobby_interest_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_hobby_interest_get`(
    IN p_profile_id INT,
    IN p_id INT,
    IN p_category VARCHAR(45), -- 'hobby' or 'interest'
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
            'ERROR', error_message, p_created_user, 'PROFILE_HOBBY_INTEREST_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_HOBBY_INTEREST_GET', 
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
    
    -- Validation: Ensure profile_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '52005';
        SET error_message = 'Profile ID must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validation: Ensure category is provided
    IF p_category IS NULL OR (p_category != 'hobby' AND p_category != 'interest') THEN
        SET error_code = '52006';
        SET error_message = 'Category must be either "hobby" or "interest".';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Get all records for a profile matching the specified category
    SELECT 
        phi.*,
        hi.name AS hobby_interest_name,
        hi.description AS hobby_interest_description,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message
    FROM profile_hobby_interest phi
    INNER JOIN lookup_table hi ON phi.hobby_interest_id = hi.id AND hi.category = p_category
    WHERE phi.profile_id = p_profile_id
    AND (phi.isverified != -1 OR phi.isverified IS NULL); -- Exclude soft-deleted records
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful read
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ', 
        CONCAT(p_category, 's retrieved for profile ID: ', p_profile_id),
        p_created_user, 
        'PROFILE_HOBBY_INTEREST_GET', 
        CONCAT('Profile ID: ', p_profile_id, ', Category: ', p_category),
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_lifestyle_create
DROP PROCEDURE IF EXISTS `eb_profile_lifestyle_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_lifestyle_create`(
    IN p_profile_id INT,
    IN p_eating_habit VARCHAR(45),
    IN p_diet_habit VARCHAR(45),
    IN p_cigarettes_per_day VARCHAR(10),
    IN p_drink_frequency VARCHAR(45),
    IN p_gambling_engage VARCHAR(45),
    IN p_physical_activity_level VARCHAR(45),
    IN p_relaxation_methods VARCHAR(45),
    IN p_additional_info VARCHAR(255),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_lifestyle_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        
        ROLLBACK;
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_LIFESTYLE_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_LIFESTYLE_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '53001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '53002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if this profile already has lifestyle information
    IF EXISTS (
        SELECT 1 
        FROM profile_lifestyle 
        WHERE profile_id = p_profile_id 
        AND is_active = 1
    ) THEN
        SET error_code = '53004';
        SET error_message = 'Lifestyle information already exists for this profile.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new lifestyle record
    INSERT INTO profile_lifestyle (
        profile_id,
        eating_habit,
        diet_habit,
        cigarettes_per_day,
        drink_frequency,
        gambling_engage,
        physical_activity_level,
        relaxation_methods,
        additional_info,
        created_date,
        modified_date,
        created_user,
        modified_user,
        is_active
    ) VALUES (
        p_profile_id,
        p_eating_habit,
        p_diet_habit,
        p_cigarettes_per_day,
        p_drink_frequency,
        p_gambling_engage,
        p_physical_activity_level,
        p_relaxation_methods,
        p_additional_info,
        NOW(),
        NOW(),
        p_created_user,
        p_created_user,
        1 -- Active by default
    );
    
    -- Get the new lifestyle ID
    SET new_lifestyle_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Lifestyle created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_LIFESTYLE_CREATE', 
        CONCAT('Profile ID: ', p_profile_id, ', Lifestyle created'),

        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new lifestyle ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_lifestyle_id AS id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_lifestyle_delete
DROP PROCEDURE IF EXISTS `eb_profile_lifestyle_delete`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_lifestyle_delete`(
    IN p_id INT,
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
    DECLARE record_exists INT DEFAULT 0;
    DECLARE profile_id_val INT;
    
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
            'ERROR', error_message, p_created_user, 'PROFILE_LIFESTYLE_DELETE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_id),
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
            'ERROR', error_message, p_created_user, 'PROFILE_LIFESTYLE_DELETE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_id),
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
    
    -- Validation: Ensure id is valid
    IF p_id IS NULL OR p_id <= 0 THEN
        SET error_code = '53010';
        SET error_message = 'Invalid id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the lifestyle record exists and get the profile_id
    SELECT COUNT(*), profile_id INTO record_exists, profile_id_val 
    FROM profile_lifestyle 
    WHERE id = p_id;
    
    IF record_exists = 0 THEN
        SET error_code = '53011';
        SET error_message = CONCAT('Lifestyle record with ID ', p_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Soft delete by setting isverified = -1
    UPDATE profile_lifestyle
    SET 
        isverified = -1,
        date_modified = NOW(),
        user_modified = p_created_user
    WHERE id = p_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful deletion
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'DELETE', 
        CONCAT('Lifestyle record deleted with ID: ', p_id), 
        p_created_user, 
        'PROFILE_LIFESTYLE_DELETE', 
        CONCAT('ID: ', p_id, ', Profile ID: ', profile_id_val),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_id AS id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_lifestyle_get
DROP PROCEDURE IF EXISTS `eb_profile_lifestyle_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_lifestyle_get`(
    IN p_profile_id INT,
    IN p_id INT,
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
            'ERROR', error_message, p_created_user, 'PROFILE_LIFESTYLE_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_LIFESTYLE_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or id is provided
    IF p_profile_id IS NULL AND p_id IS NULL THEN
        SET error_code = '53005';
        SET error_message = 'Either profile_id or id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_id IS NOT NULL THEN
        -- Get specific lifestyle record by ID
        SELECT 
            pl.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_lifestyle pl
        WHERE pl.profile_lifestyle_id = p_id
        AND pl.is_active = 1; -- Only active records
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all lifestyle records for a profile
        SELECT 
            pl.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_lifestyle pl
        WHERE pl.profile_id = p_profile_id
        AND pl.is_active = 1; -- Only active records
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
            WHEN p_id IS NOT NULL THEN CONCAT('Lifestyle retrieved by ID: ', p_id)
            ELSE CONCAT('Lifestyles retrieved for profile ID: ', p_profile_id)
        END, 
        p_created_user, 
        'PROFILE_LIFESTYLE_GET', 
        CASE 
            WHEN p_id IS NOT NULL THEN CONCAT('ID: ', p_id)
            ELSE CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_lifestyle_update
DROP PROCEDURE IF EXISTS `eb_profile_lifestyle_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_lifestyle_update`(
    IN p_profile_lifestyle_id INT,
    IN p_eating_habit VARCHAR(45),
    IN p_diet_habit VARCHAR(45),
    IN p_cigarettes_per_day VARCHAR(10),
    IN p_drink_frequency VARCHAR(45),
    IN p_gambling_engage VARCHAR(45),
    IN p_physical_activity_level VARCHAR(45),
    IN p_relaxation_methods VARCHAR(45),
    IN p_additional_info VARCHAR(255),
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
    DECLARE record_exists INT DEFAULT 0;
    DECLARE current_profile_id INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'PROFILE_LIFESTYLE_UPDATE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_profile_lifestyle_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_LIFESTYLE_UPDATE', 
            CONCAT('Error Code: ', error_code, ', ID: ', p_profile_lifestyle_id),
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
    
    -- Validation: Ensure profile_lifestyle_id is valid
    IF p_profile_lifestyle_id IS NULL OR p_profile_lifestyle_id <= 0 THEN
        SET error_code = '53006';
        SET error_message = 'Invalid profile_lifestyle_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the lifestyle record exists and get the profile_id
    SELECT COUNT(*), profile_id INTO record_exists, current_profile_id 
    FROM profile_lifestyle 
    WHERE profile_lifestyle_id = p_profile_lifestyle_id
    group by profile_id;
    
    IF record_exists = 0 THEN
        SET error_code = '53007';
        SET error_message = CONCAT('Lifestyle record with ID ', p_profile_lifestyle_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the lifestyle record with non-null values
    UPDATE profile_lifestyle
    SET 
        eating_habit = IFNULL(p_eating_habit, eating_habit),
        diet_habit = IFNULL(p_diet_habit, diet_habit),
        cigarettes_per_day = IFNULL(p_cigarettes_per_day, cigarettes_per_day),
        drink_frequency = IFNULL(p_drink_frequency, drink_frequency),
        gambling_engage = IFNULL(p_gambling_engage, gambling_engage),
        physical_activity_level = IFNULL(p_physical_activity_level, physical_activity_level),
        relaxation_methods = IFNULL(p_relaxation_methods, relaxation_methods),
        additional_info = IFNULL(p_additional_info, additional_info),
        modified_date = NOW(),
        modified_user = p_modified_user
    WHERE profile_lifestyle_id = p_profile_lifestyle_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Lifestyle record updated with ID: ', p_profile_lifestyle_id), 
        p_modified_user, 
        'PROFILE_LIFESTYLE_UPDATE', 
        CONCAT('ID: ', p_profile_lifestyle_id, ', Profile ID: ', current_profile_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_profile_lifestyle_id AS id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_personal_create
DROP PROCEDURE IF EXISTS `eb_profile_personal_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_personal_create`(
    accountid int,
    first_name varchar(45),
    last_name varchar(45),
    middle_name varchar(45),
    prefix varchar(45),
    suffix varchar(45),
    gender int,
    birth_date date,
    phone_mobile varchar(15),
    phone_home varchar(15),
    phone_emergency varchar(15),
    email_id varchar(150),
    marital_status int, 
    religion int, 
    nationality int, 
    caste int, 
    height_inches int, 
    height_cms int,
    weight int, 
    weight_units varchar(4), 
    complexion int, 
    linkedin varchar(450), 
    facebook varchar(450), 
    instagram varchar(450), 
    whatsapp_number varchar(15), 
    profession int, 
    disability int,
    created_user varchar(45),
    short_summary longtext
)
BEGIN
    -- Declare variables for error handling
    DECLARE age INT;
    DECLARE duplicate_profile INT DEFAULT 0;
    DECLARE duplicate_email INT DEFAULT 0;
    DECLARE duplicate_phone INT DEFAULT 0;
    DECLARE account_exists INT DEFAULT 0;
    DECLARE error_msg VARCHAR(1000);
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_profile_id INT;
    
    -- Declare handler for SQL exceptions 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;
        SELECT 
            'fail' AS status,
            'SQL Exception' as error_type,
            null AS profile_id,
            error_code,
            error_message;
    END;
    
    -- Declare handler for custom errors (SQLSTATE starting with '45')
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        ROLLBACK;
        -- Return error information
        SELECT 
            'fail' AS status,
            'Validation Exception' as error_type,
            null AS profile_id,
            error_code,
            error_message;
    END;
    
    -- Validation: Ensure accountid is a valid positive integer
    IF accountid <= 0 THEN
        SET error_code = '46001_INVALID_ACCOUNTID';
        SET error_message = 'Invalid accountid. It must be a positive integer.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF EXISTS (SELECT 1 FROM account a WHERE a.account_id = accountid AND is_active != 1) THEN
        SET error_code = '46017_ACCOUNT_IS_NOT_ACTIVE';
        SET error_message = 'This account is not active. Please contact administrator to enable your account.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validation: Ensure essential fields are not NULL or empty
    IF first_name IS NULL OR TRIM(first_name) = '' THEN
        SET error_code = '46002_MISSING_FIRST_NAME';
        SET error_message = 'First name cannot be empty.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF last_name IS NULL OR TRIM(last_name) = '' THEN
        SET error_code = '46003_MISSING_LAST_NAME';
        SET error_message = 'Last name cannot be empty.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF gender NOT IN (SELECT id FROM lookup_table WHERE category = 'Gender' ) THEN
        SET error_code = '46004_INVALID_GENDER';
        SET error_message = 'Invalid gender. Please provide a valid gender .';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    IF birth_date IS NULL THEN
        SET error_code = '46005_MISSING_BIRTH_DATE';
        SET error_message = 'Date of birth is required.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

     -- Check for duplicate profile
    SELECT COUNT(*) INTO duplicate_profile 
    FROM profile_personal p
    WHERE p.last_name = last_name 
    AND p.first_name = first_name 
    AND p.birth_date = birth_date;
    
    IF duplicate_profile > 0 THEN
        SET error_code = '46006_DUPLICATE_PROFILE';
        SET error_message = CONCAT('Profile with First Name: ', first_name, 
                          ', Last Name: ', last_name, 
                          ' and DOB: ', birth_date, 
                          ' already exists.');
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check for duplicate email
    IF email_id IS NOT NULL THEN
        SELECT COUNT(*) INTO duplicate_email 
        FROM profile_personal p
        WHERE p.email_id = email_id;
        
        IF duplicate_email > 0 THEN
            SET error_code = '46007_DUPLICATE_EMAIL';
            SET error_message = CONCAT('Profile with email: ', email_id, ' already exists.');
            SET custom_error = TRUE;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
        END IF;
    END IF;

    -- Check for duplicate phone
    IF phone_mobile IS NOT NULL THEN
        SELECT COUNT(*) INTO duplicate_phone 
        FROM profile_personal p
        WHERE p.phone_mobile = phone_mobile;
        
        IF duplicate_phone > 0 THEN
            SET error_code = '46008_DUPLICATE_PHONE';
            SET error_message = CONCAT('Profile with mobile phone: ', phone_mobile, ' already exists.');
            SET custom_error = TRUE;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
        END IF;
    END IF;


    -- Age validation
    SET age = TIMESTAMPDIFF(YEAR, birth_date, CURDATE());
    IF age < 21 OR age > 85 THEN
        SET error_code = '46009_INVALID_AGE';
        SET error_message = CONCAT('Age should be between 21 and 85. Provided age is ', age, ' years.');
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check if account exists
    SELECT COUNT(*) INTO account_exists 
    FROM account 
    WHERE account_id = accountid;
    
    IF account_exists = 0 THEN
        SET error_code = '46010_INVALID_ACCOUNT';
        SET error_message = 'Invalid Account ID. The account does not exist.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate phone number formats
    IF phone_mobile IS NOT NULL AND LENGTH(phone_mobile) < 10 THEN
        SET error_code = '46011_INVALID_MOBILE';
        SET error_message = 'Invalid mobile phone number. It should contain at least 10 digits.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF phone_home IS NOT NULL AND LENGTH(phone_home) < 10 THEN
        SET error_code = '46012_INVALID_HOME_PHONE';
        SET error_message = 'Invalid home phone number. It should contain at least 10 digits.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF phone_emergency IS NOT NULL AND LENGTH(phone_emergency) < 10 THEN
        SET error_code = '46013_INVALID_EMERGENCY_PHONE';
        SET error_message = 'Invalid emergency phone number. It should contain at least 10 digits.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate email format
    IF email_id IS NOT NULL AND email_id NOT LIKE '%_@__%.__%' THEN
        SET error_code = '46014_INVALID_EMAIL';
        SET error_message = 'Invalid email format.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate height and weight
    IF height_inches <= 0  THEN
        SET error_code = '46015_INVALID_HEIGHT';
        SET error_message = 'Invalid height. Height must be greater than 0.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF weight <= 0 THEN
        SET error_code = '46016_INVALID_WEIGHT';
        SET error_message = 'Invalid weight. Weight must be greater than 0.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;


    -- Start transaction
    START TRANSACTION;
    -- Insert the profile
    INSERT INTO profile_personal (
        account_id,
        first_name,
        last_name,
        middle_name,
        prefix,
        suffix,
        gender,
        birth_date,
        phone_mobile,
        phone_home,
        phone_emergency,
        email_id,
        marital_status, 
        religion, 
        nationality, 
        caste, 
        height_inches, 
        height_cms,
        weight, 
        weight_units, 
        complexion, 
        linkedin, 
        facebook, 
        instagram, 
        whatsapp_number, 
        profession, 
        disability,
        is_active, 
        created_date, 
        created_user,
        short_summary
    ) VALUES (
        accountid,
        first_name,
        last_name,
        middle_name,
        prefix,
        suffix,
        gender,
        birth_date,
        phone_mobile,
        phone_home,
        phone_emergency,
        email_id,
        marital_status, 
        religion, 
        nationality, 
        caste, 
        height_inches, 
        height_cms,
        weight, 
        weight_units, 
        complexion, 
        linkedin, 
        facebook, 
        instagram, 
        whatsapp_number, 
        profession, 
        disability,
        1, 
        NOW(), 
        created_user,
        short_summary
    );
    
    -- Get the newly inserted profile ID
    SET new_profile_id = LAST_INSERT_ID();
    
    -- If we got here, everything succeeded, so commit
    COMMIT;
    
    -- Return success results
    SELECT 
        'success' AS status,
        NULL as error_type,
        new_profile_id AS profile_id,
        NULL as error_code,
        NULL as error_message;
END$$
DELIMITER ;

-- Procedure: eb_profile_personal_get
DROP PROCEDURE IF EXISTS `eb_profile_personal_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_personal_get`(
    IN p_profile_id INT,
    IN p_account_id INT,
    IN p_created_user VARCHAR(100)
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
            'ERROR', error_message, p_created_user, 'PROFILE_PERSONAL_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_PERSONAL_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or account_id is provided
    IF p_profile_id IS NULL AND p_account_id IS NULL THEN
        SET error_code = '47001';
        SET error_message = 'Either profile_id or account_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_id IS NOT NULL THEN
        -- Get specific profile by ID
        SELECT 
            pp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_personal pp
        WHERE pp.profile_id = p_profile_id
        AND pp.is_active = 1;
        
    ELSEIF p_account_id IS NOT NULL THEN
        -- Get profile by account_id
        SELECT 
            pp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_personal pp
        WHERE pp.account_id = p_account_id
        AND pp.is_active = 1;
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
            WHEN p_profile_id IS NOT NULL THEN CONCAT('Profile retrieved by ID: ', p_profile_id)
            ELSE CONCAT('Profile retrieved for account ID: ', p_account_id)
        END, 
        p_created_user, 
        'PROFILE_PERSONAL_GET', 
        CASE 
            WHEN p_profile_id IS NOT NULL THEN CONCAT('Profile ID: ', p_profile_id)
            ELSE CONCAT('Account ID: ', p_account_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_personal_update
DROP PROCEDURE IF EXISTS `eb_profile_personal_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_personal_update`(
    p_profile_id int,
    accountid int,
    first_name varchar(45),
    last_name varchar(45),
    middle_name varchar(45),
    prefix varchar(45),
    suffix varchar(45),
    gender int,
    birth_date date,
    phone_mobile varchar(15),
    phone_home varchar(15),
    phone_emergency varchar(15),
    email_id varchar(150),
    marital_status int, 
    religion int, 
    nationality int, 
    caste int, 
    height_inches int, 
    height_cms int,
    weight int, 
    weight_units varchar(4), 
    complexion int, 
    linkedin varchar(450), 
    facebook varchar(450), 
    instagram varchar(450), 
    whatsapp_number varchar(15), 
    profession int, 
    disability int,
    updated_user varchar(45),
    short_summary longtext
)
BEGIN
    -- Declare variables for error handling
    DECLARE age INT;
    DECLARE profile_exists INT DEFAULT 0;
    DECLARE duplicate_email INT DEFAULT 0;
    DECLARE duplicate_phone INT DEFAULT 0;
    DECLARE account_exists INT DEFAULT 0;
    DECLARE error_msg VARCHAR(1000);
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE original_account_id INT;
    
    -- Declare handler for SQL exceptions 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;
        SELECT 
            'fail' AS status,
            'SQL Exception' as error_type,
            null AS profile_id,
            error_code,
            error_message;
    END;
    
    -- Declare handler for custom errors (SQLSTATE starting with '45')
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        ROLLBACK;
        -- Return error information
        SELECT 
            'fail' AS status,
            'Validation Exception' as error_type,
            null AS profile_id,
            error_code,
            error_message;
    END;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Validation: Ensure profile_id is a valid positive integer
    IF p_profile_id <= 0 THEN
        SET error_code = '47001_INVALID_PROFILE_ID';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if profile exists
    
    SELECT COUNT(*), account_id INTO profile_exists, original_account_id
    FROM profile_personal 
    WHERE profile_id = p_profile_id
    GROUP BY account_id;
    
    IF profile_exists = 0 THEN
        SET error_code = '47002_PROFILE_NOT_FOUND';
        SET error_message = 'Profile not found. The profile does not exist.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validation: Ensure accountid is a valid positive integer
    IF accountid <= 0 THEN
        SET error_code = '47003_INVALID_ACCOUNTID';
        SET error_message = 'Invalid accountid. It must be a positive integer.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validation: Ensure essential fields are not NULL or empty
    IF first_name IS NULL OR TRIM(first_name) = '' THEN
        SET error_code = '47004_MISSING_FIRST_NAME';
        SET error_message = 'First name cannot be empty.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF last_name IS NULL OR TRIM(last_name) = '' THEN
        SET error_code = '47005_MISSING_LAST_NAME';
        SET error_message = 'Last name cannot be empty.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF gender NOT IN (SELECT id FROM lookup_table WHERE category = 'Gender' ) THEN
        SET error_code = '47006_INVALID_GENDER';
        SET error_message = 'Invalid gender. Please provide a valid gender (1 for Male, 2 for Female).';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    IF birth_date IS NULL THEN
        SET error_code = '47007_MISSING_BIRTH_DATE';
        SET error_message = 'Date of birth is required.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check for duplicate email (excluding current profile)
    IF email_id IS NOT NULL THEN
        SELECT COUNT(*) INTO duplicate_email 
        FROM profile_personal p
        WHERE p.email_id = email_id AND p.profile_id != p_profile_id;
        
        IF duplicate_email > 0 THEN
            SET error_code = '47008_DUPLICATE_EMAIL';
            SET error_message = CONCAT('Profile with email: ', email_id, ' already exists.');
            SET custom_error = TRUE;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM account a WHERE a.account_id = accountid AND is_active != 1) THEN
        SET error_code = '47009_ACCOUNT_IS_NOT_ACTIVE';
        SET error_message = 'This account is not active. Please contact administrator to enable your account.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check for duplicate phone (excluding current profile)
    IF phone_mobile IS NOT NULL THEN
        SELECT COUNT(*) INTO duplicate_phone 
        FROM profile_personal p
        WHERE p.phone_mobile = phone_mobile AND p.profile_id != p_profile_id;
        
        IF duplicate_phone > 0 THEN
            SET error_code = '47010_DUPLICATE_PHONE';
            SET error_message = CONCAT('Profile with mobile phone: ', phone_mobile, ' already exists.');
            SET custom_error = TRUE;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
        END IF;
    END IF;

    -- Age validation
    SET age = TIMESTAMPDIFF(YEAR, birth_date, CURDATE());
    IF age < 21 OR age > 85 THEN
        SET error_code = '47011_INVALID_AGE';
        SET error_message = CONCAT('Age should be between 21 and 85. Provided age is ', age, ' years.');
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check if account exists
    SELECT COUNT(*) INTO account_exists 
    FROM account 
    WHERE account_id = accountid;
    
    IF account_exists = 0 THEN
        SET error_code = '47012_INVALID_ACCOUNT';
        SET error_message = 'Invalid Account ID. The account does not exist.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate phone number formats
    IF phone_mobile IS NOT NULL AND LENGTH(phone_mobile) < 10 THEN
        SET error_code = '47013_INVALID_MOBILE';
        SET error_message = 'Invalid mobile phone number. It should contain at least 10 digits.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF phone_home IS NOT NULL AND LENGTH(phone_home) < 10 THEN
        SET error_code = '47014_INVALID_HOME_PHONE';
        SET error_message = 'Invalid home phone number. It should contain at least 10 digits.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF phone_emergency IS NOT NULL AND LENGTH(phone_emergency) < 10 THEN
        SET error_code = '47015_INVALID_EMERGENCY_PHONE';
        SET error_message = 'Invalid emergency phone number. It should contain at least 10 digits.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate email format
    IF email_id IS NOT NULL AND email_id NOT LIKE '%_@__%.__%' THEN
        SET error_code = '47016_INVALID_EMAIL';
        SET error_message = 'Invalid email format.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate height and weight
    IF height_inches <= 0  THEN
        SET error_code = '47017_INVALID_HEIGHT';
        SET error_message = 'Invalid height. Height must be greater than 0.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF weight <= 0 THEN
        SET error_code = '47018_INVALID_WEIGHT';
        SET error_message = 'Invalid weight. Weight must be greater than 0.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Prevent changing account_id if it's different from original
    IF accountid != original_account_id THEN
        SET error_code = '47019_ACCOUNT_ID_CHANGE_NOT_ALLOWED';
        SET error_message = 'Changing the account ID associated with a profile is not allowed.';
        SET custom_error = TRUE;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Update the profile
    UPDATE profile_personal SET
        first_name = first_name,
        last_name = last_name,
        middle_name = middle_name,
        prefix = prefix,
        suffix = suffix,
        gender = gender,
        birth_date = birth_date,
        phone_mobile = phone_mobile,
        phone_home = phone_home,
        phone_emergency = phone_emergency,
        email_id = email_id,
        marital_status = marital_status, 
        religion = religion, 
        nationality = nationality, 
        caste = caste, 
        height_inches = height_inches, 
        height_cms = height_cms,
        weight = weight, 
        weight_units = weight_units, 
        complexion = complexion, 
        linkedin = linkedin, 
        facebook = facebook, 
        instagram = instagram, 
        whatsapp_number = whatsapp_number, 
        profession = profession, 
        disability = disability,
        updated_date = NOW(), 
        updated_user = updated_user,
        short_summary = short_summary
    WHERE profile_id = p_profile_id;
    
    -- If we got here, everything succeeded, so commit
    COMMIT;
    
    -- Return success results
    SELECT 
        'success' AS status,
        NULL as error_type,
        p_profile_id AS profile_id,
        NULL as error_code,
        NULL as error_message;
END$$
DELIMITER ;

-- Procedure: eb_profile_photo_create
DROP PROCEDURE IF EXISTS `eb_profile_photo_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_photo_create`(
 IN p_profile_id INT,
    IN p_url VARCHAR(100),
    IN p_photo_type INT,
    IN p_caption VARCHAR(100),
    IN p_description VARCHAR(255),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_photo_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    DECLARE total_photos INT;
    DECLARE headshot_count INT;
    DECLARE type_count INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_PHOTO_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_PHOTO_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '54001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '54002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate URL
    IF p_url IS NULL OR p_url = '' THEN
        SET error_code = '54003';
        SET error_message = 'Photo URL is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate photo_type
    IF p_photo_type IS NULL THEN
        SET error_code = '54004';
        SET error_message = 'Photo type is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate total number of photos for the profile (max 7)
    SELECT COUNT(*) INTO total_photos FROM profile_photo 
    WHERE profile_id = p_profile_id AND softdelete = 0;

    IF total_photos >= 7 THEN
        SET error_code = '54006';
        SET error_message = 'Maximum limit of 7 photos per profile reached.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;

    -- Validate photo type based on lookup_table values
    -- Clear Headshot (photo_type = 1) can have only one photo
    IF p_photo_type = (
        SELECT id FROM lookup_table 
        WHERE category = 'Photo_type' 
        AND name != 'Other' 
        AND id = p_photo_type
    ) THEN
        SELECT COUNT(*) INTO headshot_count FROM profile_photo 
        WHERE profile_id = p_profile_id AND photo_type = p_photo_type AND softdelete = 0;
        
        IF headshot_count > 0 THEN
            SET error_code = '54007';
            SET error_message = 'Only one Clear Headshot photo is allowed per profile.';
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = error_message;
        END IF;
    ELSE
        -- For other photo types (Full-body shot, Casual or Lifestyle Shot, etc.), maximum 2 photos allowed per type
        SELECT COUNT(*) INTO type_count FROM profile_photo 
        WHERE profile_id = p_profile_id AND photo_type = p_photo_type 
        AND caption != 'Other'
        AND softdelete = 0;
        
        IF type_count >= 2 THEN
            SET error_code = '54008';
            SET error_message = 'Maximum limit of 2 photos for this photo type reached.';
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = error_message;
        END IF;
    END IF;
    
    -- Validate caption
    IF p_caption IS NULL OR p_caption = '' THEN
        SET error_code = '54005';
        SET error_message = 'Caption is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- No need to handle primary photo as the field doesn't exist in the table
    
    -- Insert the new photo record
    INSERT INTO profile_photo (
        profile_id,
        url,
        photo_type,
        caption,
        description,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified
    ) VALUES (
        p_profile_id,
        p_url,
        p_photo_type,
        p_caption,
        p_description,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0 -- Not verified by default
    );
    
    -- Get the new photo ID
    SET new_photo_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Photo created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_PHOTO_CREATE', 
        CONCAT('Profile ID: ', p_profile_id, ', Photo URL: ', p_url, ', Photo Type: ', p_photo_type, ', Caption: ', p_caption),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new photo ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_photo_id AS profile_photo_id,
        NULL AS error_code,
        NULL AS error_message;
END$$
DELIMITER ;

-- Procedure: eb_profile_photo_delete
DROP PROCEDURE IF EXISTS `eb_profile_photo_delete`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_photo_delete`(
    IN photo_id INT,
    IN profile_id INT,
    IN user_deleted VARCHAR(45)
    -- IN ip_address VARCHAR(45),
    -- IN browser_profile VARCHAR(255)
)
BEGIN
    -- Step 1: Declare variables for time tracking and execution time
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;

    -- Set the start time of the procedure execution
    SET start_time = NOW();

    -- Step 2: Start a transaction to ensure data consistency
    START TRANSACTION;

    -- Step 3: Validate if the profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = profile_id) THEN
        -- Rollback the transaction and raise an error if profile does not exist
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Profile does not exist for the given profile_id';
    END IF;

    -- Step 4: Validate if the photo exists for the given profile_id and photo_id
    IF NOT EXISTS (SELECT 1 FROM profile_photo WHERE profile_id = profile_id AND profile_photo_id = photo_id) THEN
        -- Rollback the transaction and raise an error if photo does not exist
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Photo does not exist for the given photo_id';
    END IF;

    -- Step 5: Delete the profile photo
    DELETE FROM profile_photo WHERE profile_id = profile_id AND profile_photo_id = photo_id;

    -- Step 6: Commit the transaction after successful deletion
    COMMIT;

    -- Step 7: Capture the end time and calculate the execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(SECOND, start_time, end_time);

    -- Step 8: Log the activity in the activity_log table
    INSERT INTO activity_log (
        log_type, 
        message, 
        created_by, 
        start_time, 
        end_time, 
        execution_time 
        -- ip_address, 
        -- browser_profile
    ) 
    VALUES (
        'ACTIVITY', 
        CONCAT('Profile photo deleted for profile ID ', profile_id), 
        user_deleted,
        start_time,
        end_time,
        execution_time
        -- ip_address,
        -- browser_profile
    );

    -- Return a success message
    SELECT 'Photo deleted successfully' AS message;

END$$
DELIMITER ;

-- Procedure: eb_profile_photo_get
DROP PROCEDURE IF EXISTS `eb_profile_photo_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_photo_get`(
    IN p_profile_id INT
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
            'ERROR', error_message, p_profile_id, 'PROFILE_PHOTO_GET', 
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
            'ERROR', error_message, p_profile_id, 'PROFILE_PHOTO_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or profile_photo_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '54005';
        SET error_message = 'Either profile_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_id IS NOT NULL THEN
        -- Get all photos for a profile
        SELECT 
            pp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_photo pp
        WHERE pp.profile_id = p_profile_id and softdelete = 0
        -- AND (pp.isverified != 0 OR pp.isverified IS NULL) -- Exclude soft-deleted records
        ORDER BY pp.date_created DESC; -- Newest photos first
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
        CONCAT('Photos retrieved for profile ID: ', p_profile_id), 
        p_profile_id, 
        'PROFILE_PHOTO_GET', 
        CONCAT('Profile ID: ', p_profile_id),
        start_time, end_time, execution_time
    );


    
END$$
DELIMITER ;

-- Procedure: eb_profile_property_create
DROP PROCEDURE IF EXISTS `eb_profile_property_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_property_create`(
    IN p_profile_id INT,
    IN p_property_type INT,
    IN p_ownership_type INT,
    IN p_property_address VARCHAR(125),
    IN p_property_value DECIMAL(10,2),
    IN p_property_description VARCHAR(2000),
    IN p_isoktodisclose BIT(1),
    IN p_created_by VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_property_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_by, 'PROFILE_PROPERTY_CREATE', 
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
            'ERROR', error_message, p_created_by, 'PROFILE_PROPERTY_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '55001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '55002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate property_type
    IF p_property_type IS NULL OR p_property_type = '' THEN
        SET error_code = '55003';
        SET error_message = 'Property type is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate property_value
    IF p_property_value IS NULL THEN
        SET error_code = '55004';
        SET error_message = 'Property value is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new property record
    INSERT INTO profile_property (
        profile_id,
        property_type,
        ownership_type,
        property_address,
        property_value,
        property_description,
        isoktodisclose,
        created_date,
        modified_date,
        created_by,
        modifyed_by,
        isverified
    ) VALUES (
        p_profile_id,
        p_property_type,
        p_ownership_type,
        p_property_address,
        p_property_value,
        p_property_description,
        p_isoktodisclose,
        NOW(),
        NOW(),
        p_created_by,
        p_created_by,
        0 -- Not verified by default
    );
    
    -- Get the new property ID
    SET new_property_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Property created for profile ID: ', p_profile_id), 
        p_created_by, 
        'PROFILE_PROPERTY_CREATE', 
        CONCAT('Profile ID: ', p_profile_id, ', Property Type: ', p_property_type, ', Property Value: ', p_property_value),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new property ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_property_id AS profile_property_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_property_get
DROP PROCEDURE IF EXISTS `eb_profile_property_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_property_get`(
    IN p_profile_id INT,
    IN p_profile_property_id INT,
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
            'ERROR', error_message, p_created_user, 'PROFILE_PROPERTY_GET', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_PROPERTY_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or profile_property_id is provided
    IF p_profile_id IS NULL AND p_profile_property_id IS NULL THEN
        SET error_code = '55005';
        SET error_message = 'Either profile_id or profile_property_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_property_id IS NOT NULL THEN
        -- Get specific property by ID
        SELECT 
            pp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_property pp
        WHERE pp.profile_property_id = p_profile_property_id
        AND (pp.isverified != -1 OR pp.isverified IS NULL); -- Exclude soft-deleted records
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get all properties for a profile
        SELECT 
            pp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_property pp
        WHERE pp.profile_id = p_profile_id
        AND (pp.isverified != -1 OR pp.isverified IS NULL) -- Exclude soft-deleted records
        ORDER BY pp.property_type, pp.created_date DESC;
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
            WHEN p_profile_property_id IS NOT NULL THEN CONCAT('Property retrieved by ID: ', p_profile_property_id)
            ELSE CONCAT('Properties retrieved for profile ID: ', p_profile_id)
        END, 
        p_created_user, 
        'PROFILE_PROPERTY_GET', 
        CASE 
            WHEN p_profile_property_id IS NOT NULL THEN CONCAT('Property ID: ', p_profile_property_id)
            ELSE CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_property_update
DROP PROCEDURE IF EXISTS `eb_profile_property_update`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_property_update`(
    IN p_profile_id INT,
    IN p_profile_property_id INT,
    IN p_property_type INT,
    IN p_ownership_type INT,
    IN p_property_address VARCHAR(125),
    IN p_property_value DECIMAL(10,2),
    IN p_property_description VARCHAR(2000),
    IN p_isoktodisclose BIT(1),
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
    DECLARE record_exists INT DEFAULT 0;
    DECLARE current_profile_id INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_modified_user, 'PROFILE_PROPERTY_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Property ID: ', p_profile_property_id),
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
            'ERROR', error_message, p_modified_user, 'PROFILE_PROPERTY_UPDATE', 
            CONCAT('Error Code: ', error_code, ', Property ID: ', p_profile_property_id),
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
    
    -- Validation: Ensure profile_property_id is valid
    IF p_profile_property_id IS NULL OR p_profile_property_id <= 0 THEN
        SET error_code = '55006';
        SET error_message = 'Invalid profile_property_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if the property record exists and get the profile_id
    SELECT COUNT(*), profile_id INTO record_exists, current_profile_id 
    FROM profile_property 
    WHERE property_id = p_profile_property_id
    group by profile_id;
    
    IF record_exists = 0 THEN
        SET error_code = '55007';
        SET error_message = CONCAT('Property with ID ', p_profile_property_id, ' does not exist.');
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate property_type if provided
    IF p_property_type IS NOT NULL AND p_property_type = '' THEN
        SET error_code = '55008';
        SET error_message = 'Property type cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate property_value if provided
    IF p_property_value IS NOT NULL AND p_property_value = '' THEN
        SET error_code = '55009';
        SET error_message = 'Property value cannot be empty if provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Update the property record with non-null values
    UPDATE profile_property
    SET 
        property_type = IFNULL(p_property_type, property_type),
        ownership_type = IFNULL(p_ownership_type, ownership_type),
		property_address = IFNULL(p_property_address, property_address),
		property_value = IFNULL(p_property_value, property_value),
		property_description = IFNULL(p_property_description, property_description),
        modified_date = NOW(),
        modifyed_by = p_modified_user
    WHERE property_id = p_profile_property_id;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful update
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'UPDATE', 
        CONCAT('Property updated with ID: ', p_profile_property_id), 
        p_modified_user, 
        'PROFILE_PROPERTY_UPDATE', 
        CONCAT('Property ID: ', p_profile_property_id, ', Profile ID: ', current_profile_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success
    SELECT 
        'success' AS status,
        NULL AS error_type,
        p_profile_property_id AS profile_property_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_profile_related_data_count
DROP PROCEDURE IF EXISTS `eb_profile_related_data_count`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_related_data_count`(
    IN p_profile_id INT,
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Error handling variables
    DECLARE v_error_code VARCHAR(100) DEFAULT NULL;
    DECLARE v_error_message VARCHAR(255) DEFAULT NULL;

    -- Timing variables
    DECLARE v_start_time DATETIME;
    DECLARE v_end_time DATETIME;
    DECLARE v_execution_time INT;

    -- Exception handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT,
            v_error_code = MYSQL_ERRNO;

        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR',
            v_error_message,
            p_created_user,
            'PROFILE_RELATED_DATA_COUNT',
            CONCAT('Error Code: ', v_error_code),
            v_start_time,
            NOW(),
            TIMESTAMPDIFF(MICROSECOND, v_start_time, NOW()) / 1000
        );

        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            v_error_code AS error_code,
            v_error_message AS error_message;
    END;

    -- Start timer
    SET v_start_time = NOW();

    -- Validation
    IF p_profile_id IS NULL THEN
        SET v_error_code = '47010';
        SET v_error_message = 'Profile ID must be provided.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END IF;

    -- Get counts for profile-related tables
    SELECT
        (SELECT COUNT(*) FROM profile_property        WHERE profile_id = p_profile_id) AS property_count,
        (SELECT COUNT(*) FROM profile_personal        WHERE profile_id = p_profile_id) AS personal_count,
        (SELECT COUNT(*) FROM profile_lifestyle       WHERE profile_id = p_profile_id) AS lifestyle_count,
        (SELECT COUNT(*) FROM profile_hobby_interest  WHERE profile_id = p_profile_id) AS hobby_interest_count,
        (SELECT COUNT(*) FROM profile_family_reference WHERE profile_id = p_profile_id) AS family_reference_count,
        (SELECT COUNT(*) FROM profile_photo         WHERE profile_id = p_profile_id) AS photo_count,
        (SELECT COUNT(*) FROM profile_address         WHERE profile_id = p_profile_id) AS address_count,
        (SELECT COUNT(*) FROM profile_education       WHERE profile_id = p_profile_id) AS education_count,
        (SELECT COUNT(*) FROM profile_employment      WHERE profile_id = p_profile_id) AS employment_count,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message;

    -- End timer
    SET v_end_time = NOW();
    SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time) / 1000;

    -- Log success
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ',
        CONCAT('Counts retrieved for Profile ID: ', p_profile_id),
        p_created_user,
        'PROFILE_RELATED_DATA_COUNT',
        CONCAT('Profile ID: ', p_profile_id),
        v_start_time, v_end_time, v_execution_time
    );
END$$
DELIMITER ;

-- Procedure: eb_profile_search_get
DROP PROCEDURE IF EXISTS `eb_profile_search_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_search_get`(
    IN p_profile_id INT,
    -- Optional override parameters
    IN p_min_age INT,
    IN p_max_age INT,
    IN p_religion INT,
    IN p_max_education INT,
    IN p_occupation INT,
    IN p_country INT,
    IN p_casete_id INT,
    IN p_marital_status INT,
    IN p_gender INT
)
BEGIN
    -- Declare variables to hold search preferences
    DECLARE v_min_age INT;
    DECLARE v_max_age INT;
    DECLARE v_religion INT;
    DECLARE v_max_education INT;
    DECLARE v_occupation INT;
    DECLARE v_country INT;
    DECLARE v_casete_id INT;
    DECLARE v_marital_status INT;
    
    DECLARE original_sql_mode VARCHAR(1000);
    -- Save current SQL mode
    SET original_sql_mode = @@SESSION.sql_mode;
    -- Remove ONLY_FULL_GROUP_BY temporarily
    SET SESSION sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', '')); 

    -- Get search preferences from the profile_search_prefernce table
    SELECT 
        min_age, max_age, religion, max_education, occupation, country, casete_id, marital_status
    INTO 
        v_min_age, v_max_age, v_religion, v_max_education, v_occupation, v_country, v_casete_id, v_marital_status
    FROM 
        profile_search_preference
    WHERE 
        profile_id = p_profile_id
    LIMIT 1;
    
    -- Use input parameters if provided, but set to NULL if parameter is -1 (ignore filter)
    -- For other values, use parameter value directly, only fallback to preferences if parameter is NULL
    SET v_min_age = CASE 
        WHEN p_min_age = -1 THEN NULL 
        WHEN p_min_age IS NOT NULL THEN p_min_age 
        ELSE v_min_age 
    END;
    SET v_max_age = CASE 
        WHEN p_max_age = -1 THEN NULL 
        WHEN p_max_age IS NOT NULL THEN p_max_age 
        ELSE v_max_age 
    END;
    SET v_religion = CASE 
        WHEN p_religion = -1 THEN NULL 
        WHEN p_religion IS NOT NULL THEN p_religion 
        ELSE v_religion 
    END;
    SET v_max_education = CASE 
        WHEN p_max_education = -1 THEN NULL 
        WHEN p_max_education IS NOT NULL THEN p_max_education 
        ELSE v_max_education 
    END;
    SET v_occupation = CASE 
        WHEN p_occupation = -1 THEN NULL 
        WHEN p_occupation IS NOT NULL THEN p_occupation 
        ELSE v_occupation 
    END;
    SET v_country = CASE 
        WHEN p_country = -1 THEN NULL 
        WHEN p_country IS NOT NULL THEN p_country 
        ELSE v_country 
    END;
    SET v_casete_id = CASE 
        WHEN p_casete_id = -1 THEN NULL 
        WHEN p_casete_id IS NOT NULL THEN p_casete_id 
        ELSE v_casete_id 
    END;
    SET v_marital_status = CASE 
        WHEN p_marital_status = -1 THEN NULL 
        WHEN p_marital_status IS NOT NULL THEN p_marital_status 
        ELSE v_marital_status 
    END;
    -- Main query to search profiles based on preferences
    SELECT 
		pp.profile_id,
        pp.first_name,
        pp.last_name,
        lt.name AS gender,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) AS age,
        pp.marital_status,
        pa.country_name,
        profile_photo.url,
        pp.religion,
        pf.to_profile_id
        , case when pf.is_active =1 then 1 else 0 end IsFavorite
    FROM 
        profile_personal pp
	LEFT JOIN 
		profile_favorites pf ON pf.from_profile_id = pp.profile_id
	LEFT JOIN 
		(SELECT profile_photo.* FROM profile_photo INNER JOIN lookup_table on photo_type = id where caption ='Clear Headshot') AS profile_photo  ON pp.profile_id = profile_photo.profile_id	
    LEFT JOIN 
        lookup_table lt ON lt.category = 'Gender' AND lt.id = pp.gender
    LEFT JOIN 
        (select pa.*, country_name from profile_address pa LEFT JOIN country c ON c.country_id = pa.country_id) pa ON pa.profile_id = pp.profile_id
    
    LEFT JOIN 
        profile_education pe ON pe.profile_id = pp.profile_id
    /*LEFT JOIN 
        profile_employment pem ON pem.profile_id = pp.profile_id */
    WHERE 
        pp.is_active = 1
        AND (pp.gender = p_gender OR p_gender IS NULL)
        -- Apply age filter if specified
        AND (v_min_age IS NULL OR TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) >= v_min_age)
		AND (v_max_age IS NULL OR TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) <= v_max_age)
        -- Apply marital status filter if specified
        AND (v_marital_status IS NULL OR pp.marital_status = v_marital_status)         

        -- Apply religion filter if specified
        AND (v_religion IS NULL OR pp.religion = v_religion)
        -- Apply education filter if specified
        -- AND pe.education_level = v_max_education
         /*
        -- Apply occupation filter if specified
        AND (v_occupation IS NULL OR EXISTS (
            SELECT 1 FROM profile_employment pem2 
            WHERE pem2.profile_id = pp.profile_id 
            AND pem2.job_title_id = v_occupation
        )) */
        -- Apply caste filter if specified
        -- AND (v_casete_id IS NULL OR pp.caste = v_casete_id)
        -- Apply country filter if specified
        AND (v_country IS NULL OR EXISTS (
            SELECT 1 FROM profile_address pa2 
            WHERE pa2.profile_id = pp.profile_id 
            AND pa2.country_id = v_country
        ))

        -- Exclude the profile that is doing the search
        AND pp.profile_id <> p_profile_id
    GROUP BY 
        pp.profile_id,
        pp.first_name,
        pp.last_name,
        lt.name ,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) ,
        pp.marital_status,
        pa.country_name,
        profile_photo.url,
        pp.religion,
        pf.to_profile_id
        -- , case when pf.is_active =1 then 1 else 0 end       
    ORDER BY 
        pp.first_name, pp.last_name;
	
	-- Restore original SQL mode
    SET SESSION sql_mode = original_sql_mode;
END$$
DELIMITER ;

-- Procedure: eb_profile_search_get_all
DROP PROCEDURE IF EXISTS `eb_profile_search_get_all`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_search_get_all`(
    IN p_profile_id INT
)
BEGIN
    -- Main query to get all active profiles except the user's own
    SELECT 
        pp.profile_id,
        pp.first_name,
        pp.last_name,
        lt.name AS gender,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) AS age,
        pp.marital_status,
        pa.country_name,
        profile_photo.url,
        pp.religion,
        pf.to_profile_id,
        CASE WHEN pf.is_active = 1 THEN 1 ELSE 0 END AS IsFavorite
    FROM 
        profile_personal pp
    LEFT JOIN 
        profile_favorites pf ON pf.from_profile_id = pp.profile_id
    LEFT JOIN 
        (SELECT profile_photo.* FROM profile_photo 
         INNER JOIN lookup_table ON photo_type = id 
         WHERE caption = 'Clear Headshot') AS profile_photo 
        ON pp.profile_id = profile_photo.profile_id	
    LEFT JOIN 
        lookup_table lt ON lt.category = 'Gender' AND lt.id = pp.gender
    LEFT JOIN 
        (SELECT pa.*, country_name FROM profile_address pa 
         LEFT JOIN country c ON c.country_id = pa.country_id) pa 
        ON pa.profile_id = pp.profile_id
    WHERE 
        pp.is_active = 1
        -- Exclude the profile that is doing the search
        AND pp.profile_id <> p_profile_id
    GROUP BY 
        pp.profile_id
    ORDER BY 
        pp.first_name, pp.last_name;
END$$
DELIMITER ;

-- Procedure: eb_profile_search_get_v1
DROP PROCEDURE IF EXISTS `eb_profile_search_get_v1`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_search_get_v1`(
    IN p_profile_id INT,
    -- Optional override parameters
    IN p_min_age INT,
    IN p_max_age INT,
    IN p_religion INT,
    IN p_max_education INT,
    IN p_occupation INT,
    IN p_country INT,
    IN p_casete_id INT,
    IN p_marital_status INT
)
BEGIN
    -- Declare variables to hold search preferences
    DECLARE v_min_age INT;
    DECLARE v_max_age INT;
    DECLARE v_religion INT;
    DECLARE v_max_education INT;
    DECLARE v_occupation INT;
    DECLARE v_country INT;
    DECLARE v_casete_id INT;
    DECLARE v_marital_status INT;
    
    -- Get search preferences from the profile_search_prefernce table
    SELECT 
        min_age, max_age, religion, max_education, occupation, country, casete_id, marital_status
    INTO 
        v_min_age, v_max_age, v_religion, v_max_education, v_occupation, v_country, v_casete_id, v_marital_status
    FROM 
        profile_search_preference
    WHERE 
        profile_id = p_profile_id
    LIMIT 1;
    
    -- Use input parameters if provided, but set to NULL if parameter is -1 (ignore filter)
    -- For other values, use parameter value directly, only fallback to preferences if parameter is NULL
    SET v_min_age = CASE 
        WHEN p_min_age = -1 THEN NULL 
        WHEN p_min_age IS NOT NULL THEN p_min_age 
        ELSE v_min_age 
    END;
    SET v_max_age = CASE 
        WHEN p_max_age = -1 THEN NULL 
        WHEN p_max_age IS NOT NULL THEN p_max_age 
        ELSE v_max_age 
    END;
    SET v_religion = CASE 
        WHEN p_religion = -1 THEN NULL 
        WHEN p_religion IS NOT NULL THEN p_religion 
        ELSE v_religion 
    END;
    SET v_max_education = CASE 
        WHEN p_max_education = -1 THEN NULL 
        WHEN p_max_education IS NOT NULL THEN p_max_education 
        ELSE v_max_education 
    END;
    SET v_occupation = CASE 
        WHEN p_occupation = -1 THEN NULL 
        WHEN p_occupation IS NOT NULL THEN p_occupation 
        ELSE v_occupation 
    END;
    SET v_country = CASE 
        WHEN p_country = -1 THEN NULL 
        WHEN p_country IS NOT NULL THEN p_country 
        ELSE v_country 
    END;
    SET v_casete_id = CASE 
        WHEN p_casete_id = -1 THEN NULL 
        WHEN p_casete_id IS NOT NULL THEN p_casete_id 
        ELSE v_casete_id 
    END;
    SET v_marital_status = CASE 
        WHEN p_marital_status = -1 THEN NULL 
        WHEN p_marital_status IS NOT NULL THEN p_marital_status 
        ELSE v_marital_status 
    END;
    
    -- Main query to search profiles based on preferences
    SELECT 
        pp.profile_id,
        pp.first_name,
        pp.last_name,
        lt.name AS gender,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) AS age,
        pp.marital_status,
        pa.country_name,
        profile_photo.url,
        pp.religion,
        pf.to_profile_id,
        CASE WHEN pf.is_active = 1 THEN 1 ELSE 0 END AS IsFavorite
    FROM 
        profile_personal pp
    LEFT JOIN 
        profile_favorites pf ON pf.from_profile_id = pp.profile_id
    LEFT JOIN 
        (SELECT profile_photo.* FROM profile_photo 
         INNER JOIN lookup_table ON photo_type = id 
         WHERE caption ='Clear Headshot') AS profile_photo ON pp.profile_id = profile_photo.profile_id	
    LEFT JOIN 
        lookup_table lt ON lt.category = 'Gender' AND lt.id = pp.gender
    LEFT JOIN 
        (SELECT pa.*, country_name 
         FROM profile_address pa 
         LEFT JOIN country c ON c.country_id = pa.country_id) pa ON pa.profile_id = pp.profile_id
    WHERE 
        pp.is_active = 1
        -- Apply age filter if specified (NULL means no filter)
        AND (v_min_age IS NULL OR TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) >= v_min_age)
        AND (v_max_age IS NULL OR TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) <= v_max_age)
        -- Apply marital status filter if specified (NULL means no filter)
        AND (v_marital_status IS NULL OR pp.marital_status = v_marital_status)         
        -- Apply religion filter if specified (NULL means no filter)
        AND (v_religion IS NULL OR pp.religion = v_religion)
        -- Apply country filter if specified (NULL means no filter)
        AND (v_country IS NULL OR EXISTS (
            SELECT 1 FROM profile_address pa2 
            WHERE pa2.profile_id = pp.profile_id 
            AND pa2.country_id = v_country
        ))
        -- Exclude the profile that is doing the search
        AND pp.profile_id <> p_profile_id
    GROUP BY 
        pp.profile_id
    ORDER BY 
        pp.first_name, pp.last_name;
END$$
DELIMITER ;

-- Procedure: eb_profile_search_preference_create
DROP PROCEDURE IF EXISTS `eb_profile_search_preference_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_search_preference_create`(
    IN p_profile_id INT,
    IN p_min_age INT,
    IN p_max_age INT,
    IN p_gender INT,
    IN p_religion INT,
    IN p_max_education INT,
    IN p_occupation INT,
    IN p_country INT,
    IN p_casete_id INT,
    IN p_marital_status INT,
    IN p_created_user VARCHAR(40)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_preference_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
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
            'ERROR', error_message, p_created_user, 'PROFILE_SEARCH_PREFERENCE_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_SEARCH_PREFERENCE_CREATE', 
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
    
    -- Validation: Ensure profile_id is valid
    IF p_profile_id IS NULL OR p_profile_id <= 0 THEN
        SET error_code = '57001';
        SET error_message = 'Invalid profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_profile_id) THEN
        SET error_code = '57002';
        SET error_message = 'Profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate min_age
    IF p_min_age IS NOT NULL AND (p_min_age < 20 OR p_min_age > 70) THEN
        SET error_code = '57003';
        SET error_message = 'Minimum age must be between 20 and 70.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate max_age
    IF p_max_age IS NOT NULL AND (p_max_age < 20 OR p_max_age > 70) THEN
        SET error_code = '57004';
        SET error_message = 'Maximum age must be between 20 and 70.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate min_age and max_age relationship
    IF p_min_age IS NOT NULL AND p_max_age IS NOT NULL AND p_min_age > p_max_age THEN
        SET error_code = '57005';
        SET error_message = 'Minimum age cannot be greater than maximum age.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate gender from lookup table
    IF p_gender IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_table WHERE category = 'gender' AND id = p_gender AND isactive = 1) THEN
        SET error_code = '57006';
        SET error_message = 'Invalid gender preference code.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate religion from lookup table
    IF p_religion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_table WHERE category = 'religion' AND id = p_religion AND isactive = 1) THEN
        SET error_code = '57007';
        SET error_message = 'Invalid religion code.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate education from lookup table
    IF p_max_education IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_table WHERE category = 'education_level' AND id = p_max_education AND isactive = 1) THEN
        SET error_code = '57008';
        SET error_message = 'Invalid education level code.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate occupation from lookup table
    IF p_occupation IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_table WHERE category = 'profession' AND id = p_occupation AND isactive = 1) THEN
        SET error_code = '57009';
        SET error_message = 'Invalid occupation code.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate caste from lookup table
    IF p_casete_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_table WHERE category = 'caste' AND id = p_casete_id AND isactive = 1) THEN
        SET error_code = '57010';
        SET error_message = 'Invalid caste code.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate marital status from lookup table
    IF p_marital_status IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_table WHERE category = 'marital_status' AND id = p_marital_status AND isactive = 1) THEN
        SET error_code = '57011';
        SET error_message = 'Invalid marital status code.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country from countries table
    IF p_country IS NOT NULL AND NOT EXISTS (SELECT 1 FROM country WHERE  country_id= p_country) THEN
        SET error_code = '57012';
        SET error_message = 'Invalid country name.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if this profile already has search preferences
    IF EXISTS (
        SELECT 1 
        FROM profile_search_preference 
        WHERE profile_id = p_profile_id
    ) THEN
        SET error_code = '57013';
        SET error_message = 'This profile already has search preferences. Use the update procedure instead.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new search preference record
    INSERT INTO profile_search_preference (
        profile_id,
        min_age,
        max_age,
        gender,
        religion,
        max_education,
        occupation,
        country,
        casete_id,
        marital_status
    ) VALUES (
        p_profile_id,
        p_min_age,
        p_max_age,
        p_gender,
        p_religion,
        p_max_education,
        p_occupation,
        p_country,
        p_casete_id,
        p_marital_status
    );
    
    -- Get the new preference ID
    SET new_preference_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Search preferences created for profile ID: ', p_profile_id), 
        p_created_user, 
        'PROFILE_SEARCH_PREFERENCE_CREATE', 
        CONCAT('Profile ID: ', p_profile_id, 
               ', Preference ID: ', new_preference_id, 
               ', Min Age: ', IFNULL(p_min_age, 'NULL'), 
               ', Max Age: ', IFNULL(p_max_age, 'NULL'), 
               ', Gender: ', IFNULL(p_gender, 'NULL'), 
               ', Religion: ', IFNULL(p_religion, 'NULL'), 
               ', Education: ', IFNULL(p_max_education, 'NULL'), 
               ', Occupation: ', IFNULL(p_occupation, 'NULL'), 
               ', Country: ', IFNULL(p_country, 'NULL'), 
               ', Caste: ', IFNULL(p_casete_id, 'NULL'), 
               ', Marital Status: ', IFNULL(p_marital_status, 'NULL')),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new preference ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_preference_id AS preference_id,
        NULL AS error_code,
        NULL AS error_message;
  
END$$
DELIMITER ;

-- Procedure: eb_profile_search_preference_get
DROP PROCEDURE IF EXISTS `eb_profile_search_preference_get`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_search_preference_get`(
  IN p_profile_id INT)
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
            'ERROR', error_message, p_profile_id, 'PROFILE_SEARCH_PREFERENCE_GET', 
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
            'ERROR', error_message, p_profile_id, 'PROFILE_SEARCH_PREFERENCE_GET', 
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
    
    -- Validation: Ensure at least one of profile_id or preference_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '57009';
        SET error_message = 'Either profile_id must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Query based on the provided parameters
    IF p_profile_id IS NOT NULL THEN
        -- Get specific search preference by ID
        SELECT 
            psp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_search_preference psp
        WHERE psp.profile_id = p_profile_id;
        
    ELSEIF p_profile_id IS NOT NULL THEN
        -- Get search preferences for a profile
        SELECT 
            psp.*,
            'success' AS status,
            NULL AS error_type,
            NULL AS error_code,
            NULL AS error_message
        FROM profile_search_preference psp
        WHERE psp.profile_id = p_profile_id;
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
            WHEN p_profile_id IS NOT NULL THEN CONCAT('Search preferences retrieved for profile ID: ', p_profile_id)
        END, 
        p_profile_id, 
        'PROFILE_SEARCH_PREFERENCE_GET', 
        CASE 
            WHEN p_profile_id IS NOT NULL THEN CONCAT('Profile ID: ', p_profile_id)
        END,
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_views_create
DROP PROCEDURE IF EXISTS `eb_profile_views_create`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_views_create`(
    IN p_from_profile_id INT,
    IN p_to_profile_id INT,
    IN p_account_id INT
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_view_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'PROFILE_VIEWS_CREATE', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_VIEWS_CREATE', 
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
    
    -- Validation: Ensure from_profile_id is valid
    IF p_from_profile_id IS NULL OR p_from_profile_id <= 0 THEN
        SET error_code = '59001';
        SET error_message = 'Invalid from_profile_id. It must be a positive integer.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if from profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_from_profile_id) THEN
        SET error_code = '59002';
        SET error_message = 'From profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate to_profile_id
    IF p_to_profile_id IS NULL OR p_to_profile_id <= 0 THEN
        SET error_code = '59003';
        SET error_message = 'To profile ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate if to profile exists
    IF NOT EXISTS (SELECT 1 FROM profile_personal WHERE profile_id = p_to_profile_id) THEN
        SET error_code = '59004';
        SET error_message = 'To profile does not exist.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate account_id
    IF p_account_id IS NULL OR p_account_id <= 0 THEN
        SET error_code = '59005';
        SET error_message = 'Account ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if profile is trying to view itself (this is allowed, but we'll log it)
    IF p_from_profile_id = p_to_profile_id THEN
        SET error_code = '59006';
        SET error_message = 'A profile is viewing itself.';
        -- We don't signal an error here, just log it
    END IF;
    
    -- Insert the new view record
    INSERT INTO profile_views (
        from_profile_id,
        to_profile_id,
        profile_view_date,
        account_id
    ) VALUES (
        p_from_profile_id,
        p_to_profile_id,
        NOW(), -- profile_view_date is set to current time
        p_account_id
    );
    
    -- Get the new view ID
    SET new_view_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Profile ', p_from_profile_id, ' viewed profile ', p_to_profile_id), 
        CONCAT('Account ID: ', p_account_id), 
        'PROFILE_VIEWS_CREATE', 
        CONCAT('From Profile ID: ', p_from_profile_id, ', To Profile ID: ', p_to_profile_id, ', Account ID: ', p_account_id),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new view ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_view_id AS id,
        NULL AS error_code,
        NULL AS error_message;
   
END$$
DELIMITER ;

-- Procedure: eb_profile_views_get_viewed_by_me
DROP PROCEDURE IF EXISTS `eb_profile_views_get_viewed_by_me`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_views_get_viewed_by_me`(
    IN p_profile_id INT,
    IN p_created_user VARCHAR(100)
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
            'ERROR', error_message, p_created_user, 'PROFILE_VIEWS_GET_VIEWED_BY_ME', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_VIEWS_GET_VIEWED_BY_ME', 
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
    
    -- Validation: Ensure profile_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '59007';
        SET error_message = 'Profile ID must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Get all profiles viewed by this profile with required information
    SELECT 
        pv.profile_view_id,
        pv.from_profile_id,
        pv.to_profile_id,
        pv.profile_view_date,
        pp.first_name,
        pp.last_name,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) AS age,
        lt.name AS country,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message
    FROM profile_views pv
    INNER JOIN profile_personal pp ON pv.to_profile_id = pp.profile_id
    LEFT JOIN profile_address pa ON pp.profile_id = pa.profile_id
    LEFT JOIN lookup_table lt ON pa.country_id = lt.id AND lt.category = 'Country'
    WHERE pv.from_profile_id = p_profile_id
    GROUP BY pv.to_profile_id  -- To avoid duplicate profiles if multiple views or addresses
    ORDER BY pv.profile_view_date DESC;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful read
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ', 
        CONCAT('Profiles viewed by profile ID: ', p_profile_id),
        p_created_user, 
        'PROFILE_VIEWS_GET_VIEWED_BY_ME', 
        CONCAT('Profile ID: ', p_profile_id),
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_profile_views_get_viewed_me
DROP PROCEDURE IF EXISTS `eb_profile_views_get_viewed_me`;

DELIMITER $$
CREATE PROCEDURE `eb_profile_views_get_viewed_me`(
    IN p_profile_id INT,
    IN p_created_user VARCHAR(100)
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
            'ERROR', error_message, p_created_user, 'PROFILE_VIEWS_GET_VIEWED_ME', 
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
            'ERROR', error_message, p_created_user, 'PROFILE_VIEWS_GET_VIEWED_ME', 
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
    
    -- Validation: Ensure profile_id is provided
    IF p_profile_id IS NULL THEN
        SET error_code = '59008';
        SET error_message = 'Profile ID must be provided.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Get all profiles that viewed this profile with required information
    SELECT 
        pv.profile_view_id,
        pv.from_profile_id,
        pv.to_profile_id,
        pv.profile_view_date,
        pp.first_name,
        pp.last_name,
        TIMESTAMPDIFF(YEAR, pp.birth_date, CURDATE()) AS age,
        lt.name AS country,
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message
    FROM profile_views pv
    INNER JOIN profile_personal pp ON pv.from_profile_id = pp.profile_id
    LEFT JOIN profile_address pa ON pp.profile_id = pa.profile_id
    LEFT JOIN lookup_table lt ON pa.country_id = lt.id AND lt.category = 'Country'
    WHERE pv.to_profile_id = p_profile_id
    GROUP BY pv.from_profile_id  -- To avoid duplicate profiles if multiple views or addresses
    ORDER BY pv.profile_view_date DESC;
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful read
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'READ', 
        CONCAT('Profiles that viewed profile ID: ', p_profile_id),
        p_created_user, 
        'PROFILE_VIEWS_GET_VIEWED_ME', 
        CONCAT('Profile ID: ', p_profile_id),
        start_time, end_time, execution_time
    );
    
END$$
DELIMITER ;

-- Procedure: eb_registered_partner_create
DROP PROCEDURE IF EXISTS `eb_registered_partner_create`;

DELIMITER $$
CREATE PROCEDURE `eb_registered_partner_create`(
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
    IN p_domain_root_url VARCHAR(255),
    IN p_created_user VARCHAR(45)
)
BEGIN
    -- Declare variables for error handling
    DECLARE custom_error BOOLEAN DEFAULT FALSE;
    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
    DECLARE new_partner_id INT;
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE execution_time INT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        ROLLBACK;        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', error_message, p_created_user, 'REGISTERED_PARTNER_CREATE', 
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
            'ERROR', error_message, p_created_user, 'REGISTERED_PARTNER_CREATE', 
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
    
    -- Validation: Required fields
    -- Validate business_name
    IF p_business_name IS NULL OR TRIM(p_business_name) = '' THEN
        SET error_code = '48001';
        SET error_message = 'Business name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate alias
    IF p_alias IS NULL OR TRIM(p_alias) = '' THEN
        SET error_code = '48002';
        SET error_message = 'Alias is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate primary_phone
    IF p_primary_phone IS NULL OR TRIM(p_primary_phone) = '' THEN
        SET error_code = '48003';
        SET error_message = 'Primary phone is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate primary_phone_country_code
    IF p_primary_phone_country_code IS NULL OR p_primary_phone_country_code <= 0 THEN
        SET error_code = '48004';
        SET error_message = 'Primary phone country code is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate address_line1
    IF p_address_line1 IS NULL OR TRIM(p_address_line1) = '' THEN
        SET error_code = '48005';
        SET error_message = 'Address line 1 is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate state
    IF p_state IS NULL OR p_state <= 0 THEN
        SET error_code = '48006';
        SET error_message = 'State is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate country
    IF p_country IS NULL OR p_country <= 0 THEN
        SET error_code = '48007';
        SET error_message = 'Country is required and must be valid.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate zip
    IF p_zip IS NULL OR TRIM(p_zip) = '' THEN
        SET error_code = '48008';
        SET error_message = 'ZIP code is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate business_registration_number
    IF p_business_registration_number IS NULL OR TRIM(p_business_registration_number) = '' THEN
        SET error_code = '48009';
        SET error_message = 'Business registration number is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate business_ITIN
    IF p_business_ITIN IS NULL OR TRIM(p_business_ITIN) = '' THEN
        SET error_code = '48010';
        SET error_message = 'Business ITIN is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate business_description
    IF p_business_description IS NULL OR TRIM(p_business_description) = '' THEN
        SET error_code = '48011';
        SET error_message = 'Business description is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate primary_contact_first_name
    IF p_primary_contact_first_name IS NULL OR TRIM(p_primary_contact_first_name) = '' THEN
        SET error_code = '48012';
        SET error_message = 'Primary contact first name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate primary_contact_last_name
    IF p_primary_contact_last_name IS NULL OR TRIM(p_primary_contact_last_name) = '' THEN
        SET error_code = '48013';
        SET error_message = 'Primary contact last name is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Validate business_website
    IF p_business_website IS NULL OR TRIM(p_business_website) = '' THEN
        SET error_code = '48014';
        SET error_message = 'Business website is required.';
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Insert the new registered partner
    INSERT INTO registered_partner (
        business_name,
        alias,
        business_email,
        primary_phone,
        primary_phone_country_code,
        secondary_phone,
        address_line1,
        city,
        state,
        country,
        zip,
        business_registration_number,
        business_ITIN,
        business_description,
        primary_contact_first_name,
        primary_contact_last_name,
        primary_contact_gender,
        primary_contact_date_of_birth,
        primary_contact_email,
        business_linkedin,
        business_website,
        business_facebook,
        business_whatsapp,
        date_created,
        user_created,
        date_modified,
        user_modified,
        isverified,
        Is_active,
        domain_root_url
    ) VALUES (
        p_business_name,
        p_alias,
        p_business_email,
        p_primary_phone,
        p_primary_phone_country_code,
        p_secondary_phone,
        p_address_line1,
        p_city,
        p_state,
        p_country,
        p_zip,
        p_business_registration_number,
        p_business_ITIN,
        p_business_description,
        p_primary_contact_first_name,
        p_primary_contact_last_name,
        p_primary_contact_gender,
        p_primary_contact_date_of_birth,
        p_primary_contact_email,
        p_business_linkedin,
        p_business_website,
        p_business_facebook,
        p_business_whatsapp,
        NOW(),
        p_created_user,
        NOW(),
        p_created_user,
        0, -- Not verified by default
        b'0', -- Not active by default
        p_domain_root_url
    );
    
    -- Get the new partner ID
    SET new_partner_id = LAST_INSERT_ID();
    
    -- Record end time and calculate execution time
    SET end_time = NOW();
    SET execution_time = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000; -- Convert to milliseconds
    
    -- Log the successful creation
    INSERT INTO activity_log (
        log_type, message, created_by, activity_type, activity_details,
        start_time, end_time, execution_time
    ) VALUES (
        'CREATE', 
        CONCAT('Registered partner created with ID: ', new_partner_id), 
        p_created_user, 
        'REGISTERED_PARTNER_CREATE', 
        CONCAT('Business Name: ', p_business_name),
        start_time, end_time, execution_time
    );
    
    -- Commit the transaction
    COMMIT;
    
    -- Return success with the new partner ID
    SELECT 
        'success' AS status,
        NULL AS error_type,
        new_partner_id AS reg_partner_id,
        NULL AS error_code,
        NULL AS error_message;
    
END$$
DELIMITER ;

-- Procedure: eb_registered_partner_get
DROP PROCEDURE IF EXISTS `eb_registered_partner_get`;

DELIMITER $$
CREATE PROCEDURE `eb_registered_partner_get`(
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
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = error_message;
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
    
END$$
DELIMITER ;

-- Procedure: eb_reset_password
DROP PROCEDURE IF EXISTS `eb_reset_password`;

DELIMITER $$
CREATE PROCEDURE `eb_reset_password`(
   IN email VARCHAR(45),
    IN current_password VARCHAR(45),
    IN new_password VARCHAR(45)
)
BEGIN

    DECLARE existing_password VARCHAR(45);
    DECLARE v_account_id INT;
    SET SQL_SAFE_UPDATES = 0;

    -- Retrieve the account_id and existing password for the given email
    SELECT a.account_id, l.password 
    INTO v_account_id, existing_password
    FROM account a
    JOIN login l ON a.account_id = l.account_id
    WHERE a.email = email
    LIMIT 1;  -- Ensure only one row is selected

    -- Check if the email exists
    IF v_account_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '45001_Email not found.';
    END IF;

    -- Check if the current password matches the existing password
    IF existing_password != current_password THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '45002_Current password is incorrect.';
    END IF;

    -- Start transaction
    START TRANSACTION;

    -- Update password in the login information
    UPDATE login
    SET password = new_password
    WHERE account_id = v_account_id;  -- Reference the variable correctly

    -- Commit transaction
    COMMIT;

    -- Return success message
    SELECT 'Account password updated successfully.' AS message;
END$$
DELIMITER ;

-- Procedure: eb_update_new_password
DROP PROCEDURE IF EXISTS `eb_update_new_password`;

DELIMITER $$
CREATE PROCEDURE `eb_update_new_password`(
   IN email VARCHAR(45),
   IN new_password VARCHAR(45)
)
BEGIN
    DECLARE existing_password VARCHAR(45);
    DECLARE v_account_id INT;
    SET SQL_SAFE_UPDATES = 0;

			-- Retrieve the account_id and existing password for the given email
			SELECT a.account_id, l.password 
			INTO v_account_id, existing_password
			FROM account a
			JOIN login l ON a.account_id = l.account_id
			WHERE a.email = email
			LIMIT 1;  -- Ensure only one row is selected

			-- Check if the email exists
			IF v_account_id IS NULL THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email not found.';
			END IF;
			-- Start transaction
			START TRANSACTION;
			-- Update password in the login information
			UPDATE login
			SET password = new_password
			WHERE account_id = v_account_id;  -- Reference the variable correctly
			-- Commit transaction
			COMMIT;
			-- Return success message
			SELECT 
				'success' AS status,
				'Account password updated successfully.' AS message,
				null AS error_code,
                null AS error_message;

END$$
DELIMITER ;

-- Procedure: eb_update_new_password_forgot_password
DROP PROCEDURE IF EXISTS `eb_update_new_password_forgot_password`;

DELIMITER $$
CREATE PROCEDURE `eb_update_new_password_forgot_password`(
   IN email VARCHAR(45),
   IN new_password VARCHAR(45)
)
BEGIN
    DECLARE existing_password VARCHAR(45);
    DECLARE v_account_id INT;
    SET SQL_SAFE_UPDATES = 0;

			-- Retrieve the account_id and existing password for the given email
			SELECT a.account_id, l.password 
			INTO v_account_id, existing_password
			FROM account a
			JOIN login l ON a.account_id = l.account_id
			WHERE a.email = email
			LIMIT 1;  -- Ensure only one row is selected

			-- Check if the email exists
			IF v_account_id IS NULL THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email not found.';
			END IF;
			-- Start transaction
			START TRANSACTION;
			-- Update password in the login information
			UPDATE login
			SET password = new_password
			WHERE account_id = v_account_id;  -- Reference the variable correctly
			-- Commit transaction
			COMMIT;
			-- Return success message
			SELECT 
				'success' AS status,
				'Account password updated successfully.' AS message,
				null AS error_code,
                null AS error_message;

END$$
DELIMITER ;

-- Procedure: eb_validate_email_otp
DROP PROCEDURE IF EXISTS `eb_validate_email_otp`;

DELIMITER $$
CREATE PROCEDURE `eb_validate_email_otp`(IN email VARCHAR(150), IN user_otp INT)
BEGIN
    -- validate email OTP 
    IF EXISTS (SELECT * FROM login_history 
		WHERE 
			login_name = email AND
			email_otp = user_otp AND 
            email_otp_valid_end > NOW()) THEN
        SELECT 
			'Success' AS status,
            'OTP Verified successfully' as message,
            email,
            account_id,
            account_code
		FROM account a
        WHERE a.email = email    ;
    ELSE
        SELECT 
			'Fail' AS status,
			'Either Invalid or Expired OTP presented' as message,
            null AS email,
            null AS account_id,
            null AS account_code 
		FROM DUAL;
    END IF;
END$$
DELIMITER ;

-- Procedure: eb_validate_mail_and_generate_OTP
DROP PROCEDURE IF EXISTS `eb_validate_mail_and_generate_OTP`;

DELIMITER $$
CREATE PROCEDURE `eb_validate_mail_and_generate_OTP`(
    IN email VARCHAR(150), 
    IN ip VARCHAR(20), 
    IN sysname VARCHAR(45) , 
    IN usragent VARCHAR(45), 
    IN location VARCHAR(45))
BEGIN
    DECLARE id_login INT;
    DECLARE email_otp INT;
    DECLARE start_date DATETIME;

    -- Check if the email exists in the login table 
    IF EXISTS (
        SELECT 1 FROM account 
        WHERE email = email and is_active = 1) THEN

        -- Generate email OTP 
        SET email_otp = FLOOR(1000 + RAND() * 9000);
        SET start_date = NOW();

        -- Get Login ID (use LIMIT 1 to ensure only one row is selected)
        SELECT login_id INTO id_login 
        FROM login 
        WHERE email = email and is_active = 1
        LIMIT 1;

        -- Insert into login_history table
        INSERT INTO login_history(
            login_name,
            login_date, 
            login_status, 
            email_otp, 
            ip_address,
            system_name,
            user_agent,
            location,
            login_id_on_success,
            email_otp_valid_start,
            email_otp_valid_end)
        VALUES(
            email,
            NOW(), 
            1,
            email_otp,
            ip, 
            sysname, 
            usragent,
            location,
            id_login,
            start_date,
            DATE_ADD(start_date, INTERVAL 2 MINUTE));

        -- Return the OTP
        SELECT 
			null as error_code, 
			null as error_message, 
			email_otp AS otp
        FROM dual;

    ELSE 
        INSERT INTO login_history(
            login_name,
            login_date, 
            login_status, 
            email_otp, 
            ip_address,
            system_name,
            user_agent,
            location)
        VALUES(
            email,
            NOW(), 
            0,
            -1,
            ip, 
            sysname, 
            usragent,
            location);
        -- Return -1 if the email is invalid
        SELECT 
			'45008_INVALID_EMAIL' as error_code, 
			'Either Email does not exist or NOT active.' as error_message, 
            null AS otp;
    END IF;
END$$
DELIMITER ;

-- Procedure: get_accountDetails
DROP PROCEDURE IF EXISTS `get_accountDetails`;

DELIMITER $$
CREATE PROCEDURE `get_accountDetails`(IN email_id VARCHAR(150))
BEGIN

    DECLARE error_code VARCHAR(100) DEFAULT NULL;
    DECLARE error_message VARCHAR(255) DEFAULT NULL;
	SET error_code = '45015_EMAIL_DOES_NOT_EXIST';
    SET error_message = 'Email doesn\'t exists';

	
	IF EXISTS(	SELECT * FROM account WHERE email = email_id) THEN
		SELECT 
				`account`.`account_code`,
                `account`.`account_id`,
				`account`.`email`,
				`account`.`primary_phone`,
				`account`.`primary_phone_country`,
				`account`.`primary_phone_type`,
				`account`.`secondary_phone`,
				`account`.`secondary_phone_country`,
				`account`.`secondary_phone_type`,
				`account`.`first_name`,
				`account`.`last_name`,
				`account`.`middle_name`,
				`account`.`birth_date`,
				`account`.`gender`,
				`account`.`address_line1`,
				`account`.`address_line2`,
				`account`.`city`,
				`account`.`state`,
				`account`.`zip`,
				`account`.`country`,
				`account`.`photo`,
				`account`.`secret_question`,
				`account`.`secret_answer`,
				`account`.`created_date`,
				`account`.`created_user`,
				`account`.`modified_date`,
				`account`.`modified_user`,
				`account`.`is_active`,
				`account`.`activation_date`,
				`account`.`activated_user`,
				`account`.`deactivated_date`,
				`account`.`deactivated_user`,
				`account`.`deactivation_reason`,
				`account`.`is_deleted`,
				`account`.`deleted_date`,
				`account`.`deleted_user`,
				`account`.`deleted_reason`
			FROM `matrimony_services`.`account`
			WHERE email = email_id;        
	ELSE
		SELECT error_code AS error_code, error_message AS error_message;		
    END IF;
END$$
DELIMITER ;

-- Procedure: lkp_get_Country_List
DROP PROCEDURE IF EXISTS `lkp_get_Country_List`;

DELIMITER $$
CREATE PROCEDURE `lkp_get_Country_List`()
BEGIN

	SELECT * FROM country
    WHERE country_name in ('India', 'United States','Canada','United Kingdom','Australia');

END$$
DELIMITER ;

-- Procedure: lkp_get_Country_States
DROP PROCEDURE IF EXISTS `lkp_get_Country_States`;

DELIMITER $$
CREATE PROCEDURE `lkp_get_Country_States`(IN countryID INT)
BEGIN
	IF countryID IS NOT NULL THEN
		SELECT * FROM state
		WHERE country_id = countryID;
    ELSE
		SELECT * FROM state;
    END IF;
END$$
DELIMITER ;

-- Procedure: lkp_get_LookupData
DROP PROCEDURE IF EXISTS `lkp_get_LookupData`;

DELIMITER $$
CREATE PROCEDURE `lkp_get_LookupData`(IN m_category VARCHAR(100))
BEGIN
	
    IF (m_category IS NOT  NULL)  THEN
		SELECT id, name, description, category
		FROM lookup_table
		WHERE category = m_category AND isactive = 1;
	ELSE
		SELECT id, name, description, category
		FROM lookup_table
		WHERE isactive = 1;    
    END IF;
END$$
DELIMITER ;

-- Procedure: sampledata_create_full_account
DROP PROCEDURE IF EXISTS `sampledata_create_full_account`;

DELIMITER $$
CREATE PROCEDURE `sampledata_create_full_account`(
    -- Account and Login Parameters
    IN p_email VARCHAR(150),
    IN p_user_pwd VARCHAR(150),
    IN p_first_name VARCHAR(45),
    IN p_middle_name VARCHAR(45),
    IN p_last_name VARCHAR(45),
    IN p_birth_date DATE,
    IN p_gender INT,
    IN p_primary_phone VARCHAR(10),
    IN p_primary_phone_country VARCHAR(5),
    IN p_primary_phone_type INT,
    IN p_secondary_phone VARCHAR(10),
    IN p_secondary_phone_country VARCHAR(5),
    IN p_secondary_phone_type INT,
    IN p_secret_question VARCHAR(45),
    IN p_secret_answer VARCHAR(45),

    -- Profile Personal Parameters
    IN p_prefix VARCHAR(45),
    IN p_suffix VARCHAR(45),
    IN p_marital_status INT,
    IN p_religion INT,
    IN p_nationality INT,
    IN p_caste INT,
    IN p_height_inches INT,
    IN p_height_cms INT,
    IN p_weight INT,
    IN p_weight_units VARCHAR(4),
    IN p_complexion INT,
    IN p_linkedin VARCHAR(450),
    IN p_facebook VARCHAR(450),
    IN p_instagram VARCHAR(450),
    IN p_whatsapp_number VARCHAR(15),
    IN p_profession INT,
    IN p_disability INT,

    -- Profile Address Parameters
    IN p_address_line1 VARCHAR(45),
    IN p_address_line2 VARCHAR(45),
    IN p_city VARCHAR(45),
    IN p_state VARCHAR(45),
    IN p_zip VARCHAR(45),
    IN p_country VARCHAR(45),
    IN p_address_type INT,

    -- Profile Contact Parameters
    IN p_contact_name VARCHAR(100),
    IN p_contact_relationship VARCHAR(50),
    IN p_contact_phone VARCHAR(15),

    -- Profile Education Parameters
    IN p_degree VARCHAR(100),
    IN p_institution VARCHAR(100),
    IN p_year_of_completion INT,

    -- Profile Employment Parameters
    IN p_company_name VARCHAR(100),
    IN p_job_title VARCHAR(100),
    IN p_start_date DATE,
    IN p_end_date DATE,

    -- Profile Family Reference Parameters
    IN p_ref_name VARCHAR(100),
    IN p_ref_relationship VARCHAR(50),
    IN p_ref_phone VARCHAR(15),

    -- Profile Hobby/Interest Parameters
    IN p_hobby_name VARCHAR(100),

    -- Profile Lifestyle Parameters
    IN p_diet_preference INT,
    IN p_smoking_habit INT,
    IN p_drinking_habit INT,

    -- Profile Property Parameters
    IN p_property_type INT,
    IN p_property_value DECIMAL(18, 2),

    -- Profile Photo Parameters
    IN p_photo_path VARCHAR(255),
    IN p_is_profile_photo TINYINT
)
BEGIN
    DECLARE new_account_id INT;
    DECLARE error_occurred BOOLEAN DEFAULT FALSE;

    -- Error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET error_occurred = TRUE;
        SELECT 'fail' AS status, 'An error occurred during account creation.' AS message;
    END;

    START TRANSACTION;

    -- 1. Create Account and Login
    CALL eb_account_login_create(
        p_email, p_user_pwd, p_first_name, p_middle_name, p_last_name, p_birth_date, p_gender,
        p_primary_phone, p_primary_phone_country, p_primary_phone_type,
        p_secondary_phone, p_secondary_phone_country, p_secondary_phone_type,
        p_address_line1, p_address_line2, p_city, p_state, p_zip, p_country,
        p_photo_path, p_secret_question, p_secret_answer
    );

    -- Get the new account ID
    SELECT account_id INTO new_account_id FROM account WHERE email = p_email;

    -- 2. Enable the Account
    CALL eb_enable_disable_account(new_account_id, 1, 'New account activation');

    -- 3. Create Profile Personal
    CALL eb_profile_personal_create(
        new_account_id, p_first_name, p_last_name, p_middle_name, p_prefix, p_suffix, p_gender,
        p_birth_date, p_primary_phone, NULL, NULL, p_email, p_marital_status, p_religion, p_nationality,
        p_caste, p_height_inches, p_height_cms, p_weight, p_weight_units, p_complexion, p_linkedin,
        p_facebook, p_instagram, p_whatsapp_number, p_profession, p_disability, p_email
    );

    -- 4. Create other profile entries
    CALL eb_profile_address_create(new_account_id, p_address_type, p_address_line1, p_address_line2, p_city, p_state, p_zip, p_country, p_email);
    CALL eb_profile_contact_create(new_account_id, p_contact_name, p_contact_relationship, p_contact_phone, p_email);
    CALL eb_profile_education_create(new_account_id, p_degree, p_institution, p_year_of_completion, p_email);
    CALL eb_profile_employment_create(new_account_id, p_company_name, p_job_title, p_start_date, p_end_date, p_email);
    CALL eb_profile_family_reference_create(new_account_id, p_ref_name, p_ref_relationship, p_ref_phone, p_email);
    CALL eb_profile_hobby_interest_create(new_account_id, p_hobby_name, p_email);
    CALL eb_profile_lifestyle_create(new_account_id, p_diet_preference, p_smoking_habit, p_drinking_habit, p_email);
    CALL eb_profile_property_create(new_account_id, p_property_type, p_property_value, p_email);
    CALL eb_profile_photo_create(new_account_id, p_photo_path, p_is_profile_photo, p_email);

    IF NOT error_occurred THEN
        COMMIT;
        SELECT 'success' AS status, 'Account created successfully.' AS message, new_account_id AS account_id;
    END IF;

END$$
DELIMITER ;

-- Procedure: sampledata_generate_complete_profile
DROP PROCEDURE IF EXISTS `sampledata_generate_complete_profile`;

DELIMITER $$
CREATE PROCEDURE `sampledata_generate_complete_profile`()
BEGIN
    -- Declare variables for account creation
    DECLARE v_created_account_id INT;
    DECLARE v_profile_id INT;
    DECLARE v_status VARCHAR(50);
    DECLARE v_error_message VARCHAR(255);
    DECLARE v_photo_id INT;
    DECLARE v_contact_id INT;
    DECLARE v_education_id INT;
    DECLARE v_employment_id INT;
    DECLARE v_family_ref_id INT;
    DECLARE v_hobby_id INT;
    DECLARE v_interest_id INT;
    DECLARE v_lifestyle_id INT;
    DECLARE v_address_id INT;
    DECLARE v_property_id INT;
	DECLARE v_property_type_id INT;
	DECLARE v_ownership_type_id INT;    
    -- Variables for lookup values
    DECLARE v_gender_id INT;
    DECLARE v_marital_status_id INT;
    DECLARE v_religion_id INT;
    DECLARE v_profession_id INT;
    DECLARE v_photo_type_id INT;
    DECLARE v_contact_type_id INT;
    DECLARE v_education_level_id INT;
    DECLARE v_field_of_study_id INT;
    DECLARE v_family_relation_id INT;
    DECLARE v_hobby_id_lookup INT;
    DECLARE v_interest_id_lookup INT;
    DECLARE v_address_type_id INT;
    
    -- First, create the account and login
    CALL sampledata_generate_sample_account();
    
    -- Get the ID of the newly created account using LAST_INSERT_ID()
    SELECT LAST_INSERT_ID() INTO v_created_account_id
    FROM account LIMIT 1;
    
    -- If account creation was successful, proceed with profile data insertion
    IF v_created_account_id IS NOT NULL THEN
        -- Get lookup values
        SELECT id INTO v_gender_id FROM lookup_table WHERE category = 'Gender' ORDER BY RAND() LIMIT 1;
        SELECT id INTO v_marital_status_id FROM lookup_table WHERE category = 'marital_status' ORDER BY RAND() LIMIT 1;
        SELECT id INTO v_religion_id FROM lookup_table WHERE category = 'religion' ORDER BY RAND() LIMIT 1;
        SELECT id INTO v_profession_id FROM lookup_table WHERE category = 'profession' ORDER BY RAND() LIMIT 1;
        
        -- 1. Insert personal profile data
        CALL eb_profile_personal_create(
            v_created_account_id,                                -- accountid
            CONCAT('First_', v_created_account_id),              -- first_name
            CONCAT('Last_', v_created_account_id),               -- last_name
            'Middle',                                            -- middle_name
            'Mr',                                                -- prefix
            NULL,                                                -- suffix
            v_gender_id,                                         -- gender
            DATE_SUB(CURDATE(), INTERVAL 25 YEAR),               -- birth_date
            CONCAT('555', LPAD(v_created_account_id, 7, '0')),   -- phone_mobile
            CONCAT('444', LPAD(v_created_account_id, 7, '0')),   -- phone_home
            CONCAT('333', LPAD(v_created_account_id, 7, '0')),   -- phone_emergency
            CONCAT('user', v_created_account_id, '@example.com'),-- email_id
            v_marital_status_id,                                 -- marital_status
            v_religion_id,                                       -- religion
            1,                                                   -- nationality (assuming 1 is valid)
            NULL,                                                -- caste
            70,                                                  -- height_inches
            178,                                                 -- height_cms
            180,                                                 -- weight
            'lbs',                                               -- weight_units
            NULL,                                                -- complexion
            CONCAT('linkedin.com/in/user', v_created_account_id),-- linkedin
            CONCAT('facebook.com/user', v_created_account_id),   -- facebook
            CONCAT('instagram.com/user', v_created_account_id),  -- instagram
            CONCAT('555', LPAD(v_created_account_id, 7, '0')),   -- whatsapp_number
            v_profession_id,                                     -- profession
            NULL,                                                -- disability
            'system'                                             -- created_user
        );
        
        -- Get the profile ID from the newly created personal profile
        SELECT LAST_INSERT_ID() INTO v_profile_id 
        FROM profile_personal limit 1;
        
        -- If profile creation was successful, continue with other profile data
        IF v_profile_id IS NOT NULL THEN
            -- 2. Insert profile photo
            SELECT id INTO v_photo_type_id FROM lookup_table WHERE category = 'photo_type' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_photo_create(
                v_profile_id,                                     -- p_profile_id
                CONCAT('/photos/user_', v_profile_id, '.jpg'),    -- p_photo_url
                v_photo_type_id,                                  -- p_photo_type
                'Head shot',                                                -- p_caption
                'head shot',                                         -- p_description
                'test'											-- user
            );
            
            -- 3. Insert profile contact
            SELECT id INTO v_contact_type_id FROM lookup_table WHERE category = 'contact_type' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_contact_create(
                v_profile_id,                                     -- p_profile_id
                v_contact_type_id,                                -- p_contact_type
                CONCAT('contact_value_', v_profile_id),           -- p_contact_value
                'system'                                          -- p_created_user
            );
            
            -- 4. Insert profile education
            SELECT id INTO v_education_level_id FROM lookup_table WHERE category = 'education_level' ORDER BY RAND() LIMIT 1;
            SELECT id INTO v_field_of_study_id FROM lookup_table WHERE category = 'field_of_study' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_education_create(
                v_profile_id,                                     -- p_profile_id
                v_education_level_id,                             -- p_education_level
                YEAR(CURDATE()) - 5,                              -- p_year_completed
                CONCAT('University of ', CHAR(65 + FLOOR(RAND() * 26))), -- p_institution_name
                CONCAT(FLOOR(100 + RAND() * 9900), ' Campus Dr'), -- p_address_line1
                'University City',                                -- p_city
                1,                                                -- p_state_id (assuming 1 is valid)
                1,                                                -- p_country_id (assuming 1 is valid)
                '12345',                                          -- p_zip
                v_field_of_study_id,                              -- p_field_of_study
                'system'                                          -- p_created_user
            );
            
            -- 5. Insert profile employment
            CALL eb_profile_employment_create(
                v_profile_id,                                     -- p_profile_id
                CONCAT('Company ', CHAR(65 + FLOOR(RAND() * 26))),-- p_institution_name
                CONCAT(FLOOR(100 + RAND() * 9900), ' Business Rd'),-- p_address_line1
                'Business City',                                  -- p_city
                1,                                                -- p_state_id
                1,                                                -- p_country_id
                '54321',                                          -- p_zip
                YEAR(CURDATE()) - 3,                              -- p_start_year
                NULL,                                             -- p_end_year
                v_profession_id,                                  -- p_job_title_id
                NULL,                                             -- p_other_title
                FLOOR(50000 + RAND() * 50000),                    -- p_last_salary_drawn
                'system'                                          -- p_created_user
            );
            
            -- 6. Insert family reference
            SELECT id INTO v_family_relation_id FROM lookup_table WHERE category = 'Family' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_family_reference_create(
                v_profile_id,                                     -- p_profile_id
                CONCAT('Family_First_', v_profile_id),            -- p_first_name
                CONCAT('Family_Last_', v_profile_id),             -- p_last_name
                v_family_relation_id,                             -- p_reference_type
                CONCAT('555', LPAD(FLOOR(RAND() * 10000000), 7, '0')), -- p_primary_phone
                CONCAT('family', v_profile_id, '@example.com'),   -- p_email
                CONCAT(FLOOR(100 + RAND() * 9900), ' Family St'), -- p_address_line1
                'Family City',                                    -- p_city
                1,                                                -- p_state
                1,                                                -- p_country
                '54321',                                          -- p_zip
                'system'                                          -- p_created_user
            );
            
            -- 7. Insert hobby and interest
            SELECT id INTO v_hobby_id_lookup FROM lookup_table WHERE category = 'hobby' ORDER BY RAND() LIMIT 1;
            SELECT id INTO v_interest_id_lookup FROM lookup_table WHERE category = 'interest' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_hobby_interest_create(
                v_profile_id,                                     -- p_profile_id
                v_hobby_id_lookup,                                -- p_hobby_id
                'system'                                          -- p_created_user
            );
            
            -- 8. Insert lifestyle
            CALL eb_profile_lifestyle_create(
                v_profile_id,                                     -- p_profile_id
                CONCAT('Eating_', CHAR(65 + FLOOR(RAND() * 26))), -- p_eating_habit
                CONCAT('Diet_', CHAR(65 + FLOOR(RAND() * 26))),   -- p_diet_habit
                CONCAT(FLOOR(RAND() * 20), ' per day'),           -- p_cigarettes_per_day
                CONCAT('Drinks_', CHAR(65 + FLOOR(RAND() * 26))), -- p_drink_frequency
                CONCAT('Gambling_', CHAR(65 + FLOOR(RAND() * 26))), -- p_gambling_engage
                CONCAT('Activity_', CHAR(65 + FLOOR(RAND() * 26))), -- p_physical_activity_level
                CONCAT('Relaxation_', CHAR(65 + FLOOR(RAND() * 26))), -- p_relaxation_methods
                'Additional lifestyle information',               -- p_additional_info
                'system'                                          -- p_created_user
            );
            
            
            -- 9. Insert address
            SELECT id INTO v_address_type_id FROM lookup_table WHERE category = 'address_type' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_address_create(
                v_profile_id,                                     -- p_profile_id
                v_address_type_id,                                -- p_address_type
                CONCAT(FLOOR(100 + RAND() * 9900), ' Residential St'), -- p_address_line1
                CONCAT('Apt ', FLOOR(1 + RAND() * 500)),          -- p_address_line2
                'Hometown',                                       -- p_city
                1,                                                -- p_state (assuming 1 is valid)
                1,                                                -- p_country_id (assuming 1 is valid)
                '98765',                                          -- p_zip
                'Near Park',                                      -- p_landmark1
                'Opposite Mall',                                  -- p_landmark2
                'system'                                          -- p_created_user
            );
            
            

            -- 10. Insert property  
            SELECT id INTO v_property_type_id FROM lookup_table WHERE category = 'property_type' ORDER BY RAND() LIMIT 1;
            SELECT id INTO v_ownership_type_id FROM lookup_table WHERE category = 'ownership_type' ORDER BY RAND() LIMIT 1;
            
            CALL eb_profile_property_create(
                v_profile_id,                                     -- p_profile_id
                v_property_type_id,                               -- p_property_type (assuming 1 is valid)
                v_ownership_type_id,                              -- p_ownership_type (assuming 1 is valid)
                CONCAT(FLOOR(100 + RAND() * 9900), ' Property St, Property City, 45678'), -- p_property_address
                FLOOR(1000 + RAND() * 9000),                      -- p_property_value
                'Beautiful property with modern amenities',        -- p_property_description
                1,                                                -- p_isoktodisclose (1 = true)
                'system'                                          -- p_created_by
            );
            
            -- Return success message with all created IDs
            SELECT 
                v_created_account_id AS account_id, 
                v_profile_id AS profile_id,
                'Complete profile created successfully' AS message;
        ELSE
            -- Return error if profile creation failed
            SELECT v_created_account_id AS account_id, NULL AS profile_id, 'Failed to create profile' AS message;
        END IF;
    ELSE
        -- Return error if account creation failed
        SELECT NULL AS account_id, NULL AS profile_id, 'Failed to create account' AS message;
    END IF;
END$$
DELIMITER ;

-- Procedure: sampledata_generate_sample_account
DROP PROCEDURE IF EXISTS `sampledata_generate_sample_account`;

DELIMITER $$
CREATE PROCEDURE `sampledata_generate_sample_account`()
BEGIN
    -- Declare variables for account_login_create procedure parameters
    DECLARE v_email VARCHAR(150);
    DECLARE v_user_pwd VARCHAR(150);
    DECLARE v_first_name VARCHAR(45);
    DECLARE v_middle_name VARCHAR(45);
    DECLARE v_last_name VARCHAR(45);
    DECLARE v_birth_date DATE;
    DECLARE v_gender INT;
    DECLARE v_primary_phone VARCHAR(10);
    DECLARE v_primary_phone_country VARCHAR(5);
    DECLARE v_primary_phone_type INT;
    DECLARE v_secondary_phone VARCHAR(10);
    DECLARE v_secondary_phone_country VARCHAR(5);
    DECLARE v_secondary_phone_type INT;
    DECLARE v_address_line1 VARCHAR(45);
    DECLARE v_address_line2 VARCHAR(45);
    DECLARE v_city VARCHAR(45);
    DECLARE v_state VARCHAR(45);
    DECLARE v_zip VARCHAR(45);
    DECLARE v_country VARCHAR(45);
    DECLARE v_photo VARCHAR(45);
    DECLARE v_secret_question VARCHAR(45);
    DECLARE v_secret_answer VARCHAR(45);
    DECLARE v_country_id INT;
    DECLARE v_created_account_id INT;
    DECLARE v_status VARCHAR(50);
    
    -- Generate random data for account_login_create procedure
    SET v_first_name = ELT(FLOOR(1 + RAND() * 10), 'John', 'Jane', 'Peter', 'Mary', 'David', 'Sarah', 'Michael', 'Emily', 'Robert', 'Lisa');
    SET v_last_name = ELT(FLOOR(1 + RAND() * 10), 'Smith', 'Jones', 'Williams', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor', 'Anderson');
    SET v_email = CONCAT(LOWER(v_first_name), '.', LOWER(v_last_name), '_', FLOOR(RAND() * 10000), '@example.com');
    SET v_user_pwd = CONCAT('Pass', FLOOR(1000 + RAND() * 9000));
    SET v_middle_name = ELT(FLOOR(1 + RAND() * 5), 'A', 'B', 'C', 'D', 'E');
    
    -- Generate birth date between 20 and 60 years ago
    SET v_birth_date = DATE_SUB(CURDATE(), INTERVAL (20 + FLOOR(RAND() * 40)) YEAR);
    
    -- Get random gender from lookup table
    SELECT id INTO v_gender FROM lookup_table WHERE category = 'Gender' ORDER BY RAND() LIMIT 1;
    
    -- Generate random phone numbers
    SET v_primary_phone = LPAD(FLOOR(RAND() * 10000000000), 10, '0');
    SET v_primary_phone_country = '+1';
    SELECT id INTO v_primary_phone_type FROM lookup_table WHERE category = 'phone_type' ORDER BY RAND() LIMIT 1;
    
    -- Secondary phone is optional, 30% chance of being NULL
    IF RAND() > 0.3 THEN
        SET v_secondary_phone = LPAD(FLOOR(RAND() * 10000000000), 10, '0');
        SET v_secondary_phone_country = '+1';
        SELECT id INTO v_secondary_phone_type FROM lookup_table WHERE category = 'phone_type' ORDER BY RAND() LIMIT 1;
    ELSE
        SET v_secondary_phone = NULL;
        SET v_secondary_phone_country = NULL;
        SET v_secondary_phone_type = NULL;
    END IF;
    
    -- Generate random address
    SET v_address_line1 = CONCAT(FLOOR(100 + RAND() * 9900), ' ', 
                               ELT(FLOOR(1 + RAND() * 5), 'Main St', 'Oak Ave', 'Maple Rd', 'Washington Blvd', 'Park Lane'));
    
    -- Address line 2 is optional, 50% chance of being NULL
    IF RAND() > 0.5 THEN
        SET v_address_line2 = CONCAT('Apt ', FLOOR(1 + RAND() * 500));
    ELSE
        SET v_address_line2 = NULL;
    END IF;
    
    -- Generate random city, zip
    SET v_city = ELT(FLOOR(1 + RAND() * 10), 'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 
                    'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose');
    SET v_zip = LPAD(FLOOR(RAND() * 100000), 5, '0');
    
     -- Select a random country from the countries table
    SELECT country_id, country_name INTO v_country_id, v_country 
    FROM country 
    WHERE is_active = TRUE and country_id = 1
    ORDER BY RAND() 
    LIMIT 1;
    
    -- Select a random state from the state table that matches the selected country
    SELECT state_id INTO v_state 
    FROM state 
    WHERE country_id = 1 AND is_active = TRUE 
    ORDER BY RAND() 
    LIMIT 1;    
    -- Photo is optional, 70% chance of having one
    IF RAND() > 0.3 THEN
        SET v_photo = CONCAT('/photos/user_', FLOOR(RAND() * 1000), '.jpg');
    ELSE
        SET v_photo = NULL;
    END IF;
    
    -- Generate security question and answer
    SET v_secret_question = ELT(FLOOR(1 + RAND() * 5), 
                              'What is your favorite color?', 
                              'What was your first pet\'s name?', 
                              'What city were you born in?', 
                              'What is your mother\'s maiden name?', 
                              'What was your first car?');
    
    SET v_secret_answer = ELT(FLOOR(1 + RAND() * 5), 'Blue', 'Fluffy', 'Chicago', 'Smith', 'Toyota');
    
    
    -- Call the account_login_create procedure with generated data
    CALL eb_account_login_create(
        v_email, 
        v_user_pwd, 
        v_first_name, 
        v_middle_name, 
        v_last_name, 
        v_birth_date, 
        v_gender,
        v_primary_phone, 
        v_primary_phone_country, 
        v_primary_phone_type,
        v_secondary_phone, 
        v_secondary_phone_country, 
        v_secondary_phone_type,
        v_address_line1, 
        v_address_line2, 
        v_city, 
        v_state, 
        v_zip, 
        v_country,
        v_photo, 
        v_secret_question, 
        v_secret_answer
    );
    
    -- Get the ID of the newly created account
    SELECT LAST_INSERT_ID() INTO v_created_account_id
    FROM account limit 1;
    
    -- If account creation was successful, enable the account
    IF v_created_account_id IS NOT NULL THEN
        -- Enable the account (set is_active to 1)
        CALL eb_enable_disable_account(
            v_created_account_id,  -- account ID
            1,                     -- is_active (1 = enable)
            'Account enabled during sample data generation',  -- reason
            'test user'
        );
        
        -- Return the account ID
        SELECT v_created_account_id AS account_id, 'Account created and enabled successfully' AS message;
    ELSE
        -- Return error if account creation failed
        SELECT NULL AS account_id, 'Failed to create account' AS message;
    END IF;
END$$
DELIMITER ;

-- Procedure: test_diagnostics
DROP PROCEDURE IF EXISTS `test_diagnostics`;

DELIMITER $$
CREATE PROCEDURE `test_diagnostics`()
BEGIN
    DECLARE error_message VARCHAR(255);
    DECLARE error_code VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;

        SELECT error_code, error_message;
    END;

    -- Force an error
    SELECT nonexistent_column FROM nonexistent_table;
END$$
DELIMITER ;

-- Procedure: test_null_exception
DROP PROCEDURE IF EXISTS `test_null_exception`;

DELIMITER $$
CREATE PROCEDURE `test_null_exception`()
BEGIN
    DECLARE error_message VARCHAR(255);
    DECLARE error_code VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT,
            error_code = MYSQL_ERRNO;
        SELECT 'Handler triggered', error_code, error_message;
    END;

    -- This will throw error 1048
    INSERT INTO test (name) VALUES (NULL);
END$$
DELIMITER ;

