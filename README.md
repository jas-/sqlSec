# sqlSec #

Fork me @ https://www.github.com/jas-/sqlSec

Series of stored procedures forcing new or existing encrypted database contents to adhere to password lifetimes.

## How? ##
By extracting current encrypted fields, generating a new key, re-encrypting contents & updating original record.

## Why? ##
Because I can. No really, encrypted partitons for your database will only secure your backups. Besides you never know when a blind SQL injection will present itself.

## Dangerous? ##
There are several failsafes built in, you can force a backup of all records with old key.

## Install? ##
Simple, clone this repo and run installer.

## Example? ##
Sure.

```php
./install.php localhost dbname

Enter MySQL root password:
Successfully created new user account
Successfully created tables to oops
Successfully created stored procedures from 'sqlSec-procs.sql'
sqlSec installation details:
        Username: 59279858ea0fdefs
        Password: 48862f22fccaadb3a5xefe
        Backup path: /var/lib/mysql/dbname/

Lets define the table & fields you wish to store encrypted data in...
        Already using encrypted fields? n
        Create backup first? n
        Enter table: myTest
        Enter field: myField
        Another record? n
```

## New user? ##
Privilege separation. A random username coupled with a random password with specific permission assignments to perform the rotation process.

