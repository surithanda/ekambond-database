-- Table: test

DROP TABLE IF EXISTS `test`;
CREATE TABLE `test` (
  `my_row_id` bigint unsigned NOT NULL AUTO_INCREMENT /*!80023 INVISIBLE */,
  `name` varchar(45) NOT NULL,
  PRIMARY KEY (`my_row_id`)
) ENGINE=InnoDB;
