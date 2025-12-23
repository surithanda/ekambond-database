-- =============================================
-- Admin Database Schema
-- Created: 2024
-- Purpose: Admin user management and authentication
-- =============================================

USE matrimony_services;

-- =============================================
-- Table: admin_users
-- Purpose: Store admin user accounts with role-based access
-- =============================================
DROP TABLE IF EXISTS `admin_users`;
CREATE TABLE `admin_users` (
    `admin_id` INT PRIMARY KEY AUTO_INCREMENT,
    `username` VARCHAR(50) UNIQUE NOT NULL,
    `email` VARCHAR(150) UNIQUE NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` ENUM('viewer', 'approver', 'admin') NOT NULL DEFAULT 'viewer',
    `is_active` TINYINT(1) DEFAULT 1,
    `last_login` DATETIME,
    `failed_login_attempts` INT DEFAULT 0,
    `locked_until` DATETIME,
    `mfa_secret` VARCHAR(32),
    `mfa_enabled` TINYINT(1) DEFAULT 0,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_by` VARCHAR(45),
    INDEX `idx_username` (`username`),
    INDEX `idx_email` (`email`),
    INDEX `idx_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- Table: admin_sessions
-- Purpose: Manage admin user sessions
-- =============================================
DROP TABLE IF EXISTS `admin_sessions`;
CREATE TABLE `admin_sessions` (
    `session_id` VARCHAR(128) PRIMARY KEY,
    `admin_id` INT NOT NULL,
    `ip_address` VARCHAR(45),
    `user_agent` TEXT,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME NOT NULL,
    `is_active` TINYINT(1) DEFAULT 1,
    `last_activity` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users`(`admin_id`) ON DELETE CASCADE,
    INDEX `idx_admin_id` (`admin_id`),
    INDEX `idx_expires_at` (`expires_at`),
    INDEX `idx_is_active` (`is_active`)
) ENGINE=InnoDB;

-- =============================================
-- Table: api_keys
-- Purpose: Enhanced API key management with expiration
-- =============================================
DROP TABLE IF EXISTS `api_keys`;
CREATE TABLE `api_keys` (
    `key_id` INT PRIMARY KEY AUTO_INCREMENT,
    `client_id` INT NOT NULL,
    `api_key` VARCHAR(64) UNIQUE NOT NULL,
    `key_name` VARCHAR(100),
    `expires_at` DATETIME,
    `is_active` TINYINT(1) DEFAULT 1,
    `usage_count` INT DEFAULT 0,
    `last_used` DATETIME,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(45),
    FOREIGN KEY (`client_id`) REFERENCES `api_clients`(`id`) ON DELETE CASCADE,
    INDEX `idx_api_key` (`api_key`),
    INDEX `idx_client_id` (`client_id`),
    INDEX `idx_is_active` (`is_active`),
    INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB;

-- =============================================
-- Table: notification_queue
-- Purpose: Queue for email notifications
-- =============================================
DROP TABLE IF EXISTS `notification_queue`;
CREATE TABLE `notification_queue` (
    `notification_id` INT PRIMARY KEY AUTO_INCREMENT,
    `recipient_email` VARCHAR(150) NOT NULL,
    `subject` VARCHAR(255) NOT NULL,
    `message_body` TEXT NOT NULL,
    `notification_type` VARCHAR(50) NOT NULL,
    `status` ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
    `attempts` INT DEFAULT 0,
    `max_attempts` INT DEFAULT 3,
    `scheduled_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `sent_at` DATETIME,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(45),
    INDEX `idx_status` (`status`),
    INDEX `idx_scheduled_at` (`scheduled_at`),
    INDEX `idx_notification_type` (`notification_type`)
) ENGINE=InnoDB;

-- =============================================
-- Table: admin_audit_log
-- Purpose: Comprehensive audit trail for admin actions
-- =============================================
DROP TABLE IF EXISTS `admin_audit_log`;
CREATE TABLE `admin_audit_log` (
    `audit_id` INT PRIMARY KEY AUTO_INCREMENT,
    `admin_id` INT,
    `action_type` VARCHAR(100) NOT NULL,
    `resource_type` VARCHAR(50) NOT NULL,
    `resource_id` VARCHAR(100),
    `action_details` JSON,
    `ip_address` VARCHAR(45),
    `user_agent` TEXT,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users`(`admin_id`) ON DELETE SET NULL,
    INDEX `idx_admin_id` (`admin_id`),
    INDEX `idx_action_type` (`action_type`),
    INDEX `idx_resource_type` (`resource_type`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB;

-- =============================================
-- Table: password_reset_tokens
-- Purpose: Manage password reset tokens
-- =============================================
DROP TABLE IF EXISTS `password_reset_tokens`;
CREATE TABLE `password_reset_tokens` (
    `token_id` INT PRIMARY KEY AUTO_INCREMENT,
    `admin_id` INT NOT NULL,
    `token` VARCHAR(128) UNIQUE NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `is_used` TINYINT(1) DEFAULT 0,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users`(`admin_id`) ON DELETE CASCADE,
    INDEX `idx_token` (`token`),
    INDEX `idx_admin_id` (`admin_id`),
    INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB;

-- =============================================
-- Insert default admin user (password: Admin@123)
-- Note: Password should be hashed using bcrypt in production
-- =============================================
INSERT INTO `admin_users` (`username`, `email`, `password_hash`, `role`, `is_active`, `created_by`)
VALUES ('admin', 'admin@matrimony.com', '$2b$10$rQZ8YqXqZ8YqXqZ8YqXqZeO8YqXqZ8YqXqZ8YqXqZ8YqXqZ8YqXqZ', 'admin', 1, 'system');

-- =============================================
-- End of admin schema
-- =============================================
