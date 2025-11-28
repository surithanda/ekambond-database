-- Table: profile_property

DROP TABLE IF EXISTS `profile_property`;
CREATE TABLE `profile_property` (
  `property_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int DEFAULT NULL,
  `property_type` int DEFAULT NULL,
  `ownership_type` int DEFAULT NULL,
  `property_address` varchar(125) DEFAULT NULL,
  `property_value` decimal(10,2) DEFAULT NULL,
  `property_description` varchar(2000) DEFAULT NULL,
  `isoktodisclose` bit(1) DEFAULT NULL,
  `created_date` datetime DEFAULT NULL,
  `modified_date` datetime DEFAULT NULL,
  `created_by` varchar(45) DEFAULT NULL,
  `modifyed_by` varchar(45) DEFAULT NULL,
  `isverified` bit(1) DEFAULT b'0',
  PRIMARY KEY (`property_id`)
) ENGINE=InnoDB COMMENT='	';
