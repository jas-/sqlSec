# sqlSec #
Performs symmetric encryption key and data rotation adhering to ISO 27001
(A.12.3.2), HIPAA (Title 2) & PCI-DSS (Requirement 3.5 & 3.6).

## Description ##
Compliance regarding ['at rest'](http://www.slideshare.net/SISAInfosec/key-management-techniques-sisa-presentation-at-ges-conference)
data requires the use of symmetric encryption.

With this comes the problem of ['key rotation'](http://www.secureconsulting.net/2008/03/the_key_management_lifecycle_1.html).

This project aims to provide a simple, free to use method of adhering to 'key
lifetime requirements' by implementing a series of stored procedures bound to
the MySQL database that requires encrypted data.

The stored procedures which can setup for event triggers, automated scheduling
or performed manually to perform the following functions on any specified
`databse -> table -> field` combinations.

## Install? ##
Simple, clone this repo and run installer.

```sh
$ ./install -h
```

## Test & Evaluate ##
If you wish to test and evaluate the effectiveness of this software you can do
so without risk of interuption of existing systems.

### Install test suite ###
If you run the tool with the `-t` option it will import a simple `PKI` management
database included with this distribution.

```sh
$ ./install -t
sqlSec - A symmetric encryption / data rotation tool for MySQL

  Creating necessary database creation objects...done

Database installation credentials
  Enter MySQL username: root
  Enter root MySQL password: 

Warning!
  Your MySQL installation does not support the latest
  encryption support, it is suggested you upgrade < 5.6.x

Database settings
  Database server name [localhost]: 

Test environment settings
  Test server name [localhost]: 
  Test database name [PKI]: 

  Test database read-write username [Administrator]: 
  Test database read-write password [Random]: 
  Test database read-only username [Read_Only]: 
  Test database read-only password [Random]: 

Test database account info
  Test database server: localhost
  Test database name: PKI
  Test database read-write account: Administrator
  Test database read-write password: d09cdf211abe7b85d776110d56c9c9cd
  Test database read-only account: Read_Only
  Test database read-only password: 6863c4e8b8d362a4065ad760c246bb16

Configure database
1) PKI
Select database to use: 1

Create backup
  Backup directory [/tmp]: 
  Create a backup?  [Y/n] 
  Backup created... /tmp/2015-06-22-PKI.sql

sqlSec specific operations
  Adding database sqlSec tables, users & permissions...done
  Creating key generation procedures...done
  Creating key rotation proceduresdone

Specify encrypted fields for database: PKI
1) certificates  3) escrow        5) privatekeys   7) trusts
2) credentials   4) keyring       6) publickeys    8) Quit
Select table to view fields: 2
1) id          3) email       5) Main
2) keyID       4) passphrase  6) Quit
Select field to enable encryption: 3
1) id          3) email       5) Main
2) keyID       4) passphrase  6) Quit
Select field to enable encryption: 4
1) id          3) email       5) Main
2) keyID       4) passphrase  6) Quit
Select field to enable encryption: 5
1) certificates  3) escrow        5) privatekeys   7) trusts
2) credentials   4) keyring       6) publickeys    8) Quit
Select table to view fields: 5
1) id
2) keyID
3) private
4) Main
5) Quit
Select field to enable encryption: 3
1) id
2) keyID
3) private
4) Main
5) Quit
Select field to enable encryption: 4
1) certificates  3) escrow        5) privatekeys   7) trusts
2) credentials   4) keyring       6) publickeys    8) Quit
Select table to view fields: 7
1) id
2) keyID
3) trusted
4) Main
5) Quit
Select field to enable encryption: 3
1) id
2) keyID
3) trusted
4) Main
5) Quit
Select field to enable encryption: 4
1) certificates  3) escrow        5) privatekeys   7) trusts
2) credentials   4) keyring       6) publickeys    8) Quit
Select table to view fields: 8
Cleaning up...
```

At that point you can use the wizard to add those fields you wish to begin
using within the key management routines.

### Populate the test database ###
Now that you have chosen the fields you wish to use now you can use the
[`sqlSec_DBG_FP()`](https://github.com/jas-/sqlSec/blob/master/templates/sqlSec-procs.sql#L325-L395)
stored procedure to populate the `table -> field` combinations with random
data. An example to create 100 records:

```sh
$ mysql -u <username> -p <password> PKI -e 'CALL sqlSec_DBG_FP(100)'
```

### Run the encryption key / data rotation tests ###
Once you have some generic records to work with you can now begin evaluating
the performance & functionality of the toolkit. The below example will run
the test over the 100 records created from the last step for ten iterations.

```sh
$ mysql -u <username> -p <password> PKI -e 'CALL sqlSec_DBG_Test(10)'
```

## Notes on security ##
Like any secure system a great deal relies upon the implementation. While this
software makes every attempt to protect the 'at rest' data as well as the 
encryption keys used, it is not without its limitations. This is especially
true if used as a default installation.

The following two sections addresses these inherant weakensses.

### On keys & strength ###
Prior to version 5.6 of the community MySQL database there was no API to 
generate a truely [random numbers](http://dev.mysql.com/doc/refman/5.6/en/encryption-functions.html#function_random-bytes).

Nor do they support any [IV (Initialization
Vector)](http://whatis.techtarget.com/definition/initialization-vector-IV)
within the [AES_ENCRYPT()](https://dev.mysql.com/doc/refman/5.6/en/encryption-functions.html#function_aes-encrypt)
/ [AES_DECRYPT()](https://dev.mysql.com/doc/refman/5.6/en/encryption-functions.html#function_aes-decrypt)
functions.

That being said this package will still work but the key & encryption modes
is limited and subject to attack methods.

It is HIGHLY recommended that you upgrade the MySQL engine in order to import
the [advanced cryptographic](https://dev.mysql.com/doc/refman/5.6/en/server-system-variables.html#sysvar_block_encryption_mode)
key management routines available.

While older MySQL installations are supported the strength of the keys generated
are not as secure as on versions < 5.6.

### On key management ###
The default method of key management is not anywhere near as secure as using
a key stored offline and only loaded when the need arises to rotate the
encryption key and the associated encrypted data.

A method of providing the path to a key file is available but must be provided
at the time of installation and be available at the time of rotation.