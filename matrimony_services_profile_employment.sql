-- Table: profile_employment

DROP TABLE IF EXISTS `profile_employment`;
CREATE TABLE `profile_employment` (
  `profile_employment_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `institution_name` varchar(255) NOT NULL,
  `address_line1` varchar(100) DEFAULT NULL,
  `city` varchar(45) NOT NULL,
  `state_id` int NOT NULL,
  `country_id` int NOT NULL,
  `zip` varchar(8) NOT NULL,
  `start_year` int NOT NULL,
  `end_year` int DEFAULT NULL,
  `job_title_id` int NOT NULL,
  `other_title` varchar(50) DEFAULT NULL,
  `last_salary_drawn` decimal(10,0) NOT NULL,
  `date_created` datetime DEFAULT NULL,
  `user_created` varchar(45) DEFAULT NULL,
  `date_modified` datetime DEFAULT NULL,
  `user_modified` varchar(45) DEFAULT NULL,
  `isverified` int DEFAULT NULL,
  PRIMARY KEY (`profile_employment_id`)
) ENGINE=InnoDB;
