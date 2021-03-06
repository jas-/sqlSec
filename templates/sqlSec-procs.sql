DELIMITER //

-- Main key & data rotation procedure
DROP PROCEDURE IF EXISTS sqlSec_Main//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_Main(IN backup BOOLEAN, IN debug BOOLEAN)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Decrypts, rotates encryption keys & re-encrypts data'
BEGIN
 BLOCK1: begin
  DECLARE c BOOLEAN DEFAULT FALSE;

  DECLARE t CHAR(16) DEFAULT NULL;
  DECLARE f CHAR(32) DEFAULT NULL;

  DECLARE ops CURSOR FOR SELECT `tbl`,`field` FROM `sqlSec_map`;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET c = TRUE;

  CALL sqlSec_GK(@oldSecret);

  IF (@oldSecret IS NOT NULL) THEN
   IF (backup > 0) THEN
    CALL sqlSec_BU(@oldSecret);
   END IF;
   OPEN ops;
   CALL sqlSec_DT("processing");
   CALL sqlSec_GT;
   read_loop: LOOP
    FETCH ops INTO t, f;
    IF c THEN
     CLOSE ops;
     LEAVE read_loop;
    END IF;
    SET @rand = CONCAT(t,'_',SUBSTR(SHA1(RAND()), 4, 8));
    CALL sqlSec_CV(t, f, @oldSecret, @rand);
    CALL sqlSec_PT(@rand);
    CALL sqlSec_DV(@rand);
   END LOOP;
   SET @newSecret = sqlSec_GS();
   CALL sqlSec_SV(@newSecret);
   CALL sqlSec_RP(@newSecret, debug);
   CALL sqlSec_DT("processing");
  END IF;
 end BLOCK1;
END//

-- Re-encrypts data from temporary table and saves in original table/field
DROP PROCEDURE IF EXISTS sqlSec_RP//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_RP(IN Secret LONGTEXT, IN debug BOOLEAN)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Re-encrypts data with new encryption key'
BEGIN
 DECLARE c BOOLEAN DEFAULT FALSE;
 DECLARE i INT(255) DEFAULT FALSE;
 DECLARE t CHAR(16) DEFAULT FALSE;
 DECLARE f CHAR(32) DEFAULT FALSE;
 DECLARE v LONGTEXT DEFAULT FALSE;

 DECLARE ops CURSOR FOR SELECT * FROM `processing`;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET c = TRUE;

 SET foreign_key_checks = 0;

 IF (Secret IS NOT NULL) THEN
  OPEN ops;
  CALL sqlSec_GT;
  read_loop: LOOP
   FETCH ops INTO i, t, f, v;
   IF c THEN
    CLOSE ops;
    LEAVE read_loop;
   END IF;
   SET @sql = CONCAT('UPDATE `',t,'` SET `',f,'` = HEX(AES_ENCRYPT("',v,'", SHA1("',Secret,'"))) WHERE `id` = "',i,'"');
   PREPARE stmt FROM @sql;
   EXECUTE stmt;
   DEALLOCATE PREPARE stmt;

   IF (debug > 0) THEN
    SELECT i AS RecordID, t AS TableName, f AS FieldName, v AS DecryptedValue;
   END IF;

  END LOOP;
 END IF;
 SET foreign_key_checks = 1;
END//

-- Create backup for new records
DROP PROCEDURE IF EXISTS sqlSec_BU_New//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_BU_New(IN Secret LONGTEXT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Backup old data prior for new installations'
BEGIN
 CALL sqlSec_BU(Secret);
END//

-- Create new record set procedure
DROP PROCEDURE IF EXISTS sqlSec_New//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_New(IN t CHAR(16), IN f CHAR(32), IN s LONGTEXT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Decrypts existing data'
BEGIN

 IF (s != '') THEN
  SET @sql = CONCAT('CREATE OR REPLACE VIEW sqlSec_NEW AS SELECT `id`, "',t,'" AS tbl, "',f,'" AS fld, AES_DECRYPT(BINARY(UNHEX(`',f,'`)), SHA1("',s,'")) AS val FROM `',t,'` WHERE `',f,'` != ""');
 ELSE
  SET @sql = CONCAT('CREATE OR REPLACE VIEW sqlSec_NEW AS SELECT `id`, "',t,'" AS tbl, "',f,'" AS fld, `',f,'` AS val FROM `',t,'` WHERE `',f,'` != ""');
 END IF;

 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;

 CALL sqlSec_DT('processing');
 CALL sqlSec_GT;
 CALL sqlSec_PT('sqlSec_NEW');
 CALL sqlSec_GK(@Secret);
 IF (@Secret IS NOT NULL) THEN
  CALL sqlSec_RP(@Secret, 1);
 END IF;
 CALL sqlSec_DT("processing");
 CALL sqlSec_DV('sqlSec_NEW');

END//

-- Create view procedure
DROP PROCEDURE IF EXISTS sqlSec_CV//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_CV(IN t CHAR(16), IN f CHAR(32), IN Secret LONGTEXT, IN rnd CHAR(128))
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Creates view'
BEGIN
 SET @sql = CONCAT('CREATE OR REPLACE VIEW ',rnd,' AS SELECT `id`, "',t,'" AS tbl, "',f,'" AS fld, AES_DECRYPT(BINARY(UNHEX(`',f,'`)), SHA1("',Secret,'")) AS val FROM `',t,'` WHERE `',f,'` != ""');
 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
END//

-- Delete view procedure
DROP PROCEDURE IF EXISTS sqlSec_DV//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DV(IN rnd CHAR(64))
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Drops view'
BEGIN
 SET @sql = CONCAT('DROP VIEW IF EXISTS ',rnd);
 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
END//

-- Populate processing table from view
DROP PROCEDURE IF EXISTS sqlSec_PT//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_PT(IN rnd CHAR(128))
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Populates processing table from view'
BEGIN
 SET @sql = CONCAT('INSERT INTO `processing` SELECT * FROM `',rnd,'`');
 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
END//

-- Generates temporary tables for view(s)
DROP PROCEDURE IF EXISTS sqlSec_GT//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_GT()
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Generates temporary tables for view reference exceptions'
BEGIN
 CREATE TEMPORARY TABLE IF NOT EXISTS `processing`(
  `id` BIGINT NOT NULL,
  `tbl` CHAR(16) NOT NULL,
  `fld` CHAR(32) NOT NULL,
  `val` LONGTEXT NOT NULL
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci AUTO_INCREMENT=0;
END//

-- Drops temporary table
DROP PROCEDURE IF EXISTS sqlSec_DT//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DT(IN tbl CHAR(16))
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Drop specified table'
BEGIN
 SET @sql = CONCAT('DROP TABLE IF EXISTS ',tbl,'');
 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
END//

-- Retrieve this months key
DROP PROCEDURE IF EXISTS sqlSec_GK//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_GK(OUT OutSecret CHAR(128))
 DETERMINISTIC
 SQL SECURITY INVOKER
 COMMENT 'Attempts to retrieve this months key'
BEGIN
 SELECT MAX(`id`) FROM `sqlSec_settings` INTO @id;
 SET @sql = CONCAT('SELECT SHA1(CONCAT(SHA1(`epoch`), SHA1(`keyID`))) INTO @Secret FROM `sqlSec_settings` WHERE `epoch` >= (UNIX_TIMESTAMP(NOW())-2678400) AND `epoch` <= UNIX_TIMESTAMP(NOW()) AND `id` = "',@id,'"');
 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
 IF (@Secret IS NOT NULL) THEN
  SET OutSecret = SHA1(@Secret);
 ELSE
  SELECT 0 AS error;
 END IF;
END//

-- Save new encryption key
DROP PROCEDURE IF EXISTS sqlSec_SV//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_SV(IN Secret LONGTEXT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Saves newly generated encryption key'
BEGIN
 SET @sql = CONCAT('INSERT INTO `sqlSec_settings` (`version`, `epoch`, `keyID`) VALUE ("{VER}", UNIX_TIMESTAMP(NOW()), "',Secret,'") ON DUPLICATE KEY UPDATE `keyID`="',Secret,'"');
 PREPARE stmt FROM @sql;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
 CALL sqlSec_GK(@newSecret);
END//

-- Performs backup of all tables prior to key rotation procedure (helps ensure no data loss)
DROP PROCEDURE IF EXISTS sqlSec_BU//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_BU(IN Secret LONGTEXT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Backs up all tables prior to key rotation process'
BEGIN
 DECLARE c BOOLEAN DEFAULT FALSE;

 DECLARE t CHAR(32) DEFAULT NULL;
 DECLARE fName CHAR(255) DEFAULT NULL;

 DECLARE ops CURSOR FOR SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema = "{NAME}";
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET c = TRUE;

 IF (Secret IS NOT NULL) THEN
  SET @sql = CONCAT('SELECT "',Secret,'" INTO OUTFILE "{BUF}/BACKUP-',UNIX_TIMESTAMP(NOW()),'-SECRET.sql"');
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
 END IF;

 OPEN ops;

 LOOP1: loop
  FETCH ops INTO t;

  IF c THEN
   CLOSE ops;
   LEAVE LOOP1;
  END IF;

  SET fName = CONCAT('{BUF}/BACKUP-',UNIX_TIMESTAMP(NOW()),'-',t,'.sql');

  SET @sql = CONCAT('SELECT * INTO OUTFILE "',fName,'" FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY "\'" LINES TERMINATED BY "\n" FROM `',t,'`');
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

 END LOOP LOOP1;
END//

DELIMITER ;
