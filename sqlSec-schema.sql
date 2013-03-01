-- Switch to newly created db context
USE `[dbName]`;

-- Assign grant priviledge for scheduled events account then drop it
GRANT USAGE ON *.* TO `[dbUser]`@`[dbHost]`;
DROP USER `[dbUser]`@`[dbHost]`;
FLUSH PRIVILEGES;

-- Create the scheduled events user and assign limited permissions
CREATE USER `[dbUser]`@`[dbHost]` IDENTIFIED BY '[dbPass]';
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, INDEX, CREATE TEMPORARY TABLES, LOCK TABLES, TRIGGER, EXECUTE, EVENT, CREATE VIEW, DROP ON `[dbName]`.* TO `[dbUser]`@`[dbHost]`;
GRANT FILE ON *.* TO `[dbUser]`@`[dbHost]`;
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
INSERT INTO `sqlSec_settings` (`version`, `epoch`, `keyID`) VALUES ('v0.1', UNIX_TIMESTAMP(NOW()), '[dbKey]');

-- Drop & create new table to manage table/fields which require symmetric encryption
DROP TABLE IF EXISTS `sqlSec_map`;
CREATE TABLE IF NOT EXISTS `sqlSec_map` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `tbl` CHAR(16) NOT NULL,
  `field` CHAR(32) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `field` (`field`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Testing table
DROP TABLE IF EXISTS `myTest`;
CREATE TABLE IF NOT EXISTS `myTest` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `myField` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

INSERT INTO `myTest` (`myField`) VALUES ("abd"),("def"),("hij");
