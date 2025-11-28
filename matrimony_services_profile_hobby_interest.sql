-- Table: profile_hobby_interest

DROP TABLE IF EXISTS `profile_hobby_interest`;
CREATE TABLE `profile_hobby_interest` (
  `profile_hobby_intereste_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `hobby_interest_id` int NOT NULL,
  `description` varchar(100) DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `user_created` varchar(45) DEFAULT NULL,
  `date_modified` datetime DEFAULT NULL,
  `user_modified` varchar(45) DEFAULT NULL,
  `isverified` int DEFAULT '0',
  PRIMARY KEY (`profile_hobby_intereste_id`)
) ENGINE=InnoDB;
