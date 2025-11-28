-- Table: lookup_table

DROP TABLE IF EXISTS `lookup_table`;
CREATE TABLE `lookup_table` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` varchar(150) DEFAULT NULL,
  `category` varchar(150) DEFAULT NULL COMMENT 'PhoneType, Gender, FriendType etc.,',
  `isactive` tinyint DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
