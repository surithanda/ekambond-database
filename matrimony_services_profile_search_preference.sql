-- Table: profile_search_preference

DROP TABLE IF EXISTS `profile_search_preference`;
CREATE TABLE `profile_search_preference` (
  `search_preference_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `min_age` int DEFAULT NULL,
  `max_age` int DEFAULT NULL,
  `religion` int DEFAULT NULL,
  `max_education` int DEFAULT NULL,
  `occupation` int DEFAULT NULL,
  `country` varchar(45) DEFAULT NULL,
  `casete_id` int DEFAULT NULL,
  `marital_status` int DEFAULT NULL,
  `gender` int DEFAULT NULL,
  PRIMARY KEY (`search_preference_id`)
) ENGINE=InnoDB;
