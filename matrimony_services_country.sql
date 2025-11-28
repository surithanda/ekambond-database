-- Table: country

DROP TABLE IF EXISTS `country`;
CREATE TABLE `country` (
  `country_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `country_name` varchar(100) NOT NULL,
  `official_name` varchar(150) DEFAULT NULL,
  `country_code_2` char(2) NOT NULL,
  `country_code_3` char(3) DEFAULT NULL,
  `country_number` char(3) DEFAULT NULL,
  `country_calling_code` varchar(5) DEFAULT NULL,
  `region` varchar(50) DEFAULT NULL,
  `latitude` decimal(8,5) DEFAULT NULL,
  `longitude` decimal(8,5) DEFAULT NULL,
  `flag_emoji` varchar(10) DEFAULT NULL,
  `flag_image_url` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`country_id`),
  UNIQUE KEY `country_code_2` (`country_code_2`),
  UNIQUE KEY `country_code_3` (`country_code_3`),
  KEY `idx_countries_name` (`country_name`),
  KEY `idx_countries_code2` (`country_code_2`),
  KEY `idx_countries_code3` (`country_code_3`)
) ENGINE=InnoDB;
