DELIMITER //
DROP PROCEDURE IF EXISTS admin_api_clients_create_v1;
CREATE PROCEDURE `admin_api_clients_create_v1`(
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
    DECLARE v_partner_name VARCHAR(255);
    DECLARE v_partner_exists INT DEFAULT 0;    
    -- Generate random PIN (4-6 digits)
    DECLARE v_partner_pin INT;
    -- Generate api_key
    DECLARE p_api_key VARCHAR(64);
    DECLARE v_mysql_errno INT;
    DECLARE v_message_text TEXT;
    
    -- Declare handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_message_text = MESSAGE_TEXT,
            v_mysql_errno = MYSQL_ERRNO;
        
        ROLLBACK;
        
        -- Log error to activity_log
        INSERT INTO activity_log (
            log_type, message, created_by, activity_type, activity_details,
            start_time, end_time, execution_time
        ) VALUES (
            'ERROR', COALESCE(v_message_text, 'Unknown SQL error'), p_activated_by, 'API_CLIENTS_CREATE', 
            CONCAT('Error Code: ', COALESCE(v_mysql_errno, 48001)),
            start_time, NOW(), TIMESTAMPDIFF(MICROSECOND, start_time, NOW()) / 1000
        );
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to create API client') AS error_message;            
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
    IF p_partner_id IS NULL OR p_partner_id <= 0 THEN
        SET error_code = '49001';
        SET error_message = 'Partner ID is required and must be valid.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    

    
    SELECT COUNT(*), business_name INTO v_partner_exists, v_partner_name
    FROM registered_partner
    WHERE reg_partner_id = p_partner_id
    AND Is_active = b'1';
    
    IF v_partner_exists = 0 THEN
        SET error_code = '49004';
        SET error_message = CONCAT('Partner with ID ', p_partner_id, ' does not exist or is not active.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    IF p_partner_root_domain IS NULL OR p_partner_root_domain = '' THEN
        SET error_code = '49002';
        SET error_message = 'Partner root domain is required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    IF p_activation_notes IS NULL OR p_activation_notes = '' THEN
        SET error_code = '49003';
        SET error_message = 'Activation notes are required.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
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
    
END //
DELIMITER ;
