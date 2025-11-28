-- Update default admin password with proper bcrypt hash
-- Password: Admin@123
-- Hash generated with bcrypt rounds=10

USE matrimony_services;

UPDATE admin_users 
SET password_hash = '$2b$10$eSqyBPCzF2/e85pZvpaideRQsyx1w35bTpsBdMEHm2U0.crhL.jIa',
    failed_login_attempts = 0,
    locked_until = NULL
WHERE username = 'admin';

SELECT 'Admin password updated successfully' AS message;
