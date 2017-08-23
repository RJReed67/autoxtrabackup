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
mysqlUser=`grep user ~/.my.cnf | tail -n 1 | cut -d"=" -f2 | awk '{print }'`
mysqlPwd="`grep password ~/.my.cnf | tail -n 1 | cut -d\"\\\"\" -f2 | awk '{print }'`"
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
