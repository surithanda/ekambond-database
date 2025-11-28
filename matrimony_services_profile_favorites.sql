-- Table: profile_favorites

DROP TABLE IF EXISTS `profile_favorites`;
CREATE TABLE `profile_favorites` (
  `profile_favorite_id` int NOT NULL AUTO_INCREMENT,
  `from_profile_id` int NOT NULL,
  `to_profile_id` int NOT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `is_active` bit(1) DEFAULT b'1',
  `date_updated` datetime DEFAULT NULL,
  `account_id` int DEFAULT NULL,
  PRIMARY KEY (`profile_favorite_id`)
) ENGINE=InnoDB;
