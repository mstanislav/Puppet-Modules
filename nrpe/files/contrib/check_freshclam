#!/bin/bash
#################################################################################
#check_freshclam - written by James Melin of Hennepin County
#Mainframe services department on 11/28/2007
#
#Purpose - to check the freshness of the CLAM-AV signature file via freshclam -V
#and report on whether or not the last update date (expressed in seconds since
#the epoch) is more than 3 days older than the freshclam update stamp (expressed
#in seconds since the epoch - 259200 seconds) and issue a warning. If the last
#CLAM-AV Signature file is more than 5 days (432000 seconds) older than the
#timestamp provided by freshclam -V then issue a critical. If the value is 0
#then issue unknown and message that the status of the virus signature cannot be
#determined.
#################################################################################


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

filepath=$1
let freshclam=$(date -d "$(/usr/bin/freshclam -V | awk -F "/" '{ print $3 }')" +%s)
let curr_date=$(date +%s)
let days_ago_3=$(echo $curr_date - 259200 | bc)
let days_ago_5=$(echo $curr_date - 432000 | bc)
let not_scanned=0
let scan_interval=$(echo $curr_date - $freshclam | bc)

if   [ $freshclam -eq 0 ]; then
        echo "Last Virus Signature update UNKNOWN"
        exit $STATE_UNKNOWN
elif [ $freshclam -lt $days_ago_5 ]; then
        echo "Virus Signature Update CRITICAL - not updated in $(echo $scan_interval / 86400 | bc) days"
        exit $STATE_CRITICAL
elif [ $freshclam -lt $days_ago_3 ]; then
        echo "Virus Signature Update WARNING - not updated in $(echo $scan_interval / 86400 | bc) days"
        exit $STATE_WARNING
else
        echo "Virus Signature Update OK - last updated $(date -d "$(/usr/bin/freshclam -V | awk -F "/" '{ print $3 }') ")"
        exit $STATE_OK
fi
