-- Table: profile_views

DROP TABLE IF EXISTS `profile_views`;
CREATE TABLE `profile_views` (
  `profile_view_id` int NOT NULL AUTO_INCREMENT,
  `from_profile_id` int NOT NULL,
  `to_profile_id` int NOT NULL,
  `profile_view_date` datetime DEFAULT CURRENT_TIMESTAMP,
  `account_id` int DEFAULT NULL,
  PRIMARY KEY (`profile_view_id`)
) ENGINE=InnoDB;
