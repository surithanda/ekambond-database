-- Table: stripe_payment_intents

DROP TABLE IF EXISTS `stripe_payment_intents`;
CREATE TABLE `stripe_payment_intents` (
  `id` int NOT NULL AUTO_INCREMENT,
  `amount` bigint NOT NULL COMMENT 'Amount in smallest currency unit (e.g., cents)',
  `currency` varchar(3) NOT NULL COMMENT 'Three-letter ISO currency code',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Record update timestamp',
  `client_reference_id` varchar(100) DEFAULT NULL,
  `session_id` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `address` varchar(256) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `state` varchar(100) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `zip_code` varchar(100) DEFAULT NULL,
  `payment_status` varchar(50) DEFAULT NULL,
  `payment_mode` varchar(50) DEFAULT NULL,
  `payment_start_date` timestamp NULL DEFAULT NULL,
  `payment_stop_date` timestamp NULL DEFAULT NULL,
  `account_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB;
