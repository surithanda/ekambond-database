-- =============================================
-- Procedure: admin_get_profiles
-- Purpose: Get complete profile data with all related tables
-- Parameters:
--   p_profile_id: Filter by profile ID (optional)
--   p_account_id: Filter by account ID (optional)
--   p_verification_status: Filter by verification status (optional)
--   p_limit: Number of records to return
--   p_offset: Number of records to skip
-- Returns: Complete profile data with all related information
-- =============================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `admin_get_profiles`$$

CREATE PROCEDURE `admin_get_profiles`(
    IN p_profile_id INT,
    IN p_account_id INT,
    IN p_verification_status VARCHAR(20),
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    DECLARE v_total_count INT DEFAULT 0;
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
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'ADMIN_GET_PROFILES_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Failed to get profiles') AS error_message;
    END;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM profile_personal pp
    WHERE 
        (p_profile_id IS NULL OR pp.profile_id = p_profile_id)
        AND (p_account_id IS NULL OR pp.account_id = p_account_id);
    
    -- Return complete profile data
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        -- Personal Info
        pp.profile_id,
        pp.account_id,
        pp.height_cms AS height,
        pp.weight,
        pp.marital_status,
        NULL AS mother_tongue,
        NULL AS physical_status,
        NULL AS body_type,
        pp.complexion,
        NULL AS eating_habits,
        NULL AS drinking_habits,
        NULL AS smoking_habits,
        NULL AS profile_created_by,
        pp.short_summary AS about_me,
        NULL AS hobbies,
        NULL AS interests,
        'pending' AS personal_verification_status,
        NULL AS personal_verified_by,
        NULL AS personal_verified_date,
        pp.created_date AS personal_created_date,
        
        -- Address Info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'address_id', pa.profile_address_id,
                'address_type', pa.address_type,
                'address_line1', pa.address_line1,
                'address_line2', pa.address_line2,
                'city', pa.city,
                'state', pa.state,
                'country_id', pa.country_id,
                'zip', pa.zip
            )
        ) FROM profile_address pa WHERE pa.profile_id = pp.profile_id) AS addresses,
        
        -- Education Info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'education_id', pe.profile_education_id,
                'education_level', pe.education_level,
                'institution_name', pe.institution_name,
                'field_of_study', pe.field_of_study,
                'year_completed', pe.year_completed
            )
        ) FROM profile_education pe WHERE pe.profile_id = pp.profile_id) AS education,
        
        -- Employment Info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'employment_id', pem.profile_employment_id,
                'institution_name', pem.institution_name,
                'job_title_id', pem.job_title_id,
                'start_year', pem.start_year,
                'end_year', pem.end_year,
                'last_salary_drawn', pem.last_salary_drawn
            )
        ) FROM profile_employment pem WHERE pem.profile_id = pp.profile_id) AS employment,
        
        -- Family References
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'reference_id', pfr.profile_family_reference_id,
                'reference_type', pfr.reference_type,
                'first_name', pfr.first_name,
                'last_name', pfr.last_name,
                'middle_name', pfr.middle_name,
                'primary_phone', pfr.primary_phone,
                'email', pfr.email,
                'employment_status', pfr.employment_status,
                'emp_company_name', pfr.emp_company_name
            )
        ) FROM profile_family_reference pfr WHERE pfr.profile_id = pp.profile_id) AS family_references,
        
        -- Photos
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'photo_id', pph.profile_photo_id,
                'url', pph.url,
                'photo_type', pph.photo_type,
                'caption', pph.caption,
                'date_created', pph.date_created
            )
        ) FROM profile_photo pph WHERE pph.profile_id = pp.profile_id AND pph.softdelete = 0) AS photos,
        
        -- Account Info
        a.account_code,
        a.email,
        a.first_name,
        a.last_name,
        a.is_active AS account_is_active,
        
        -- Pagination info
        v_total_count AS total_count,
        p_limit AS page_limit,
        p_offset AS page_offset
        
    FROM profile_personal pp
    INNER JOIN account a ON pp.account_id = a.account_id
    WHERE 
        (p_profile_id IS NULL OR pp.profile_id = p_profile_id)
        AND (p_account_id IS NULL OR pp.account_id = p_account_id)
    ORDER BY pp.created_date DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
