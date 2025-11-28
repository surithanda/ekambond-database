-- Table: api_clients

DROP TABLE IF EXISTS `api_clients`;
CREATE TABLE `api_clients` (
  `id` int NOT NULL AUTO_INCREMENT,
  `partner_name` varchar(255) NOT NULL,
  `api_key` varchar(64) NOT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `partner_id` int DEFAULT NULL,
  `partner_root_domain` varchar(50) DEFAULT NULL,
  `partner_admin_url` varchar(100) DEFAULT NULL,
  `partner_pin` int DEFAULT NULL,
  `activated_date` timestamp NULL DEFAULT NULL,
  `activation_notes` varchar(255) DEFAULT NULL,
  `deactivated_date` timestamp NULL DEFAULT NULL,
  `deactivation_notes` varchar(255) DEFAULT NULL,
  `deactivated_by` int DEFAULT NULL,
  `activated_by` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `api_key` (`api_key`)
) ENGINE=InnoDB;
