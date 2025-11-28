-- Table: login_history

DROP TABLE IF EXISTS `login_history`;
CREATE TABLE `login_history` (
  `history_id` int NOT NULL AUTO_INCREMENT,
  `login_name` varchar(45) DEFAULT NULL,
  `login_date` datetime DEFAULT NULL,
  `login_status` int DEFAULT NULL,
  `login_failure_reason` varchar(45) DEFAULT NULL,
  `email_otp` int DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `system_name` varchar(45) DEFAULT NULL,
  `user_agent` varchar(150) DEFAULT NULL,
  `location` varchar(45) DEFAULT NULL,
  `login_id_on_success` int DEFAULT NULL,
  `email_otp_valid_start` datetime DEFAULT NULL,
  `email_otp_valid_end` datetime DEFAULT NULL,
  PRIMARY KEY (`history_id`)
) ENGINE=InnoDB;
