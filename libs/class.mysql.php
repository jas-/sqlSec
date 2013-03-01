<?php

/* prevent direct access */
if (!defined('__SITE')) exit('No direct calls please...');

/**
 * Handle MySQL/MySQLi/PDO database functionality
 *
 *
 * LICENSE: This source file is subject to version 3.01 of the GPL license
 * that is available through the world-wide-web at the following URI:
 * http://www.gnu.org/licenses/gpl.html.  If you did not receive a copy of
 * the GPL License and are unable to obtain it through the web, please
 *
 * @category   database
 * @discussion Provide single interface for PDO/MySQLi/MySQL functionality by
 *             determining best available access method and degrade quietly
 * @author     jason.gerfen@gmail.com
 * @copyright  2008-2011 Jason Gerfen
 * @license    http://www.gnu.org/licenses/gpl.html  GPL License 3
 * @version    0.3
 */

/**
 *! @class mysqlDBconn
 *  @abstract Proxy for all available MySQL class methods
 *  @discussion Utilizes PDO/mysqli/mysql class extenders by degrading
 *              gracefully to any available method bsed on system configuration
 */
class mysqlDBconn
{
	/**
	 *! @var instance object - class singleton object
	 */
	protected static $instance;

	/**
	 *! @var flag string - used to determine class method
	 */
	private $flag='0x001';

	/**
	 *! @var dbconn object - MySQL handle object
	 */
	private $dbconn;

	/**
	 *! @function __construct
	 *  @abstract Provides MySQL object based on system configuration for accessing
	 *            PDO, MySQLi or MySQL access methods
	 *  @param configuration array - Server address, username, password, database
	 */
	public function __construct($configuration)
	{
		$this->flag = $this->decide($this->flag);
		switch($this->flag) {
			case '0x001':
				$this->dbconn = new pdoMySQL($configuration);
				return $this->dbconn;
			case '0x002':
				$this->dbconn = new dbMySQLi($configuration);
				return $this->dbconn;
			case '0x003':
				$this->dbconn = new dbMySQL($configuration);
				return $this->dbconn;
			default:
				trigger_error('The MySQL extensions are not loaded.', E_USER_ERROR);
				unset($instance);
				exit;
		}
	}

	/**
	 *! @function decide
	 *  @abstract Determines best method for MySQL functionality
	 *  @return flag string - Used to call appropriate class extension
	 */
	private function decide()
	{
		if (class_exists('PDO')) {
			$this->flag = '0x001';
		} elseif (class_exists('mysqli')) {
			$this->flag = '0x002';
		} else {
			$this->flag = '0x003';
		}
		return $this->flag;
	}

	/**
	 *! @function instance
	 *  @abstract Creates non-deserializing, non-cloneable instance object
	 *  @param configuration array - server, username, password, database
	 *  @return Singleton - Singleton object
	 */
	public static function instance($configuration)
	{
		if (!isset(self::$instance)) {
			$c = __CLASS__;
			self::$instance = new self($configuration);
		}
		return self::$instance;
	}

	/**
	 *! @function query
	 *  @abstract Proxy like class interface for PDO, MySQLi or MySQL class
	 *            extensions
	 *  @param query string - SQL query string
	 *  @return object - Last query handle
	 */
	public function query($query, $params=null) {
		return $this->dbconn->query($query, $params);
	}

	/**
	 *! @function sanitize
	 *  @abstract Proxy like class interface for string sanitation
	 *  @param string string - Dynamic variable(s) used in SQL statement
	 *  @return string - Sanitized version of $string
	 */
	public function sanitize($string) {
		return $this->dbconn->sanitize($string);
	}

	/**
	 *! @function results
	 *  @abstract Proxy like class interface for associative array results
	 *  @param link object - Object handle of query
	 *  @return array - Associative array of results
	 */
	public function results($link) {
		return $this->dbconn->results($link);
	}

	/**
	 *! @function affected
	 *  @abstract Proxy like class interface for checking number of rows affected
	 *  @param link object - Object handle of query
	 *  @return int - Number of rows affected
	 */
	public function affected($link) {
		return $this->dbconn->affected($link);
	}

	/**
	 *! @function error
	 *  @abstract Proxy like class interface for error messages
	 *  @param link object - Object handle of query
	 *  @return string - Error message returned
	 */
	public function error($link) {
		return $this->dbconn->error($link);
	}

	public function flush($link)
	{
		$this->dbconn->flush($link);
	}

	/**
	 *! @function __clone
	 *  @abstract Prevent cloning of singleton object
	 */
	public function __clone() {
		trigger_error('Cloning prohibited', E_USER_ERROR);
	}

	/**
	 *! @function __wakeup
	 *  @abstract Prevent deserialization of singleton object
	 */
	public function __wakeup() {
		trigger_error('Deserialization of singleton prohibited ...', E_USER_ERROR);
	}
}

/**
 *! @class pdoMySQL
 *  @abstract Extends class dbConn for PDO MySQL functionality
 *  @discussion Utilizes PDO for MySQL database access, queries, results etc
 */
class pdoMySQL extends mysqlDBconn
{

	/**
	 *! @var dbconn object - class singleton object
	 */
	private $dbconn;

	/**
	 *! @var configuration array - server, username, password, database
	 */
	private $configuration;

	/**
	 *! @function __construct
	 *  @abstract Creates new PDO link based on configured credentials
	 *  @param configuration array - server, username, password, database
	 *  @return object - PDO link resource
	 */
	public function __construct($configuration)
	{
		try {
			$this->dbconn = new PDO($this->createdsn($configuration), $configuration['dbuser'], $configuration['dbpass']);
		} catch(PDOException $e) {
			$this->dbconn = false;
			return false;
		}
		return $this->dbconn;
	}

	/**
	 *! @function createdsn
	 *  @abstract Format configuration settings into valid DSN for PDO connection
	 *  @param settings array - server, username, passsword, database
	 *  @return string - Valid PDO DSN connection string
	 */
	private function createdsn($settings)
	{
		return (!empty($settings['dbname'])) ? 'mysql:host='.$settings['dbhost'].';dbname='.$settings['dbname'] : 'mysql:host='.$settings['dbhost'].';';
	}

	/**
	 *! @function query
	 *  @abstract Handles PDO queries
	 *  @param query string - SQL statement
	 *  @return object - Returns SQL object
	 */
	public function query($query, $all=false)
	{
		$query = $this->dbconn->prepare($query);
		try {
			$query->execute();
			return ($all===true) ? $query->fetchAll(PDO::FETCH_ASSOC) : $query->fetch(PDO::FETCH_ASSOC);
		} catch(PDOException $e){
			return $e->getMessage();
		}
	}

	/**
	 *! @function sanitize
	 *  @abstract Sanitizes dynamic variables in SQL statement
	 *  @param string string - String or Integer variables
	 *  @return string - Returns sanitized variable
	 */
	public function sanitize($string)
	{
		return $string;
	}

	/**
	 *! @function results
	 *  @abstract Returns PDO associative array from last SQL statement
	 *  @param link object - Object handle of last query
	 *  @return array - Associative array
	 */
	public function results($link)
	{
		return $link->fetchAll(PDO::FETCH_ASSOC);
	}

	/**
	 *! @function affected
	 *  @abstract Handle affected amount of rows on last SQL statement
	 *  @param link object - Object handle of query
	 *  @return int - Number of affected rows
	 */
	public function affected($link)
	{
		return $link->rowCount();
	}

	/**
	 *! @function error
	 *  @abstract Return error message from last SQL statement
	 *  @param link object - Object handle of query
	 *  @return string - Error message returned
	 */
	public function error($link=null)
	{
		return $link->error();
	}

	public function flush($link=null)
	{
		return $this->__destruct();
	}

	/**
	 *! @function index
	 *  @abstract Executed upon destruction of class instance to perform
	 *            repair, optimize and flush commands on each table in database
	 *  @param link object - Object handle of connection
	 *  @param database string - Database name
	 */
	public function index($link, $database)
	{
		$obj = $link->query('SHOW TABLES');
		$results = $this->results($obj);
		foreach($results as $key => $value) {
			if (isset($value['Tables_in_'.$database])) {
				$this->query('REPAIR TABLE '.$value['Tables_in_'.$database]);
				$this->query('OPTIMIZE TABLE '.$value['Tables_in_'.$database]);
				$this->query('FLUSH TABLE '.$value['Tables_in_'.$database]);
			}
		}
	}

	/**
	 *! @function __clone
	 *  @abstract Prevent cloning of singleton object
	 */
	public function __clone() {
		trigger_error('Cloning prohibited', E_USER_ERROR);
	}

	/**
	 *! @function __wakeup
	 *  @abstract Prevent deserialization of singleton object
	 */
	public function __wakeup() {
		trigger_error('Deserialization of singleton prohibited ...', E_USER_ERROR);
	}

	/**
	 *! @function __destruct
	 *  @abstract Release database handle and perform index functionality
	 */
	public function __destruct()
	{
		//$this->index($this->dbconn, $this->configuration['database']);
		$this->dbconn = null;
	}
}

/**
 *! @class dbMySQLi
 *  @abstract Extends class dbConn for MySQLi functionality
 *  @discussion Utilizes MySQLi for database access, queries, results etc
 */
class dbMySQLi extends mysqlDBconn
{

	/**
	 *! @var dbconn object - class singleton object
	 */
	private $dbconn;

	/**
	 *! @var configuration array - server, username, password, database
	 */
	private $configuration;

	/**
	 *! @function __construct
	 *  @abstract Creates new MySQLi link based on configured credentials
	 *  @param configuration array - server, username, password, database
	 *  @return object - MySQLi link resource
	 */
	public function __construct($configuration)
	{
		$this->configuration = $configuration;
		$this->dbconn = new mysqli($configuration['hostname'],
				$configuration['username'],
				$configuration['password'],
				$configuration['database']);
		return $this->dbconn;
	}

	/**
	 *! @function query
	 *  @abstract Handles MySQLi queries
	 *  @param query string - SQL statement
	 *  @return object - Returns SQL object
	 */
	public function query($query, $params=null)
	{
		return $this->dbconn->query($query);
	}

	/**
	 *! @function sanitize
	 *  @abstract Sanitizes dynamic variables in SQL statement
	 *  @param string string - String or Integer variables
	 *  @return string - Returns sanitized variable
	 */
	public function sanitize($string)
	{
		return $this->dbconn->real_escape_string($string);
	}

	/**
	 *! @function results
	 *  @abstract Returns associative array from last SQL statement
	 *  @param link object - Object handle of last query
	 *  @return array - Associative array
	 */
	public function results($link)
	{
		$z = array(); $y;
		while ($y = $link->fetch_array(MYSQLI_ASSOC)) {
			$z[] = $y;
		}
		return $z;
	}

	/**
	 *! @function affected
	 *  @abstract Handle affected amount of rows on last SQL statement
	 *  @param link object - Object handle of query
	 *  @return int - Number of affected rows
	 */
	public function affected($link=null)
	{
		return $this->dbconn->affected_rows;
	}

	/**
	 *! @function error
	 *  @abstract Return error message from last SQL statement
	 *  @param link object - Object handle of query
	 *  @return string - Error message returned
	 */
	public function error($link=null)
	{
		return $this->dbconn->error;
	}

	/**
	 *! @function index
	 *  @abstract Executed upon destruction of class instance to perform
	 *            repair, optimize and flush commands on each table in database
	 *  @param link object - Object handle of connection
	 *  @param database string - Database name
	 */
	public function index($link, $database)
	{
		$obj = $link->query('SHOW TABLES');
		$results = $this->results($obj);
		foreach($results as $key => $value) {
			if (isset($value['Tables_in_'.$database])) {
				$this->query('REPAIR TABLE '.$value['Tables_in_'.$database]);
				$this->query('OPTIMIZE TABLE '.$value['Tables_in_'.$database]);
				$this->query('FLUSH TABLE '.$value['Tables_in_'.$database]);
			}
		}
	}

	/**
	 *! @function __clone
	 *  @abstract Prevent cloning of singleton object
	 */
	public function __clone() {
		trigger_error('Cloning prohibited', E_USER_ERROR);
	}

	/**
	 *! @function __wakeup
	 *  @abstract Prevent deserialization of singleton object
	 */
	public function __wakeup() {
		trigger_error('Deserialization of singleton prohibited ...', E_USER_ERROR);
	}

	/**
	 *! @function __destruct
	 *  @abstract Release database handle and perform index functionality
	 */
	public function __destruct()
	{
		//$this->index($this->dbconn, $this->configuration['database']);
		$this->dbconn->close();
	}
}

/**
 *! @class dbMySQL
 *  @abstract Extends class dbConn for standard MySQL functionality
 *  @discussion Utilizes MySQL for database access, queries, results etc
 */
class dbMySQL extends mysqlDBconn
{

	/**
	 *! @var dbconn object - class singleton object
	 */
	private $dbconn;

	/**
	 *! @var configuration array - server, username, password, database
	 */
	private $configuration;

	/**
	 *! @function __construct
	 *  @abstract Creates new MySQL link based on configured credentials
	 *  @param configuration array - server, username, password, database
	 *  @return object - MySQL link resource
	 */
	public function __construct($configuration)
	{
		$this->configuration = $configuration;
		$this->dbconn = mysql_pconnect($configuration['hostname'],
				$configuration['username'],
				$configuration['password']);
		return mysql_select_db($configuration['database'], $this->dbconn);
	}

	/**
	 *! @function query
	 *  @abstract Handles MySQLi queries
	 *  @param query string - SQL statement
	 *  @return object - Returns SQL object
	 */
	public function query($query, $params=null)
	{
		return mysql_query($query);
	}

	/**
	 *! @function sanitize
	 *  @abstract Sanitizes dynamic variables in SQL statement
	 *  @param string string - String or Integer variables
	 *  @return string - Returns sanitized variable
	 */
	public function sanitize($string)
	{
		return mysql_real_escape_string($string);
	}

	/**
	 *! @function results
	 *  @abstract Returns associative array from last SQL statement
	 *  @param link object - Object handle of last query
	 *  @return array - Associative array
	 */
	public function results($link)
	{
		return mysql_fetch_assoc($link);
	}

	/**
	 *! @function affected
	 *  @abstract Handle affected amount of rows on last SQL statement
	 *  @param link object - Object handle of query
	 *  @return int - Number of affected rows
	 */
	public function affected($link=null)
	{
		return mysql_affected_rows();
	}

	/**
	 *! @function error
	 *  @abstract Return error message from last SQL statement
	 *  @param link object - Object handle of query
	 *  @return string - Error message returned
	 */
	public function error($link=null)
	{
		return mysql_error();
	}

	/**
	 *! @function close
	 *  @abstract Closes the database connection
	 *  @param link object - Object handle of connection
	 *  @return boolean - Results of close
	 */
	public function close()
	{
		return mysql_close();
	}

	/**
	 *! @function index
	 *  @abstract Executed upon destruction of class instance to perform
	 *            repair, optimize and flush commands on each table in database
	 *  @param link object - Object handle of connection
	 *  @param database string - Database name
	 */
	public function index($link, $database)
	{
		$obj = $this->query('SHOW TABLES');
		$results = $this->results($obj);
		foreach($results as $key => $value) {
			if (isset($value['Tables_in_'.$database])) {
				$this->query('REPAIR TABLE '.$value['Tables_in_'.$database]);
				$this->query('OPTIMIZE TABLE '.$value['Tables_in_'.$database]);
				$this->query('FLUSH TABLE '.$value['Tables_in_'.$database]);
			}
		}
	}

	/**
	 *! @function __clone
	 *  @abstract Prevent cloning of singleton object
	 */
	public function __clone() {
		trigger_error('Cloning prohibited', E_USER_ERROR);
	}

	/**
	 *! @function __wakeup
	 *  @abstract Prevent deserialization of singleton object
	 */
	public function __wakeup() {
		trigger_error('Deserialization of singleton prohibited ...', E_USER_ERROR);
	}

	/**
	 *! @function __destruct
	 *  @abstract Release database handle and perform index functionality
	 */
	public function __destruct()
	{
		//$this->index($this->dbconn, $this->configuration['database']);
		$this->close();
	}
}

