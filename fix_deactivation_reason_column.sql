-- Fix deactivation_reason column size
-- Current: VARCHAR(45) - Too short for meaningful reasons
-- New: VARCHAR(500) - Allows for detailed explanations

USE matrimony_services;

-- Increase deactivation_reason column size
ALTER TABLE account 
MODIFY COLUMN deactivation_reason VARCHAR(500) DEFAULT NULL;

-- Also increase deleted_reason while we're at it (it has the same issue)
ALTER TABLE account 
MODIFY COLUMN deleted_reason VARCHAR(500) DEFAULT NULL;

-- Verify changes
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'matrimony_services'
AND TABLE_NAME = 'account'
AND COLUMN_NAME IN ('deactivation_reason', 'deleted_reason');
