# Autoxtrabackup
An updated bash script for automatic MySQL scheduled backups using Percona innobackupex (xtrabackup).
This script uses the innobackupex wrapper for xtrabackup from Percona, included in percona-xtrabackup.

Create full & incremental backups automatically, with configurable retention and compression, and optional e-mail output.

# Requirements
Supported MySQL distributions: MySQL, Percona Server, MariaDB

Supported Linux distributions: Debian, Ubuntu, CentOS, RedHat

Dependencies: percona-xtrabackup

This script has been tested on CentOS 6.9 with MySQL server

Original script can be found here: https://github.com/gstorme/autoxtrabackup

The script that was used as a base for this one can be found here: https://wiki.itadmins.net/mysql_mariadb_galera/galera_autoxtrabackup

The configuration file is located at **/etc/default/autoxtrabackup** and should look something like this:

```
backupDir=/var/backup
mounttype=hard
nfsmountpoint=/var/backup
incrtype=full
tmpDir=/tmp
mysqlUser=`grep user ~/.my.cnf | head -n 1 | cut -d"=" -f2 | awk '{print }'`
mysqlPwd="`grep password ~/.my.cnf | head -n 1 | cut -d\"\\\"\" -f2 | awk '{print }'`"
hoursBeforeFull=167
hoursBeforeInc=23
compression=true
compressThreads=1
keepDays=270
keepWeeks=39
keepMonths=9
sendEmail=never
emailAddress=
backupLog=$tmpDir/autoxtrabackup.log
```
**Note:** The grep commands above will parse out the first user= and password= lines in the .my.cnf file. Also, the password entry must be surrounded by double quotes and should **not** contain double quotes. This file should also have a chmod mask of 600 to keep the information in it secure.

# Examples

Create incremental backups each hour, and a full backup each 24 hours. Retention set to 1 week.

Set "hoursBeforeFull" to 24
Set "keepDays" to 7
Add a cronjob "0 * * * * /usr/local/bin/autoxtrabackup"
Create a full backup on Sunday, take incremental backups all other days. Keep backups for 1 month.

Set "hoursBeforeFull" to 168
Set "keepDays" to 31
Create the first backup on Sunday at the desired time, let's take 23h for example
Add a cronjob "0 23 * * * /usr/local/bin/autoxtrabackup"
Don't create incremental backups. Create a full backup every day at 23h, retention set to 1 week.

Set "hoursBeforeFull" to 1
Set "keepDays" to 7
Add a cronjob "0 23 * * * /usr/local/bin/autoxtrabackup"
