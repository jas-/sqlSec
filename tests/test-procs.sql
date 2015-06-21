USE {NAME};

DELIMITER //

-- Populate the shematic fields with bogus test data
DROP PROCEDURE IF EXISTS sqlSec_DBG_FP//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DBG_FP(IN i INT(255))
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Populate the database with bogus records of n count'
BEGIN

 DECLARE uid CHAR(128);

 SET foreign_key_checks = 0;

 CALL sqlSec_GK(@Secret);

 BLOCK1: begin
  WHILE i > 0 DO

   SET @uid = SHA1(LEFT(UUID(), 8)+RAND());

   SET @check = CONCAT('SELECT COUNT(*) INTO @chk FROM `keyring` WHERE `keyID` = "',@uid,'"');
   PREPARE stmt FROM @check;
   EXECUTE stmt;
   DEALLOCATE PREPARE stmt;

   IF (@chk = 0) THEN
     SET @debug = CONCAT('#',i,': keyring.keyID = "',@uid,'"');
     SELECT @debug AS AddingToKeyring;

     SET @sql = CONCAT('INSERT INTO `keyring` (`keyID`) VALUES ("',@uid,'")');
     PREPARE stmt FROM @sql;
     EXECUTE stmt;
     DEALLOCATE PREPARE stmt;

     CALL sqlSec_DBG_FP1(@uid, @Secret);
     SET i = i - 1;
   END IF;

  END WHILE;
 end BLOCK1;

 SET foreign_key_checks = 1;
END//

-- Populate the shematic fields with bogus test data helper
DROP PROCEDURE IF EXISTS sqlSec_DBG_FP1//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DBG_FP1(IN UID CHAR(128), IN Secret LONGTEXT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Populate the database with bogus records helper'
BEGIN

 DECLARE c INT DEFAULT 0;

 DECLARE tb CHAR(16) DEFAULT NULL;
 DECLARE fld CHAR(32) DEFAULT NULL;

 DECLARE ops CURSOR FOR SELECT `tbl`,`field` FROM `sqlSec_map`;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET c = 1;

 IF (Secret IS NOT NULL) THEN
  OPEN ops;
   LOOP1: loop
    FETCH ops INTO tb, fld;

    SET foreign_key_checks = 0;
    SET @Value = sqlSec_GS();

    SET @debug = CONCAT('keyID: ',UID,' -> ',tb,'.',fld,' = "',@Value,'"');

    SET @check = CONCAT('SELECT COUNT(*) INTO @chk FROM `',tb,'` WHERE `keyID` = "',UID,'"');
    PREPARE stmt FROM @check;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF (@chk > 0) THEN
      SET @sql = CONCAT('UPDATE `',tb,'` SET `',fld,'` = HEX(AES_ENCRYPT("',@Value,'", SHA1("',Secret,'"))) WHERE `keyID` = "',UID,'"');
    ELSE
      SET @sql = CONCAT('INSERT INTO `',tb,'` (`keyID`, `',fld,'`) VALUES ("',UID,'", HEX(AES_ENCRYPT("',@Value,'", SHA1("',Secret,'"))))');
    END IF;

    SELECT @sql AS Statement;

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET foreign_key_checks = 1;

    IF c THEN
     CLOSE ops;
     LEAVE LOOP1;
    END IF;

  END LOOP LOOP1;
 END IF;

END//

-- Performs automated testing of key & encrypted data rotations
DROP PROCEDURE IF EXISTS sqlSec_DBG_Test//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DBG_Test(IN i INT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Invoke rotation procedure while printing out current key'
BEGIN
 WHILE i > 0 DO
  CALL sqlSec_GK(@S);
  SELECT @S AS CurrentKey;
  CALL sqlSec_Main(1, 1);
  CALL sqlSec_GK(@K);
  SELECT @K AS NewlyCreatedKey;
  SET i = i - 1;
 END WHILE;
END//

-- Get counts & totals from tables
DROP PROCEDURE IF EXISTS sqlSec_DBG_Total//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DBG_Total()
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Get all table counts & total'
BEGIN

END//

DELIMITER ;