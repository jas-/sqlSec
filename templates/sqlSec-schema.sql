-- Switch to newly created db context
USE `{NAME}`;

-- Assign grant priviledge for scheduled events account then drop it
GRANT USAGE ON *.* TO `{SP}`@`{SERVER}`;
DROP USER `{SP}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Create the scheduled events user and assign limited permissions
CREATE USER `{SP}`@`{SERVER}` IDENTIFIED BY '{SP_PW}';
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, INDEX, CREATE TEMPORARY TABLES, LOCK TABLES, TRIGGER, EXECUTE, EVENT, CREATE VIEW, DROP ON `{NAME}`.* TO `{SP}`@`{SERVER}`;
GRANT FILE ON *.* TO `{SP}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Drop & create new application settings table
DROP TABLE IF EXISTS `sqlSec_settings`;
CREATE TABLE IF NOT EXISTS `sqlSec_settings` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `version` CHAR(32) NOT NULL,
  `epoch` INT(8) NOT NULL,
  `keyID` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `epoch` (`epoch`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Populate the settings table with defaults
INSERT INTO `sqlSec_settings` (`version`, `epoch`, `keyID`) VALUES ('{VER}', UNIX_TIMESTAMP(NOW()), '{KEY}');

-- Drop & create new table to manage table/fields which require symmetric encryption
DROP TABLE IF EXISTS `sqlSec_map`;
CREATE TABLE IF NOT EXISTS `sqlSec_map` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `tbl` CHAR(16) NOT NULL,
  `field` CHAR(32) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

