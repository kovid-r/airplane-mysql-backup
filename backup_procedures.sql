DROP PROCEDURE IF EXISTS classicmodels.table_backup; 
DELIMITER $$
CREATE PROCEDURE classicmodels.table_backup (tablename VARCHAR(255))
BEGIN
	
SET @tablename := (SELECT tablename);
SET @exportpath = CONCAT(@tablename,'.csv');

SET @query := CONCAT("SELECT * INTO OUTFILE '", @exportpath, "' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' FROM classicmodels.", @tablename);

PREPARE statement FROM @query;
EXECUTE statement;
DEALLOCATE PREPARE statement;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS classicmodels.database_backup;
DELIMITER $$
CREATE PROCEDURE classicmodels.database_backup ()
BEGIN
    
    DECLARE done int default false;
    DECLARE tn varchar(255);

    DECLARE cur CURSOR FOR SELECT table_name FROM information_schema.tables WHERE table_schema = 'classicmodels';

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET done = TRUE;

    OPEN cur;

    backup: LOOP
        FETCH cur INTO tn;
        IF done THEN
            LEAVE backup;
        END IF;

		CALL classicmodels.table_backup(tn);

    END LOOP;
    CLOSE cur;

END $$
DELIMITER ;
