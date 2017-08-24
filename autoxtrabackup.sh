#!/bin/bash
# Galera MariaDB/MySQL backup script
#
# Copyright (c) 2016 Charles Williams
#       Based on the original work from Gregory Storme
#       Copyright (c) 2014 Gregory Storme
#
# Updated (c) 2017 Ronald Reed and Ryan Riordan
#
# Version: 0.3 beta

backupDir=/var/backup
mounttype=nfs
nfsmountpoint=/var/backup
incrtype=full
tmpDir=/tmp
hoursBeforeFull=167
hoursBeforeInc=23
compression=true
keepDays=7
keepWeeks=5
keepMonths=4
sendEmail=never
emailAddress=
backupLog=$tmpDir/autoxtrabackup.log

#####
# No editing should be required below this line
#####

usage () {
        echo -e " Configuration";
        echo -e "\t/etc/default/autoxtrabackup";
        echo -e "\t\t# Backup directory location
                # Dated folders inside this one will be created
                backupDir=\"/var/backups/autoxtrabackup\"

		# Mount Type?  Possible values: nfs, hard
		# nfs means that the backup directory is an NFS
		# mount and should be checked that it is mounted
		# before starting the backup.
		# hard means that the backup directory is a physical
		# filesystem on the machine and should only be tested
		# to see if it exists.
		mounttype=\"nfs\"

		# Incremental Type?  Possible values: full, incr
		# full means create each incremental backup using the
		# last full backup as a base
		# incr means use the last incremental as the base for
		# the next incremental
		incrtype=\"full\"
		
		# NFS mount point
		# Since the actual backup directory may be further down
		# the directory tree from the actual base NFS mount
		# point, this configuration sets the actual NFS mount to
		# check for.
		nfsmountpoint=\"/var/backup\"
				
                # Temp directory
                tmpDir=/tmp

                # Log file
                backupLog=/tmp/autoxtrabackup

                # How many hours between full backups?
                # For example if set to 12 hours and the script runs every hour, the
                # script will create a full backup at 12:00, and create incremental
                # backups until 23:00. At 00:00, it will create the next full backup, and so on.
                # Keep in mind, incremental backups are only applicable for XtraDB/InnoDB tables.
                # If you have MyISAM tables, these will be copied entirely each time
                hoursBeforeFull=72
                hoursBeforeInc=20

                # Username to access the MySQL server. On CentOS with mysql packaged installs,
                # you can use the your .my.cnf file in your home directory. On other distributions,
		# fill in your MySQL credentials
                mysqlUser=\`grep user ~/.my.cnf | head -n 1 | cut -d\"=\" -f2 | awk '{print $1}'\`
                mysqlPwd=\`grep password ~/.my.cnf | head -n 1 | cut -d\"\\\"\" -f2 | awk '{print $1}'\`

                # Compress the backup or not. Set compress to true/false. Compression is enabled by default
                compression=true

                # Set number of compress threads. Default is 1
                compressThreads=1

                # Number of days, weeks and months to keep backups (includes full and incremental)
                keepDays=7
                keepWeeks=5
                keepMonths=12

                # Send e-mail notifications? Possible values: always, onerror, never
                sendEmail=never

                # Send to which e-mail address
                emailAddress=";
        echo
        echo -e " Restore a full backup";
        echo -e "\tRestore a compressed backup:";
        echo -e "\t\t1: innobackupex --decompress $backupDir/(daily/weekly/monthly)/BACKUP-DIR";
        echo -e "\t\t2: Follow same steps as for non-compressed backups";
        echo -e "\tRestore a non-compressed backup:";
        echo -e "\t\t1: innobackupex --apply-log $backupDir/(daily/weekly/monthly)/BACKUP-DIR";
        echo -e "\t\t2: Stop your MySQL server";
        echo -e "\t\t3: Delete everything in the MySQL data directory (usually /var/lib/mysql)";
        echo -e "\t\t4: innobackupex --copy-back $backupDir/(daily/weekly/monthly)/BACKUP-DIR";
        echo -e "\t\t5: Restore the ownership of the files in the MySQL data directory (chown -R mysql:mysql /var/lib/mysql/)";
        echo -e "\t\t6: Start your MySQL server";
        echo
        echo -e " Restore an incremental backup";
        echo -e "\t1: If compressed, first decompress the backup (see above)";
        echo -e "\t2: First, prepare the base backup";
        echo -e "\t3: innobackupex --apply-log --redo-only $backupDir/(daily/weekly/monthly)/FULL-BACKUP-DIR";
        echo -e "\t4: Now, apply the incremental backup to the base backup.";
        echo -e "\t5: If you have multiple incrementals, pass the --redo-only when merging all incrementals";
        echo -e "\t\texcept for the last one. Also, merge them in the chronological order that the backups were made";
        echo -e "\t6: innobackupex --apply-log --redo-only $backupDir/(daily/weekly/monthly)/FULL-BACKUP-DIR";
        echo -e "\t\t--incremental-dir=$backupDir/(daily/weekly/monthly)/INC-BACKUP-DIR";
        echo -e "\t7: Once you merge the base with all the increments, you can prepare it to roll back the uncommitted transactions:";
        echo -e "\t8: innobackupex --apply-log $backupDir/(daily/weekly/monthly)/BACKUP-DIR";
        echo -e "\t9: Follow the same steps as for a full backup restore now";
}

while getopts ":hv" opt; do
  case $opt in
        h)
                usage;
                exit 0
                ;;
        v)
                set -x;
                ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
  esac
done

if [ -f /etc/default/autoxtrabackup ] ; then
        . /etc/default/autoxtrabackup
else
        echo -e " \"$0 -h\" for help on configuring"
        exit 1
fi

dailyDir=$backupDir/daily
weeklyDir=$backupDir/weekly
monthlyDir=$backupDir/monthly

# Check if innobackupex is installed (percona-xtrabackup)
if [[ -z "$(command -v innobackupex)" ]]; then
        echo "The innobackupex executable was not found, check if you have installed percona-xtrabackup."
        exit 1
fi

# Check mounttype for directory testing
if [[ $mounttype == nfs ]]; then
    grep -qs $nfsmountpoint /proc/mounts
    if [ $? -ne 0 ]; then
	mount "$nfsmountpoint"
	if [ $? -ne 0 ]; then
            echo "Something went wrong with mounting the backup filesystem!"
	    exit 1
        fi
    fi
fi

# Check if backup directory exists
if [ ! -d "$backupDir" ]; then
        echo "Backup directory does not exist. Check your config and create the backup directory"
        exit 1
fi
if [ ! -d "$dailyDir" ]; then
        mkdir $dailyDir
fi
if [ ! -d "$weeklyDir" ]; then
        mkdir $weeklyDir
fi
if [ ! -d "$monthlyDir" ]; then
        mkdir $monthlyDir
fi

# Check if mail is installed
if [[ $sendEmail == always ]] || [[ $sendEmail == onerror ]]; then
        if [[ -z "$(command -v mail)" ]]; then
                echo "You have enabled mail, but mail is not installed or not in PATH environment variable"
                exit 1
        fi
fi

# Check if you set a correct retention
if [ $(($keepDays * 24)) -le $hoursBeforeFull ]; then
        echo "ERROR: You have set hoursBeforeFull to $hoursBeforeFull and keepDays to $keepDays, this will delete all your backups... Change this"
        exit 1
fi

# If you enabled sendEmail, check if you also set a recipient
if [[ -z $emailAddress ]] && [[ $sendEmail == onerror ]]; then
        echo "Error, you have enabled sendEmail but you have not configured any recipient"
        exit 1
elif [[ -z $emailAddress ]] && [[ $sendEmail == always ]]; then
        echo "Error, you have enabled sendEmail but you have not configured any recipient"
        exit 1
fi

# If compression is enabled, pass it on to the backup command
if [[ $compression == true ]]; then
        compress="--compress"
        compressThreads="--compress-threads=$compressThreads"
else
        compress=
        compressThreads=
fi

dateNow=`date +%Y-%m-%d_%H-%M-%S`
dateNowUnix=`date +%s`
dateTomorrow=`date --date="tomorrow" +%D`
delDay=`date -d "-$keepDays days" +%Y-%m-%d`
delWeek=`date -d "-$keepWeeks weeks" +%Y-%m-%d`
delMonth=`date -d "-$keepMonths months" +%Y-%m-%d`
tomorrow=$(TZ=`date | awk '{print $5}'`-24 date +%d)
weekTomorrow=$((`date -d $dateTomorrow +%V`))
weekNext=$((`date +%V`+1))

# Check if last day of month
if [ $tomorrow -eq 1 ]; then
        # Do Monthly
        if [ -f "$monthlyDir"/last_monthly ]; then
                lastMonthly=`cat "$monthlyDir"/last_monthly`
        else
                lastMonthly=0
        fi

        # Calculate the time since the last full backup
        difference=$((($dateNowUnix - $lastMonthly) / 60 / 60))

        # Check if we must take a full or incremental backup
        if [ $difference -gt $hoursBeforeFull ]; then
                /usr/bin/innobackupex --user=$mysqlUser --password=$mysqlPwd --no-timestamp $compress $compressThreads --tmpdir=$tmpDir --rsync "$monthlyDir"/"$dateNow" > $backupLog 2>&1

                echo $dateNowUnix > "$monthlyDir"/last_monthly

                # Copy to Weekly
                if [ $weekTomorrow == $weekNext ]; then
                        cp -rfp $monthlyDir"/"$dateNow $weeklyDir
                        echo $dateNowUnix > "$weeklyDir"/last_weekly
                fi

                # Copy to daily
                cp -rfp $monthlyDir"/"$dateNow $dailyDir/$dateNow"_full"
                echo $dateNowUnix > "$dailyDir"/latest_full
        fi
elif [ $weekTomorrow == $weekNext ]; then
        # Do Weekly
        if [ -f "$weeklyDir"/last_weekly ]; then
                lastWeekly=`cat "$weeklyDir"/last_weekly`
        else
                lastWeekly=0
        fi

        # Calculate the time since the last full backup
        difference=$((($dateNowUnix - $lastWeekly) / 60 / 60))

        # Check if we must take a full or incremental backup
        if [ $difference -gt $hoursBeforeFull ]; then
                /usr/bin/innobackupex --user=$mysqlUser --password=$mysqlPwd --no-timestamp $compress $compressThreads --tmpdir=$tmpDir --rsync "$weeklyDir"/"$dateNow" > $backupLog 2>&1
                echo $dateNowUnix > "$weeklyDir"/last_weekly

                # Copy to daily
                cp -rfp $weeklyDir"/"$dateNow $dailyDir/$dateNow"_full"
                echo $dateNowUnix > "$dailyDir"/latest_full
        fi
else
        if [ -f "$dailyDir"/latest_full ]; then
                lastFull=`cat "$dailyDir"/latest_full`
        else
                lastFull=0
        fi
        if [ -f "$dailyDir"/latest_incremental ]; then
                lastInc=`cat "$dailyDir"/latest_incremental`
        else
                lastInc=0
        fi

        # Calculate the time since the last full backup
        differenceFull=$((($dateNowUnix - $lastFull) / 60 / 60))
        differenceInc=$((($dateNowUnix - $lastInc) / 60 / 60))

        # Check if we must take a full or incremental backup
        if [[ $differenceFull -lt $hoursBeforeFull ]] && [[ $differenceInc -gt $hoursBeforeInc ]]; then
                #echo "It's been $difference hours since last full, doing an incremental backup"
                lastFullDir=`date -d@"$lastFull" '+%Y-%m-%d_%H-%M-%S'`
                lastIncrDir=`date -d@"$lastInc" '+%Y-%m-%d_%H-%M-%S'`
		if [[ $incrtype == full ]]; then
			/usr/bin/innobackupex --user=$mysqlUser --password=$mysqlPwd --no-timestamp $compress $compressThreads --rsync --tmpdir=$tmpDir --incremental --incremental-basedir="$dailyDir"/"$lastFullDir"_full "$dailyDir"/"$dateNow"_incr > $backupLog 2>&1
		else
			/usr/bin/innobackupex --user=$mysqlUser --password=$mysqlPwd --no-timestamp $compress $compressThreads --rsync --tmpdir=$tmpDir --incremental --incremental-basedir="$dailyDir"/"$lastIncrDir"_incr "$dailyDir"/"$dateNow"_incr > $backupLog 2>&1
		fi
                echo $dateNowUnix > "$dailyDir"/latest_incremental
        elif [ $differenceFull -gt $hoursBeforeFull ]; then
                #echo "It's been $difference hours since last full backup, time for a new full backup"
                echo $dateNowUnix > "$dailyDir"/latest_full
                /usr/bin/innobackupex --user=$mysqlUser --password=$mysqlPwd --no-timestamp $compress $compressThreads --tmpdir=$tmpDir --rsync "$dailyDir"/"$dateNow"_full > $backupLog 2>&1
	else
		echo "It has not been long enough since the last incremental backup, nothing done"
        fi
fi

# Check if the backup succeeded or failed, and e-mail the logfile, if enabled
if grep -q "completed OK" $backupLog; then
        #echo "Backup completed OK"
        if [[ $sendEmail == always ]]; then
                cat $backupLog | mail -s "AutoXtraBackup log" $emailAddress
        fi
else
        #echo "Backup FAILED"
        if [[ $sendEmail == always ]] || [[ $sendEmail == onerror ]]; then
                cat $backupLog | mail -s "AutoXtraBackup log" $emailAddress
        fi
        exit 1
fi

# Delete backups older than retention date
rm -rf $dailyDir/$delDay*
rm -rf $weeklyDir/$delWeek*
rm -rf $monthlyDir/$delMonth*

# Delete incremental backups with full backup base directory that was deleted
for i in `find "$dailyDir"/*incr -type f -iname xtrabackup_info 2>/dev/null |  xargs grep $delDay | awk '{print $10}' | cut -d '=' -f2`; do rm -rf $i; done

exit 0
