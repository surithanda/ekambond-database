-- =============================================
-- Procedure: admin_create_partner_registration
-- Purpose: Create a new partner registration
-- Parameters:
--   p_business_name: Name of the business
--   p_business_type: Type of business
--   p_registration_number: Business registration number (optional)
--   p_tax_id: Tax identification number (optional)
--   p_contact_person: Contact person name
--   p_contact_email: Contact email address
--   p_contact_phone: Contact phone number
--   p_contact_phone_country: Contact phone country code
--   p_website: Business website (optional)
--   p_created_by: Admin user who created the registration
-- Returns: Partner registration details
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_create_partner_registration`$$

CREATE PROCEDURE `admin_create_partner_registration`(
    IN p_business_name VARCHAR(150),
    IN p_business_type VARCHAR(50),
    IN p_registration_number VARCHAR(50),
    IN p_tax_id VARCHAR(50),
    IN p_contact_person VARCHAR(100),
    IN p_contact_email VARCHAR(150),
    IN p_contact_phone VARCHAR(15),
    IN p_contact_phone_country VARCHAR(5),
    IN p_website VARCHAR(255),
    IN p_created_by VARCHAR(45)
)
proc_label: BEGIN
    DECLARE v_partner_id INT;
    DECLARE v_email_exists INT DEFAULT 0;
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_CREATE_PARTNER_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 51013) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to create partner registration') AS error_message;
    END;
    
    DECLARE EXIT HANDLER FOR SQLSTATE '45000'
    BEGIN
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    SET v_start_time = NOW();
    SET v_error_code = NULL;
    SET v_error_message = NULL;
    
    -- Validate required fields
    IF p_business_name IS NULL OR TRIM(p_business_name) = '' THEN
        SET v_error_code = '51014';
        SET v_error_message = 'Business name is required';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    IF p_business_type IS NULL OR TRIM(p_business_type) = '' THEN
        SET v_error_code = '51015';
        SET v_error_message = 'Business type is required';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    IF p_contact_person IS NULL OR TRIM(p_contact_person) = '' THEN
        SET v_error_code = '51016';
        SET v_error_message = 'Contact person is required';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    IF p_contact_email IS NULL OR TRIM(p_contact_email) = '' THEN
        SET v_error_code = '51017';
        SET v_error_message = 'Contact email is required';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    IF p_contact_phone IS NULL OR TRIM(p_contact_phone) = '' THEN
        SET v_error_code = '51018';
        SET v_error_message = 'Contact phone is required';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    IF p_contact_phone_country IS NULL OR TRIM(p_contact_phone_country) = '' THEN
        SET v_error_code = '51019';
        SET v_error_message = 'Contact phone country code is required';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Check if email already exists
    SELECT COUNT(*)
    INTO v_email_exists
    FROM registered_partner
    WHERE primary_contact_email = p_contact_email OR business_email = p_contact_email;
    
    IF v_email_exists > 0 THEN
        SET v_error_code = '51020';
        SET v_error_message = 'Partner with this email already exists';
        SELECT 'fail' AS status, 'Validation Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
        LEAVE proc_label;
    END IF;
    
    -- Insert new partner registration
    -- Split contact person into first and last name (simple split on first space)
    INSERT INTO registered_partner (
        business_name,
        alias,
        business_email,
        primary_phone,
        primary_phone_country_code,
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
        primary_contact_email,
        business_website,
        date_created,
        user_created,
        verification_status,
        Is_active
    ) VALUES (
        p_business_name,
        LOWER(REPLACE(p_business_name, ' ', '_')),  -- Generate alias from business name
        p_contact_email,
        p_contact_phone,
        CAST(p_contact_phone_country AS UNSIGNED),  -- Convert string to int
        'To be updated',  -- Default address - can be updated later
        'To be updated',  -- Default city
        0,  -- Default state (0 = unspecified)
        0,  -- Default country (0 = unspecified)
        '000000',  -- Default zip
        COALESCE(p_registration_number, 'N/A'),
        COALESCE(p_tax_id, 'N/A'),
        p_business_type,  -- Using business_type as description
        SUBSTRING_INDEX(p_contact_person, ' ', 1),  -- First name (before first space)
        SUBSTRING_INDEX(p_contact_person, ' ', -1),  -- Last name (after last space)
        p_contact_email,
        COALESCE(p_website, ''),
        NOW(),
        p_created_by,
        'pending',  -- verification_status
        b'1'  -- Is_active = true
    );
    
    SET v_partner_id = LAST_INSERT_ID();
    
    -- Log the activity
    INSERT INTO activity_log (
        log_type,
        message,
        created_by,
        start_time,
        end_time,
        execution_time,
        activity_type,
        activity_details
    ) VALUES (
        'INFO',
        CONCAT('Partner registration created: ', p_business_name, ' (ID: ', v_partner_id, ')'),
        p_created_by,
        v_start_time,
        NOW(),
        TIMESTAMPDIFF(MICROSECOND, v_start_time, NOW()),
        'ADMIN_CREATE_PARTNER',
        JSON_OBJECT(
            'partner_id', v_partner_id,
            'business_name', p_business_name,
            'business_type', p_business_type,
            'contact_email', p_contact_email,
            'created_by', p_created_by
        )
    );
    
    -- Return the created partner details
    SELECT 
        'success' AS status,
        reg_partner_id AS id,
        business_name,
        business_description AS business_type,
        business_registration_number AS registration_number,
        business_ITIN AS tax_id,
        CONCAT(primary_contact_first_name, ' ', primary_contact_last_name) AS contact_person,
        primary_contact_email AS contact_email,
        business_email,
        primary_phone AS contact_phone,
        CAST(primary_phone_country_code AS CHAR) AS contact_phone_country,
        business_website AS website,
        verification_status AS approval_status,
        user_modified AS approved_by,
        date_modified AS approved_date,
        verification_comment AS rejection_reason,
        date_created AS created_date
    FROM registered_partner
    WHERE reg_partner_id = v_partner_id;
    
END$$

DELIMITER ;
