DELIMITER //
DROP PROCEDURE IF EXISTS `admin_registered_partner_delete_v1`;
CREATE PROCEDURE `admin_registered_partner_delete_v1`(
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
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    -- Check if partner exists
    SELECT COUNT(*) INTO partner_exists
    FROM registered_partner
    WHERE reg_partner_id = p_reg_partner_id;
    
    IF partner_exists = 0 THEN
        SET error_code = '48302';
        SET error_message = 'Partner with the provided ID does not exist.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
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
    
END //
DELIMITER ;
