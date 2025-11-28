-- Table: activity_log

DROP TABLE IF EXISTS `activity_log`;
CREATE TABLE `activity_log` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `log_type` varchar(45) DEFAULT NULL,
  `message` text,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `execution_time` int DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `browser_profile` varchar(255) DEFAULT NULL,
  `login_id` int DEFAULT NULL,
  `activity_type` varchar(100) DEFAULT NULL,
  `activity_details` varchar(255) DEFAULT NULL,
  `activity_logcol` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`log_id`)
) ENGINE=InnoDB;
