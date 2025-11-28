-- Table: profile_education

DROP TABLE IF EXISTS `profile_education`;
CREATE TABLE `profile_education` (
  `profile_education_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `education_level` int NOT NULL,
  `year_completed` int NOT NULL,
  `institution_name` varchar(255) NOT NULL,
  `address_line1` varchar(100) DEFAULT NULL,
  `city` varchar(45) DEFAULT NULL,
  `state_id` int NOT NULL,
  `country_id` int NOT NULL,
  `zip` varchar(8) NOT NULL,
  `field_of_study` int NOT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `user_created` varchar(45) DEFAULT NULL,
  `date_modified` datetime DEFAULT CURRENT_TIMESTAMP,
  `user_modified` varchar(45) DEFAULT NULL,
  `isverified` int DEFAULT NULL,
  PRIMARY KEY (`profile_education_id`)
) ENGINE=InnoDB;
