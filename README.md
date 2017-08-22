# autoxtrabackup
An updated bash script for doing backups with the Percona xtrabackup program

The configuration file is located at **/etc/default/autoxtrabackup** and should look something like this:

```
backupDir=/var/tungsten/backup
mounttype=hard
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
