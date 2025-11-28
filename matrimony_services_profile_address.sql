-- Table: profile_address

DROP TABLE IF EXISTS `profile_address`;
CREATE TABLE `profile_address` (
  `profile_address_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `address_type` int NOT NULL,
  `address_line1` varchar(100) NOT NULL,
  `address_line2` varchar(100) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `state` int NOT NULL,
  `country_id` int NOT NULL,
  `zip` varchar(10) NOT NULL,
  `landmark1` varchar(100) DEFAULT NULL,
  `landmark2` varchar(100) DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `user_created` varchar(45) DEFAULT NULL,
  `date_modified` datetime DEFAULT CURRENT_TIMESTAMP,
  `user_modified` varchar(45) DEFAULT NULL,
  `isverified` int DEFAULT NULL,
  PRIMARY KEY (`profile_address_id`)
) ENGINE=InnoDB;
