-- Create the database & drop if it already exists
DROP DATABASE IF EXISTS `{NAME}`;
CREATE DATABASE `{NAME}` DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci;

-- Assign grant priviledge for administrative account then drop it
GRANT USAGE ON *.* TO `{ADMIN}`@`{SERVER}`;
DROP USER `{ADMIN}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Create a default administrative user and assign limited permissions
CREATE USER `{ADMIN}`@`{SERVER}` IDENTIFIED BY '{ADMIN_PW}';
GRANT CREATE, SELECT, INSERT, UPDATE, DELETE, REFERENCES, INDEX,
  CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE
ON `{NAME}`.* TO `{ADMIN}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Assign grant priviledge for read-only account then drop it
GRANT USAGE ON *.* TO `{RO}`@`{SERVER}`;
DROP USER `{RO}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Create a default read-only user and assign limited permissions
CREATE USER `{RO}`@`{SERVER}` IDENTIFIED BY '{RO_PW}';
GRANT SELECT, REFERENCES, INDEX, LOCK TABLES,
  EXECUTE
ON `{NAME}`.* TO `{RO}`@`{SERVER}`;
FLUSH PRIVILEGES;

-- Switch to newly created db context
USE `{NAME}`;

-- Server table for managed servers
DROP TABLE IF EXISTS `servers`;
CREATE TABLE `servers` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `address` CHAR(128) NOT NULL,
  `description` LONGTEXT NOT NULL,
  `secret` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`hostname`),
  INDEX(`hostname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Global configuration per server
DROP TABLE IF EXISTS `options`;
CREATE TABLE `options` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `option` CHAR(128) NOT NULL,
  `value` CHAR(255) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX(`hostname`),
  CONSTRAINT `fk_options2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Interface list per server
DROP TABLE IF EXISTS `interfaces`;
CREATE TABLE `interfaces` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `iface` CHAR(16) NOT NULL,
  `hwaddr` CHAR(32) NOT NULL,
  `mask` CHAR(64) NOT NULL,
  `broadcast` CHAR(64) NOT NULL,
  `ipv4` CHAR(32) NOT NULL,
  `ipv6` CHAR(64) NOT NULL,
  `route` CHAR(32) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  INDEX (`iface`),
  CONSTRAINT `fk_interfaces2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Traffic per adapter table
DROP TABLE IF EXISTS `traffic`;
CREATE TABLE `traffic` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `iface` CHAR(16) NOT NULL,
  `type` CHAR(64) NOT NULL,
  `ts` INT(8) NOT NULL,
  `hardware` CHAR(32) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`iface`),
  CONSTRAINT `fk_traffic2interfaces` FOREIGN KEY (`iface`)
    REFERENCES `interfaces` (`iface`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Failover table
DROP TABLE IF EXISTS `failover`;
CREATE TABLE `failover` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `peer` CHAR(32) NOT NULL,
  `type` CHAR(45) NOT NULL,
  `address` CHAR(128) NOT NULL,
  `port` INT(6) NOT NULL,
  `delay` INT(6) NOT NULL,
  `min` INT(6) NOT NULL,
  `max` INT(10) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  CONSTRAINT `fk_failover2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- DNSSEC keys table
DROP TABLE IF EXISTS `dnssec_keys`;
CREATE TABLE `dnssec_keys` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `keyname` CHAR(64) NOT NULL,
  `algorithm` CHAR(128) NOT NULL,
  `secret` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  INDEX(`keyname`),
  CONSTRAINT `fk_dnssec_keys2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- DNS zones table
DROP TABLE IF EXISTS `dns_zones`;
CREATE TABLE `dns_zones` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `zone` CHAR(128) NOT NULL,
  `address` CHAR(64) NOT NULL,
  `keyname` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`, `keyname`),
  CONSTRAINT `fk_dns_zones2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_dns_zones2dnssec_keys` FOREIGN KEY (`keyname`)
    REFERENCES `dnssec_keys` (`keyname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- DNS servers
DROP TABLE IF EXISTS `dns_servers`;
CREATE TABLE `dns_servers` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `dns` CHAR(32) NOT NULL,
  `address` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  INDEX (`dns`),
  CONSTRAINT `fk_dns2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Routes
DROP TABLE IF EXISTS `routes`;
CREATE TABLE `routes` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `route` CHAR(32) NOT NULL,
  `address` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  INDEX (`route`),
  CONSTRAINT `fk_routes2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Groups table
DROP TABLE IF EXISTS `groups`;
CREATE TABLE `groups` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `group` CHAR(128) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  INDEX (`group`),
  CONSTRAINT `fk_groups2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Pools table
DROP TABLE IF EXISTS `pools`;
CREATE TABLE `pools` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `pool` CHAR(64) NOT NULL,
  `min` CHAR(128) NOT NULL,
  `max` CHAR(128) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  CONSTRAINT `fk_pools2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Subnets table
DROP TABLE IF EXISTS `subnets`;
CREATE TABLE `subnets` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `subnet` CHAR(128) NOT NULL,
  `address` CHAR(32) NOT NULL,
  `mask` CHAR(32) NOT NULL,
  `dns` CHAR(32) NOT NULL,
  `route` CHAR(32) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`hostname`),
  INDEX (`subnet`),
  INDEX (`dns`),
  INDEX (`route`),
  CONSTRAINT `fk_subnets2servers` FOREIGN KEY (`hostname`)
    REFERENCES `servers` (`hostname`)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_subnets2dns_servers` FOREIGN KEY (`dns`)
    REFERENCES `dns_servers` (`dns`)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_subnets2routes` FOREIGN KEY (`route`)
    REFERENCES `routes` (`route`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Static hosts table
DROP TABLE IF EXISTS `hosts`;
CREATE TABLE `hosts` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `hostname` CHAR(64) NOT NULL,
  `address` CHAR(32) NOT NULL,
  `hardware-address` CHAR(32) NOT NULL,
  `subnet` CHAR(128) NOT NULL,
  `group` CHAR(128) NOT NULL,
  `lease` INT(1) NOT NULL,
  `notes` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`hostname`,`address`,`hardware-address`),
  INDEX (`hostname`),
  INDEX (`group`),
  CONSTRAINT `fk_hosts2subnet` FOREIGN KEY (`subnet`)
   REFERENCES `subnets` (`subnet`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_hosts2group` FOREIGN KEY (`group`)
   REFERENCES `groups` (`group`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new keyring table
DROP TABLE IF EXISTS `keyring`;
CREATE TABLE IF NOT EXISTS `keyring` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create credentials table
DROP TABLE IF EXISTS `credentials`;
CREATE TABLE IF NOT EXISTS `credentials` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `email` LONGTEXT NOT NULL,
  `passphrase` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_credentials2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new private keys table
DROP TABLE IF EXISTS `privatekeys`;
CREATE TABLE IF NOT EXISTS `privatekeys` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `private` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_privatekeys2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new public keys table
DROP TABLE IF EXISTS `publickeys`;
CREATE TABLE IF NOT EXISTS `publickeys` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `public` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_publickeys2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new certificates table
DROP TABLE IF EXISTS `certificates`;
CREATE TABLE IF NOT EXISTS `certificates` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `certificate` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_certificates2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new trusted table
DROP TABLE IF EXISTS `trusts`;
CREATE TABLE IF NOT EXISTS `trusts` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `trusted` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_trusts2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring`(`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create revoked table
DROP TABLE IF EXISTS `escrow`;
CREATE TABLE IF NOT EXISTS `escrow` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  FOREIGN KEY `fk_escrow2keyring` (`keyID`)
    REFERENCES `keyring`(`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new native session handling table (native sessions)
DROP TABLE IF EXISTS `native_sessions`;
CREATE TABLE IF NOT EXISTS `native_sessions` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `sessionID` CHAR(255) NOT NULL,
  `sessionData` LONGTEXT NOT NULL,
  `sessionExpire` INT(10) NOT NULL,
  `sessionAgent` CHAR(40) DEFAULT NULL,
  `sessionIP` CHAR(40) DEFAULT NULL,
  `sessionReferer` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sessionID` (`sessionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new session handling table (connect-mysql session store)
DROP TABLE IF EXISTS `sessions`;
CREATE TABLE IF NOT EXISTS `sessions` (
  `sid` VARCHAR(255) NOT NULL,
  `session` TEXT NOT NULL,
  `expires` INT,
  PRIMARY KEY (`sid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- Drop & create tokens table
DROP TABLE IF EXISTS `tokens`;
CREATE TABLE IF NOT EXISTS `tokens` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `sessionID` CHAR(255) NOT NULL,
  `token` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`keyID`),
  INDEX (`sessionID`),
  CONSTRAINT `fk_tokens2credentials` FOREIGN KEY (`keyID`)
    REFERENCES `credentials` (`keyID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE,
  CONSTRAINT `fk_tokens2sessions` FOREIGN KEY (`sessionID`)
    REFERENCES `native_sessions` (`sessionID`)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create new logging table
DROP TABLE IF EXISTS `logs`;
CREATE TABLE IF NOT EXISTS `logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `datetime` BIGINT(10) NOT NULL,
  `type` CHAR(255) NOT NULL,
  `clientIP` LONGTEXT NOT NULL,
  `clientAgent` LONGTEXT NOT NULL,
  `clientReferer` LONGTEXT NOT NULL,
  `clientRequest` LONGTEXT NOT NULL,
  `clientData` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Manage CORS whitelist for API
DROP TABLE IF EXISTS `cors`;
CREATE TABLE IF NOT EXISTS `cors` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `application` CHAR(255) NOT NULL,
  `token` CHAR(255) NOT NULL,
  `url` LONGTEXT NOT NULL,
  `ip` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`application`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create a new table to handle object permissions
DROP TABLE IF EXISTS `resources`;
CREATE TABLE IF NOT EXISTS `resources` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `objectName` CHAR(128) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `keyID` (`keyID`),
  CONSTRAINT `fk_resources2keyring` FOREIGN KEY (`keyID`)
    REFERENCES `keyring` (`keyID`)
      ON DELETE CASCADE
      ON UPDATE CASCADE
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create a new table to handle permissions per group
DROP TABLE IF EXISTS `resources_groups`;
CREATE TABLE IF NOT EXISTS `resources_groups` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `groupID` LONGTEXT NOT NULL,
  `read` TINYINT(1) NOT NULL,
  `write` TINYINT(1) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`keyID`),
  CONSTRAINT `fk_resources_grps2resources` FOREIGN KEY (`keyID`)
    REFERENCES `resources` (`keyID`)
      ON DELETE CASCADE
      ON UPDATE CASCADE
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- Drop & create a new table to handle permissions per user
DROP TABLE IF EXISTS `resources_users`;
CREATE TABLE IF NOT EXISTS `resources_users` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `keyID` CHAR(128) NOT NULL,
  `userID` LONGTEXT NOT NULL,
  `read` TINYINT(1) NOT NULL,
  `write` TINYINT(1) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX (`keyID`),
  CONSTRAINT `fk_resources_usrs2resources` FOREIGN KEY (`keyID`)
    REFERENCES `resources` (`keyID`)
      ON DELETE CASCADE
      ON UPDATE CASCADE
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;

-- View for keyring entries
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewKeyring AS
 SELECT k.id AS Id, k.keyID AS KeyID, a.email AS Email,
        a.passphrase AS Password, p.private AS PrivateKey,
        pk.public AS PublicKey, c.certificate AS Certificate,
        t.trusted AS Trusts
  FROM keyring k
  LEFT JOIN credentials a ON k.keyID = a.keyID
  LEFT JOIN privatekeys p ON k.keyID = p.keyID
  LEFT JOIN publickeys pk ON k.keyID = pk.keyID
  LEFT JOIN certificates c ON k.keyID = c.keyID
  LEFT JOIN trusts t ON k.keyID = t.keyID
  WHERE k.keyID NOT IN (SELECT keyID FROM escrow)
  ORDER BY k.keyID;

-- View for authenticted sessions
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewSessions AS
 SELECT id AS Id, sessionID AS SessionID, sessionData AS SessionData,
        sessionExpire AS Expires, sessionAgent AS Agent, sessionIP AS IpAddress,
        sessionReferer AS Referer
  FROM native_sessions
  ORDER BY id;

-- View for server list
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewServers AS
 SELECT s.id AS Id, s.hostname AS Hostname, s.address AS Address,
        s.description AS Description, o.option AS 'Option',
        o.value AS 'Value'
  FROM servers s
  LEFT JOIN options o ON s.hostname = o.hostname
  ORDER BY s.hostname;

-- View for Server details
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewServersDetails AS
 SELECT s.id AS Id, s.hostname AS Hostname, i.iface AS Interface,
        i.hwaddr AS HWAddr, i.ipv4 AS IPv4, i.ipv6 AS IPv6,
        i.mask AS SubnetMask, i.broadcast AS Broadcast,
        i.route AS Route
  FROM servers s
  LEFT JOIN interfaces i ON s.hostname = i.hostname
  ORDER BY s.hostname;

-- View for Interface traffic details
CREATE OR REPLACE DEFINER='{RO}'@'{SERVER}'
 SQL SECURITY INVOKER
VIEW viewTraffic AS
 SELECT i.id AS Id, i.hostname AS Hostname, i.iface AS Interface,
        i.hwaddr AS HWAddr, i.ipv4 AS IPv4, i.ipv6 AS IPv6,
        i.mask AS SubnetMask,  i.broadcast AS Broadcast, i.route AS Route,
        t.type AS Type,  t.ts AS Timestamp, t.hardware AS MAC
  FROM interfaces i
  LEFT JOIN traffic t ON i.iface = t.iface
  ORDER BY i.hostname;