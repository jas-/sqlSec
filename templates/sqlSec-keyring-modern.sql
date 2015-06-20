DELIMITER //

DROP FUNCTION IF EXISTS sqlSec_GS//
CREATE DEFINER='{SP}'@'{SERVER}' FUNCTION sqlSec_GS() RETURNS varchar(255) CHARSET utf8
 DETERMINISTIC
 SQL SECURITY INVOKER
 COMMENT 'Creates and returns a random value'
BEGIN
  RETURN SHA1(LEFT(UUID(), 8)+RAND()+CURRENT_TIMESTAMP());
END//

DELIMITER ;
