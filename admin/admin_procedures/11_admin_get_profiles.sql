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
    
    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT,
            v_error_code = MYSQL_ERRNO;
        SELECT 'fail' AS status, 'SQL Exception' AS error_type, v_error_code AS error_code, v_error_message AS error_message;
    END;
    
    -- Set default pagination values
    SET p_limit = COALESCE(p_limit, 50);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM profile_personal pp
    WHERE 
        (p_profile_id IS NULL OR pp.profile_id = p_profile_id)
        AND (p_account_id IS NULL OR pp.account_id = p_account_id)
        AND (p_verification_status IS NULL OR pp.verification_status = p_verification_status);
    
    -- Return complete profile data
    SELECT 
        'success' AS status,
        NULL AS error_type,
        NULL AS error_code,
        NULL AS error_message,
        -- Personal Info
        pp.profile_id,
        pp.account_id,
        pp.height,
        pp.weight,
        pp.marital_status,
        pp.mother_tongue,
        pp.physical_status,
        pp.body_type,
        pp.complexion,
        pp.eating_habits,
        pp.drinking_habits,
        pp.smoking_habits,
        pp.profile_created_by,
        pp.about_me,
        pp.hobbies,
        pp.interests,
        pp.verification_status AS personal_verification_status,
        pp.verified_by AS personal_verified_by,
        pp.verified_date AS personal_verified_date,
        pp.created_date AS personal_created_date,
        
        -- Address Info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'address_id', pa.address_id,
                'address_type', pa.address_type,
                'address_line1', pa.address_line1,
                'address_line2', pa.address_line2,
                'city', pa.city,
                'state', pa.state,
                'country', pa.country,
                'zip', pa.zip,
                'verification_status', pa.verification_status,
                'verified_by', pa.verified_by,
                'verified_date', pa.verified_date
            )
        ) FROM profile_address pa WHERE pa.profile_id = pp.profile_id) AS addresses,
        
        -- Education Info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'education_id', pe.education_id,
                'education_level', pe.education_level,
                'institution_name', pe.institution_name,
                'field_of_study', pe.field_of_study,
                'year_of_passing', pe.year_of_passing,
                'verification_status', pe.verification_status,
                'verified_by', pe.verified_by,
                'verified_date', pe.verified_date
            )
        ) FROM profile_education pe WHERE pe.profile_id = pp.profile_id) AS education,
        
        -- Employment Info
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'employment_id', pem.employment_id,
                'employment_status', pem.employment_status,
                'occupation', pem.occupation,
                'organization_name', pem.organization_name,
                'annual_income', pem.annual_income,
                'currency', pem.currency,
                'verification_status', pem.verification_status,
                'verified_by', pem.verified_by,
                'verified_date', pem.verified_date
            )
        ) FROM profile_employment pem WHERE pem.profile_id = pp.profile_id) AS employment,
        
        -- Family References
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'reference_id', pfr.reference_id,
                'reference_type', pfr.reference_type,
                'name', pfr.name,
                'relationship', pfr.relationship,
                'occupation', pfr.occupation,
                'phone', pfr.phone,
                'email', pfr.email
            )
        ) FROM profile_family_references pfr WHERE pfr.profile_id = pp.profile_id) AS family_references,
        
        -- Photos
        (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'photo_id', pph.photo_id,
                'photo_url', pph.photo_url,
                'photo_type', pph.photo_type,
                'is_primary', pph.is_primary,
                'verification_status', pph.verification_status,
                'uploaded_date', pph.uploaded_date
            )
        ) FROM profile_photos pph WHERE pph.profile_id = pp.profile_id) AS photos,
        
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
        AND (p_verification_status IS NULL OR pp.verification_status = p_verification_status)
    ORDER BY pp.created_date DESC
    LIMIT p_limit OFFSET p_offset;
    
END$$

DELIMITER ;
