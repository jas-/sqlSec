# sqlSec #
Maintain PCI-DSS compliance of 'at rest' data with symmetric encryption key
data rotation.

## Description ##
PCI-DSS compliance regarding 'at rest' data requires the use of symmetric
encryption.

With this comes the problem of ['key rotation'](http://www.secureconsulting.net/2008/03/the_key_management_lifecycle_1.html).

This project aims to provide a simple, free to use method of adhering to said
compliance by implementing a series of stored procedures bound to the MySQL
database that requires encrypted data.

The stored procedures which can setup for event triggers, automated scheduling
or performed manually to perform the following functions on any specified
`databse -> table -> field` combinations.

## Install? ##
Simple, clone this repo and run installer.

```sh
$ ./install -h
```

## Usage? ##
The easiest method of saving & retrieving data once you implement the sqlSec
project would be to create stored procedures to handle access to the decrypted
(plain text) of the cipher text fields. Here are a few examples:

### Searching records ###
Here is a simple example of creating a stored procedure which will search a
table which contains encrypted fields.
```sql
DELIMITER //
CREATE PROCEDURE Search(IN search_param CHAR(128))
BEGIN
 CALL KR_GK(@Secret);
 SELECT `plain_text_field`, AES_DECRYPT(BINARY(UNHEX(cipher_text_field)), SHA1(@Secret)) AS cipher_text_field WHERE `plain_text_field` LIKE search_param OR AES_DECRYPT(BINARY(UNHEX(cipher_text_field)), SHA1(@Secret)) LIKE search_param;
END//
DELIMITER ;
```

### Adding new records ###
Here is an example procedure that can be used to insert new encrypted data
```sql
DELIMITER //
CREATE PROCEDURE Add(IN plain_txt_field CHAR(128), IN cipher_txt_field CHAR(128))
BEGIN
 CALL KR_GK(@Secret);
 INSERT INTO `table_name` (`plain_text_field`, `cipher_text_field`) VALUES (plain_txt_field, HEX(AES_ENCRYPT(cipher_txt_field, SHA1(@Secret))));
END//
DELIMITER ;
```

## Tests? ##
Yes, yes there are. In order to run them make sure you have run the installer,
selected a database to modify & then selected table & field combinations which
you wish to use as encrypted fields within the database.

If you simply wish to test with bogus data you can use the following example. This
example creates 100 bogus records per table/field combination specified during
the installation process so the total number of records for 5 fields on 5 tables
would be 500.

```sh
%> mysql -u [username] -p[password] [db-name] -e 'CALL sqlSec_DBG_FP(100)'
```

Next we can perform a rotation process. During this process there is quite a
few things taking place.
* A backup is created if specified to do so
* Any table/field combinations are used within primary loop
* The current encyption key is loaded
* A temporary table is created
* A view is created based on temporary table (used as cursor loop due to limiations in MySQL)
* The table/field combination values are decrypted with current key and placed in newly created temporary table
* A new encryption key is randomly generated
* The decrypted data is then encrypted with the new encryption key
* The newly encrypted data updates the original record id as to minimize disruption of record sets
* Temporary tables & views are removed

Here is a testing procedure to perform the above process X number of times, in
this case X=10.

```sh
%> mysql -u [username] -p[password] [db-name] -e 'CALL sqlSec_DBG_Test(10)'
```

## New user? ##
Privilege separation. A random username coupled with a random password with specific permission assignments to perform the rotation process.

