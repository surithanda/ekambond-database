-- Table: profile_contacted

DROP TABLE IF EXISTS `profile_contacted`;
CREATE TABLE `profile_contacted` (
  `profile_view_id` int NOT NULL AUTO_INCREMENT,
  `from_profile_id` int NOT NULL,
  `to_profile_id` int DEFAULT NULL,
  `profile_contact_date` datetime DEFAULT NULL,
  `profile_contact_result` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_date` datetime DEFAULT CURRENT_TIMESTAMP,
  `account_id` int NOT NULL,
  PRIMARY KEY (`profile_view_id`)
) ENGINE=InnoDB;
