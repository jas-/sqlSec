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
 SET foreign_key_checks = 0;

 CALL sqlSec_GK(@Secret);
 BLOCK1: begin
  WHILE i > 0 DO

   SET @Random1 = UUID();
   SET @Random2 = sqlSec_GS();

   SET @debug = CONCAT('keyring.keyID = "',@Random1,'"');
   SELECT @debug AS AddingToKeyring;

--   SET @sql = CONCAT('INSERT INTO `keyring` (`keyID`) VALUES ("',@Random1,'") ON DUPLICATE KEY UPDATE `keyID` = "',@Random2,'"');
   SET @sql = CONCAT('INSERT INTO `keyring` (`keyID`) VALUES ("',@Random1,'")');
   PREPARE stmt FROM @sql;
   EXECUTE stmt;
   DEALLOCATE PREPARE stmt;

   CALL sqlSec_DBG_FP1(@Random1, @Random2, @Secret);
   SET i = i - 1;
  END WHILE;
 end BLOCK1;

 SET foreign_key_checks = 1;
END//

-- Populate the shematic fields with bogus test data helper
DROP PROCEDURE IF EXISTS sqlSec_DBG_FP1//
CREATE DEFINER='{SP}'@'{SERVER}' PROCEDURE sqlSec_DBG_FP1(IN Random1 CHAR(128), IN Random2 CHAR(128), IN Secret LONGTEXT)
 DETERMINISTIC
 MODIFIES SQL DATA
 SQL SECURITY INVOKER
 COMMENT 'Populate the database with bogus records helper'
BEGIN

 DECLARE c INT DEFAULT 0;

 DECLARE t CHAR(16) DEFAULT NULL;
 DECLARE f CHAR(32) DEFAULT NULL;

 DECLARE ops CURSOR FOR SELECT `tbl`,`field` FROM `sqlSec_map`;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET c = 1;

 IF (Secret IS NOT NULL) THEN
  OPEN ops;
   LOOP1: loop
    FETCH ops INTO t, f;

-- Add method of picking all like table fields to create insert to help with unique fields

    SET foreign_key_checks = 0;
    SET @Random2 = sqlSec_GS();

    SET @debug = CONCAT('keyID: ',Random1,' -> ',t,'.',f,' = "',@Random2,'"');
    SELECT @debug AS AddingValue;

--    SET @sql = CONCAT('INSERT INTO `',t,'` (`keyID`, `',f,'`) VALUES ("',Random1,'", HEX(AES_ENCRYPT("',@Random2,'", SHA1("',Secret,'")))) ON DUPLICATE KEY UPDATE `keyID` = "',Random2,'", `',f,'` = HEX(AES_ENCRYPT("',@Random2,'", SHA1("',Secret,'")))');
    SET @sql = CONCAT('INSERT INTO `',t,'` (`keyID`, `',f,'`) VALUES ("',Random1,'", HEX(AES_ENCRYPT("',@Random2,'", SHA1("',Secret,'"))))');
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