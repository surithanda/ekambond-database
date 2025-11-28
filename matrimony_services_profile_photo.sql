-- Table: profile_photo

DROP TABLE IF EXISTS `profile_photo`;
CREATE TABLE `profile_photo` (
  `profile_photo_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `photo_type` int NOT NULL COMMENT '1 - Clear Headshot  - This picture will be displayed every where. Like Search, Profile default photo. \n2 - Full-body shot - This helps provide a better perspective of your appearance and body language. Choose a relaxed setting, like outdoors, for a more natural feel.\n3 - Casual or Lifestyle Shot - A picture of you doing something you love, like traveling, reading, or playing a sport, will show your interests and hobbies.\n\n\n4 - Family Photo - A photo with family members (if appropriate) can give a sense of your familial bonds, showing you''re family-oriented\n5 - Candid or Fun Moment – A lighthearted photo of you laughing or enjoying time with friends might help balance out the more formal shots and show your personality.\n6 - Hobby or Activity Photo – If you''re passionate about something like cooking, painting, or playing a musical instrument, sharing a photo of you engaged in that can reveal more about who you are.\n\n ',
  `description` varchar(255) DEFAULT NULL,
  `caption` varchar(100) NOT NULL,
  `relative_path` varchar(255) DEFAULT NULL,
  `url` varchar(100) NOT NULL,
  `date_created` datetime DEFAULT NULL,
  `user_created` varchar(45) DEFAULT NULL,
  `date_modified` datetime DEFAULT NULL,
  `user_modified` varchar(45) DEFAULT NULL,
  `isverified` int DEFAULT '0',
  `softdelete` bit(1) DEFAULT b'0' COMMENT '0 - Active, 1 - Soft Deleted',
  PRIMARY KEY (`profile_photo_id`)
) ENGINE=InnoDB;
