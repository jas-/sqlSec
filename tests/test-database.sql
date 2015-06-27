-- Create the database & drop if it already exists
DROP DATABASE IF EXISTS `{NAME}`;
CREATE DATABASE `{NAME}` DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci;

-- Assign grant priviledge for administrative account then drop it
-- GRANT
--   USAGE
-- ON *.* TO `{ADMIN}`@`{SERVER}`;
-- DROP USER `{ADMIN}`@`{SERVER}`;
-- FLUSH PRIVILEGES;

-- Create a default administrative user and assign limited permissions
CREATE USER `{ADMIN}`@`{SERVER}` IDENTIFIED BY '{ADMIN_PW}';
GRANT
  CREATE, SELECT, INSERT, UPDATE, DELETE, REFERENCES, INDEX,
  CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE
ON `{NAME}`.* TO `{ADMIN}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Assign grant priviledge for read-only account then drop it
-- GRANT
--   USAGE
-- ON *.* TO `{RO}`@`{SERVER}`;
-- DROP USER `{RO}`@`{SERVER}`;
-- FLUSH PRIVILEGES;

-- Create a default read-only user and assign limited permissions
CREATE USER `{RO}`@`{SERVER}` IDENTIFIED BY '{RO_PW}';
GRANT
  SELECT, REFERENCES, INDEX, LOCK TABLES, EXECUTE
ON `{NAME}`.* TO `{RO}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Switch to newly created db context
USE `{NAME}`;

-- Drop & create new keyring table
DROP TABLE IF EXISTS `keyring`;
CREATE TABLE IF NOT EXISTS `keyring` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create credentials table
DROP TABLE IF EXISTS `credentials`;
CREATE TABLE IF NOT EXISTS `credentials` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` BIGINT NOT NULL,
  `email` LONGTEXT NOT NULL,
  `passphrase` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_credentials2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`id`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new private keys table
DROP TABLE IF EXISTS `privatekeys`;
CREATE TABLE IF NOT EXISTS `privatekeys` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` BIGINT NOT NULL,
  `private` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_privatekeys2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`id`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new public keys table
DROP TABLE IF EXISTS `publickeys`;
CREATE TABLE IF NOT EXISTS `publickeys` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` BIGINT NOT NULL,
  `public` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_publickeys2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`id`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new certificates table
DROP TABLE IF EXISTS `certificates`;
CREATE TABLE IF NOT EXISTS `certificates` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` BIGINT NOT NULL,
  `certificate` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_certificates2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`id`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new trusted table
DROP TABLE IF EXISTS `trusts`;
CREATE TABLE IF NOT EXISTS `trusts` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` BIGINT NOT NULL,
  `trusted` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_trusts2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`id`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create revoked table
DROP TABLE IF EXISTS `escrow`;
CREATE TABLE IF NOT EXISTS `escrow` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  FOREIGN KEY `fk_escrow2keyring` (`keyID`)
    REFERENCES `keyring`(`id`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- View for keyring entries
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewKeyring AS
 SELECT
  k.id AS ID,
  k.keyID AS KeyID,
  a.email AS Email,
  a.passphrase AS Password,
  p.private AS PrivateKey,
  pk.public AS PublicKey,
  c.certificate AS Certificate,
  t.trusted AS Trusts
 FROM keyring k
  LEFT JOIN credentials a ON k.ID = a.keyID
  LEFT JOIN privatekeys p ON k.ID = p.keyID
  LEFT JOIN publickeys pk ON k.ID = pk.keyID
  LEFT JOIN certificates c ON k.ID = c.keyID
  LEFT JOIN trusts t ON k.ID = t.keyId
 WHERE k.ID NOT IN (SELECT keyID FROM escrow)
 ORDER BY k.ID ASC;

-- View for keyring entries in escrow
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewKeyringInEscrow AS
 SELECT
  k.id AS ID,
  k.keyID AS KeyID,
  a.email AS Email,
  a.passphrase AS Password,
  p.private AS PrivateKey,
  pk.public AS PublicKey,
  c.certificate AS Certificate,
  t.trusted AS Trusts
 FROM keyring k
  LEFT JOIN credentials a ON k.ID = a.keyID
  LEFT JOIN privatekeys p ON k.ID = p.keyID
  LEFT JOIN publickeys pk ON k.ID = pk.keyID
  LEFT JOIN certificates c ON k.ID = c.keyID
  LEFT JOIN trusts t ON k.ID = t.keyId
 WHERE k.ID IN (SELECT keyID FROM escrow)
 ORDER BY k.ID ASC;
