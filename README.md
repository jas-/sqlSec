# sqlSec #

Fork me @ https://www.github.com/jas-/sqlSec

Series of stored procedures forcing new or existing encrypted database contents
to adhere to password lifetimes.

## How? ##
By extracting current encrypted fields, generating a new key, re-encrypting
contents & updating original record.

## Why? ##
Because I can. No really, encrypted partitons for your database will only
secure your backups. Besides you never know when a blind SQL injection
will present itself.

## Dangerous? ##
There are several failsafes built in, you can force a backup of all records
with old key.

## Install? ##
Simple, clone this repo and run installer.

## Example? ##
Sure. In the example below we create the necessary copies of our templates,
connect using a privileged mysql user account, optionally create a backup of
your existing database, create the sqlSec user, permissions & tables, then
begin a wizard asking for ```table -> field``` combinations where existing
encrypted data or new encrypted data resides and adding them to sqlSec's
internal directory used during automated key rotation.

```sh
./install
sqlSec
Automate encryption key rotation for database
encrypted fields to meet password lifetime
security policies

Creating necessary database creation objects...

Database installation credentials

Enter MySQL username: root
Enter root MySQL password: 

Database settings

Database server name [localhost]: 
1) dhcp
Select database to use: 1

Backup directory [/tmp]: 

Create a backup?  [Y/n] 
Backup created... /tmp/2013-10-23-dhcp.sql

Creating database, users & permissions
Creating key rotaton procedures

Specify encrypted fields for database: dhcp

1) cors                  8) interfaces          15) sqlSec_settings
2) dns_servers           9) myTest              16) subnets
3) dns_zones            10) options             17) traffic
4) dnssec_keys          11) pools               18) viewServers
5) failover             12) routes              19) viewServersDetails
6) groups               13) servers             20) viewTraffic
7) hosts                14) sqlSec_map          21) Quit
Select table to view fields: 7
1) id                4) hardware-address  7) lease
2) hostname          5) subnet            8) notes
3) address           6) group             9) Main
Select field to enable encryption: 4
1) id                4) hardware-address  7) lease
2) hostname          5) subnet            8) notes
3) address           6) group             9) Main
Select field to enable encryption: 6
1) id                4) hardware-address  7) lease
2) hostname          5) subnet            8) notes
3) address           6) group             9) Main
Select field to enable encryption: 9
1) cors                  8) interfaces          15) sqlSec_settings
2) dns_servers           9) myTest              16) subnets
3) dns_zones            10) options             17) traffic
4) dnssec_keys          11) pools               18) viewServers
5) failover             12) routes              19) viewServersDetails
6) groups               13) servers             20) viewTraffic
7) hosts                14) sqlSec_map          21) Quit
Select table to view fields: 12
1) id
2) hostname
3) route
4) address
5) Main
Select field to enable encryption: 4
1) id
2) hostname
3) route
4) address
5) Main
Select field to enable encryption: 5
1) cors                  8) interfaces          15) sqlSec_settings
2) dns_servers           9) myTest              16) subnets
3) dns_zones            10) options             17) traffic
4) dnssec_keys          11) pools               18) viewServers
5) failover             12) routes              19) viewServersDetails
6) groups               13) servers             20) viewTraffic
7) hosts                14) sqlSec_map          21) Quit
Select table to view fields: 16
1) id        3) subnet    5) mask      7) route
2) hostname  4) address   6) dns       8) Main
Select field to enable encryption: 4
1) id        3) subnet    5) mask      7) route
2) hostname  4) address   6) dns       8) Main
Select field to enable encryption: 8
1) cors                  8) interfaces          15) sqlSec_settings
2) dns_servers           9) myTest              16) subnets
3) dns_zones            10) options             17) traffic
4) dnssec_keys          11) pools               18) viewServers
5) failover             12) routes              19) viewServersDetails
6) groups               13) servers             20) viewTraffic
7) hosts                14) sqlSec_map          21) Quit
Select table to view fields: 4
1) id         3) keyname    5) secret
2) hostname   4) algorithm  6) Main
Select field to enable encryption: 5
1) id         3) keyname    5) secret
2) hostname   4) algorithm  6) Main
Select field to enable encryption: 6
1) cors                  8) interfaces          15) sqlSec_settings
2) dns_servers           9) myTest              16) subnets
3) dns_zones            10) options             17) traffic
4) dnssec_keys          11) pools               18) viewServers
5) failover             12) routes              19) viewServersDetails
6) groups               13) servers             20) viewTraffic
7) hosts                14) sqlSec_map          21) Quit
Select table to view fields: 21
Cleaning up...
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

