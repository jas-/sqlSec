#!/usr/bin/php

<?php

/**
 * LICENSE: This source file is subject to version 3.01 of the GPL license
 * that is available through the world-wide-web at the following URI:
 * http://www.gnu.org/licenses/gpl.html.  If you did not receive a copy of
 * the GPL License and are unable to obtain it through the web, please
 *
 * @author     jason.gerfen@gmail.com
 * @copyright  2008-2012 Jason Gerfen
 * @license    http://www.gnu.org/licenses/gpl.html  GPL License 3
 * @version    0.3
 */

/* Disable error reporting */
error_reporting(0);

/* Ensure we are running as UID 0 */
if (strcmp(getenv("USER"), 'root') !== 0) {
    _help(true);
}

/* Call help if asked */
if ($argc < 3 || in_array($argv[1], array('--help', '-h', '-?'))) {
    _help();
} else {
    define('__SITE', realpath(dirname(__FILE__)));

    /* Begin installation */
    if (($i = _open('sqlSec-schema.sql')) !== false) {

        /* Create a random user & password for stored procedures */
        $argv[3] = _genKey(8);//<- Username
        $argv[4] = _genKey(12);//<- Password

        /* Generate a random hash to be used during key extraction prior to encryption process */
        $argv[5] = openssl::genRand(64);

        $i = _replace($i, $argv);

        $p = _mask();
        if (file_exists('libs/class.mysql.php')) {

            /* create database connection with supplied permissions */
            include_once('libs/class.mysql.php');
            $db = new mysqlDBconn(array('dbuser'=>'root','dbhost'=>$argv[1],'dbname'=>$argv[2],'dbpass'=>$p));

            /* Get MySQL data directory path */
            $x = $db->query('show variables like "%datadir%"');

            /* Append MySQL DB path information to options array */
            $argv[6] = $x['Value'].$argv[2]."/";

            /* Cleanup any files in MySQL data dir */
            _clean($argv[6]);

            /* proceed to create database, user, permissions & tables */
            try {
                $r = $db->query($i);
                echo "Successfully created new user account\n";
                echo "Successfully created tables to ".$argv[2]."\n";
            } catch(PDOException $e) {
                exit("An error occured while executing MySQL database creation\n");
            }

            /* Create a backup directory */
            _create_bu($argv[6]);
            _create_bu('/tmp/');

            /* Permissions on backup directory */
            _perms($argv);

            /* proceed to import stored procedures, functions & scheduled event(s) */
            _load('sqlSec-procs.sql', $p, $argv);

            echo "sqlSec installation details:\n";
            echo "\tUsername: ".$argv[3]."\n";
            echo "\tPassword: ".$argv[4]."\n";
            echo "\tBackup path: ".$argv[6]."\n";
            echo "\n";
            echo "Lets define the table & fields you wish to store encrypted data in...\n";
            _loop($db);
        } else {
            exit("The MySQL database class is missing, please re-install sqlSec package\n");
        }

    } else {
        exit("An error occured opening database schema SQL data file\n");
    }
}
exit(0);

/*
 * Display help information
 */
function _help($user = false)
{
    if ($user) echo "Error: Must be root\n\n";
    echo "dbSec installer\n";
    echo "\n";
    echo "Usage: \n";
    echo "\t./install.php hostname database\n";
    exit(0);
}

/*
 * Generate new key
 */
function _genKey($len = 64)
{
    include_once('libs/class.openssl.php');
    return openssl::genRand($len);
}

/*
 * Handle opening of installation file
 * Returns current contents of file
 */
function _open($file)
{
    if (file_exists($file)) {
        return file_get_contents($file);
    } else {
        return false;
    }
}

/*
 * Loop used to define data sets
 */
function _loop($db)
{
    $e = true;

    echo "\tAlready using encrypted fields? ";
    $a = rtrim(fgets(STDIN));
    if (preg_match('/y|yes/', $a)) {
        echo "Enter decryption key: ";
        $k = rtrim(fgets(STDIN));
    } else {
        $k = NULL;
    }

    echo "\tCreate backup first? ";
    $b = rtrim(fgets(STDIN));
    if (preg_match('/y|yes/', $b)) {
        try {
            $s = sprintf('CALL KR_BU_New("%s")', $k);
            $r = $db->query($s);
        } catch(PDOException $e) {
            exit("An error occured while adding ".$t." => ".$f." record\n");
        }
    }

    while ($e) {
        echo "\tEnter table: ";
        $t = rtrim(fgets(STDIN));
        echo "\tEnter field: ";
        $f = rtrim(fgets(STDIN));

        try {
            $s = sprintf('INSERT INTO `sqlSec_map` (`tbl`,`field`) VALUES ("%s", "%s")', $t, $f);
            $r = $db->query($s);
        } catch(PDOException $e) {
            exit("An error occured while adding ".$t." => ".$f." record\n");
        }

        echo "\tAnother record? ";
        $n = rtrim(fgets(STDIN));
        if (preg_match('/n|no/', $n)) {
            $e = false;
        }
    }

    try {
        $s = sprintf('CALL KR_New("%s", "%s", "%s")', $t, $f, $k);
        $r = $db->query($s);
    } catch(PDOException $e) {
        exit("An error occured while adding ".$t." => ".$f." record\n");
    }
}

/*
 * Handle replacements on user supplied arguments
 * Returns importable SQL data
 */
function _replace($data, $args)
{
    $data = str_replace('[dbVer]', 'v0.1', $data);
    $data = str_replace('[dbHost]', $args[1], $data);
    $data = str_replace('[dbName]', $args[2], $data);
    $data = str_replace('[dbUser]', $args[3], $data);
    $data = str_replace('[dbPass]', $args[4], $data);
    $data = str_replace('[dbKey]', $args[5], $data);
    $data = str_replace('[dbPath]', $args[6], $data);
    return $data;
}

/*
 * Handle writing of modified stored procedure file(s)
 * in order to properly import due to limitations
 * with PHP's and MySQL's inability to do so
 * using pipe's, redirects &/or queries
 */
function _write($file, $data)
{
    $h = fopen($file, 'w+');
    if ($h) {
        fwrite($h, $data);
        fflush($h);
        fclose($h);
        return true;
    }
    return false;
}

/*
 * Mask user input for MySQL root password prompt
 */
function _mask($p = "Enter MySQL root password: ")
{
    $c = "/usr/bin/env bash -c 'read -s -p \"". addslashes($p). "\" mypass && echo \$mypass'";
    $pass = rtrim(shell_exec($c));
    echo "\n";
    return $pass;
}

/*
 * Force importing of stored procedures using mysql import
 */
function _sp($pass, $db, $file)
{
    return sprintf("/usr/bin/env bash -c '/usr/bin/mysql -u root --password=%s --database %s < %s &2>/dev/null'", $pass, $db, $file);
}

/*
 * Load specified SQL file
 */
function _load($file, $p, $argv)
{
    if (file_exists($file)) {
        if (($i = _open($file)) !== false) {
            $i = _replace($i, $argv);

            if (_write('temporary-procedures.sql', $i)) {
                $c = _sp($p, $argv[2], 'temporary-procedures.sql');
                $e = `$c`;

                unlink('temporary-procedures.sql');
                echo "Successfully created stored procedures from '".$file."'\n";
                return true;
            } else {
                exit("An error occured while writting modified stored procedure information to file\n");
            }
        } else {
            exit("An error occured opening the stored procedures SQL data file\n");
        }
    }
}

/* Create backup directory */
function _create_bu($dir)
{
    if (!is_dir($dir)) {
        mkdir($dir.'/backups/');
    }
}

/* Handle permissions on key file */
function _perms($argv)
{
    /* Set keys permissions to the mysql running user */
    if (file_exists('/etc/my.cnf')) {
        $m = file_get_contents('/etc/my.cnf');
    } elseif(file_exists('/etc/mysql/my.cnf')) {
        $m = file_get_contents('/etc/mysql/my.cnf');
    } else {
        exit('Could not retrieve MySQL running user');
    }

    preg_match('/user.*=.*(\w+)/', $m, $u);

    if (empty($u[1])) {
        $u[1] = 'mysql';
    }
    chown($argv[6].'backups/', $u[1]);
    chgrp($argv[6].'backups/', $u[1]);
}

/* Remove any extranious files within data dir */
function _clean($dir)
{
    foreach (glob($dir."*.sql") as $filename) {
        unlink($filename);
    }
}