#!/system/bin/sh
# catch0sms.sh -- A mksh script to scrape radio logcat for type-0 SMS
#
# Author:	E:V:A (Team AIMSICD)
# Date:		2015-01-07
#
#======================================================================
# Requirements: 
#		* rooted device		
#		* Toaster App:		com.rja.utility/.ShowToast
#		http://forum.xda-developers.com/showthread.php?t=773232
# 
# Installation: 
#		- put binary in a place where you can execute, like in: 
#		  /data/data/com.arachnoid.sshelper/home
#		- chmod 777 catch0sms.sh
#		- From root:  ./catch0sms.sh
#
# Support:	Support is strongly HW and SW dependent, but detection 
#		should be possible on most devices with:
# 
#		* AOS > JB 4.2.2 (Enforcing) with API >= 17
#		* 
#		* Qualcomm:	MSM 8930/8960/8974 etc. 
#		* Intel:	Xgold/XMM 6260/6360/7260
#		* Mediatek:	MT 6582/ 
#
# Testing:	Use the HushSMS (XPosed) from another phone to send:
#		* Ping 3 (0-byte WAP push)
#		* Ping 4 (Empty MMSN)		[MMSN="MMS Notification"]
# 
# To manually add event in logcat: 
#	#log --help
#	  unknown option -- -USAGE: log [-p priorityChar] [-t tag] message
#         priorityChar should be one of: v,d,i,w,e
#	See: http://log4think.com/debug-android-logging/
# 
# TODO:
#	[ ] implement SMS signature identifcation
#	[ ] implement SQLite3 DB entries
#	[ ] find other native method to send toas meassage ??
#	[ ] 
# 
# ChangeLog:
#	2015-01-15	
#
#----------------------------------------------------------------------

#----------------------------------------------------------
# Logcat strings as found on:	GT-I9195 JB4.2.2 (E)
#----------------------------------------------------------
#01-16 01:00:17.385 D/GsmSmsDispatcher( 1226): sendSms:  mRetryCount=0 mMessageRef=0 SS=0
#01-16 01:00:17.385 D/GsmSmsDispatcher( 1226): sendSms:  isIms()=false mRetryCount=0 mImsRetry=0 mMessageRef=0 SS=0
#01-16 01:00:19.017 D/RILJ    ( 1226): [23715]> SMS_ACKNOWLEDGE false 214

# MAIN:
#
# D/Gsm/SmsMessage( 1195): SMS SC timestamp: 1421367661000
# W/Gsm/SmsMessage( 1195): 1 - Unsupported SMS data coding scheme 4
# E/Gsm/SmsMessage( 1195): hasUserDataHeader : true
# I/GsmSmsDispatcher( 1195): [DirectedSMS] Start1:
# I/GsmSmsDispatcher( 1195): [DirectedSMS] End1....:
# D/GsmSmsDispatcher( 1195): [DirectedSMS] Checking End...
# D/WAP PUSH( 1195): Rx: 7c06xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx00
# V/TP/MmsSmsProvider( 1195): query,matched:4
# D/TP/MmsSmsProvider( 1195): getThreadId: recipientIds (selectionArgs) =294
# D/TP/MmsSmsProvider( 1195): match 4:Elapsed time : 15.596 ms
# D/SmsProvider( 1195): insert content://sms/2450 succeeded
# I/SurfaceFlinger(  301): id=51(11) createSurf 0x402fd304 (1x1),1 flag=4, Uoast
# V/Mms:transaction( 2103): [PushReceiver] Received PUSH.
# E/Mms:transaction( 2103): [PushReceiver] Invalid PUSH data

# EVENTS:
#
#I/power_partial_wake_state(  852): [1,SMSDispatcher]
#I/power_partial_wake_state(  852): [0,SMSDispatcher]

### Silent: WAP ###
#logcat -d -b main *:v RILQ:S |grep --color=always -E "SMS"
# W/Gsm/SmsMessage( 1195): 1 - Unsupported SMS data coding scheme 4
#logcat -d -b radio *:v RILQ:S |grep --color=always -E "SMS"
# 



# D/GsmInboundSmsHandler(11177): Received short message type 0, Don't display or store it. Send Ack
# D/RILJ    (11177): [4038]> SMS_ACKNOWLEDGE true 0
# ...
# D/use-Rlog/RLOG-QC-QMI(  198):  Inside qmi_client_decode_msg_async  Callback 
#----------------------------------------------------------

#--------------------------------------
# Setup 
#--------------------------------------
SPID="$$"
echo "Starting $0 with PID: $SPID"
echo "Kill this process with: kill -1 $SPID"

# The log file:
SMSLOG="/sdcard/eva/silentsms.log"
# The DB file:
AIMDB="/data/data/com.SecUpwN.AIMSICD/databases/aimsicd.db"

alias smscat='logcat -d -v time -b radio'

# Grab the logcat timestamp and convert to normalized SQL timestamp:
# '07-15 05:57:02.075 D/RILJ ...' ==>
# '2015-01-13 21:42:45'
alias grabts='sed -E "s/^(.+)/2015\-\1/" |sed -E "s/([0-9]{2})\.[0-9]{3}/\1/" | sed -E "s/(^.+[0-9]{2}:[0-9]{2}) .+/\1/"'

# The warning "toast" message on screen:
alias silentsmswarn='am start -a android.intent.action.MAIN -e message "Silent SMS Received!" -n com.rja.utility/.ShowToast >/dev/null 2>&1'

#--------------------------------------
# Setup RAM disk / FIFO buffer device
#--------------------------------------
# 
# mkdir /data/local/temp/aimsicd/
# touch /data/local/temp/aimsicd/sms0
# mkdev XXXX
# mount 

#--------------------------------------
# Functions! 
#--------------------------------------

# Check Qualcomm CP debug level:
# [ro.boot.cp_debug_level]: [0x55FF]
# [ro.boot.debug_level]: [0x494d]
# [ro.cp_debug_level]: [0x55FF]
# [ro.debug_level]: [0x494d]
#DBL=$(getprop ro.cp_debug_level); if [[ $DBL = "0x55FF" ]]; then echo "CP debug is turned off!"; else echo "CP Debug Level is: $DBL"; fi;

function cplev() {
	DBL=$(getprop ro.cp_debug_level);
	echo -en "\n\nChecking CP debug level..\n"
	if [[ $DBL = "0x55FF" ]] 
	then 
		echo "CP debug is turned OFF! Your radio logs may not show enough info."
		echo "Please increase your CP debug level from Service Menu or *#66336#."
		#27663368378 CPMODEMTEST
	else 
		echo "CP Debug Level is: $DBL"
	fi
	unset DBL
}

#----------------------------------------------------------
# Add detection log entries to the DB table(s): 
# silentsms AND/OR EventLog
# See: https://www.sqlite.org/cli.html 
#----------------------------------------------------------

# The Detection Flag id from: 
# https://github.com/SecUpwN/Android-IMSI-Catcher-Detector/issues/230

#CREATE TABLE EventLog (_id integer primary key autoincrement, timestamp TEXT, DF_id INTEGER, DF_description TEXT);
#INSERT INTO "EventLog" VALUES(1,"$TS",12,"Detected Silent SMS! (signature:1)");

function addTable() {
	sqlite3 "$AIMDB" 'CREATE TABLE EventLog (_id integer primary key autoincrement, timestamp TEXT, DF_id INTEGER, DF_description TEXT);'
}

# Use with:  addEntry <timestamp> <signature> 
function addEntry() {
	SSTS=$1		# SMS Time STamp
	#SSIG=$2	# SMS Type-0 detection signature
	SSIG=0		
	#DF_id=12	# Detection Flag id for "Silent SMS"
	#SQL='INSERT INTO "EventLog" (timestamp,DF_id,DF_description) VALUES("'$TS'",12,"Detected Silent SMS! (signature:1)");'
	SQL='INSERT INTO "EventLog" (timestamp,DF_id,DF_description) VALUES("'$SSTS'",12,"Detected Silent SMS! (sig:'$SSIG')");'
	sqlite3 "$AIMDB" "$SQL"
}

function exportEvents() {
	# .headers ON; 
	# .mode csv; 
	sqlite3 "$AIMDB" 'SELECT * FROM EventLog'
}

#----------------------------------------------------------
# Setup the detection strings:
#----------------------------------------------------------
# Add your device findings here, with:
# <device name>:<AOS Version>:<BP/AP>
#----------------------------------------------------------
# For TEST only:
#ZSMS1="mcc_mnc_ascii"
#ZSMS2="sys_info_ind"
#ZSMS3="qcril_qmi_convert_rat_mask_to_technology"
#ZSMS3="SignalBar"

# Samsung GT-I9195:JB4.2.2E:MSM8930
ZSMS1="Received short message type 0"
ZSMS2="SMS_ACKNOWLEDGE true 0"
ZSMS3="Inside qmi_client_decode_msg_async  Callback"

#-b main
# W/Gsm/SmsMessage( 1195): 1 - Unsupported SMS data coding scheme 4
# D/WAP PUSH( 1195): Rx: 7c0603beaf848c969831323334008d93be3132333400
# D/SmsProvider( 1195): insert content://sms/2450 succeeded
ZSMS4="Unsupported SMS data coding scheme 4"
ZSMS5="WAP PUSH"
ZSMS6="insert content://sms/"

#-b events
#I/power_partial_wake_state(  852): [1,SMSDispatcher]
#I/power_partial_wake_state(  852): [0,SMSDispatcher]
ZSMS7="[1,SMSDispatcher]"

#-b radio
#01-16 01:00:19.017 D/RILJ    ( 1226): [23715]> SMS_ACKNOWLEDGE false 214
ZSMS7="> SMS_ACKNOWLEDGE false"



# Samsung GT-I9100:KK4.4.2:XMM6260
# Gigabyte GSmart ArtyA3:KK4.4.2:MT nnnn
#----------------------------------------------------------

cplev;

#--------------------------------------
# Main Detection Loop
#--------------------------------------
# $ZSMS1 $ZSMS2 $ZSMS3
# They need to be quoted or you'll test on each word...
# may improve by defining an array:
# fnames=( a.txt b.txt c.txt ) ... for f in ${fnames[@]};
#--------------------------------------

echo 
while :
do
	ZTOT=0;
	#SSIG=0;
	for x in "$ZSMS1" "$ZSMS2" "$ZSMS3";
	do 
		echo -en "Testing for: $x\n"; 
		#ZRES=0;
		ZRES=$(smscat | grep -c -E "$x");
		if [[ $ZRES -gt 0 ]]; then
			echo "Detected $ZRES possible Type-0 SMS" 
			smscat | grep -E "$x" |grabts >>$SMSLOG
			ZTOT=$(( $ZTOT + $ZRES )); 
		fi
	done;

	if [[ $ZTOT -gt 0 ]]; then
		echo "Detected: $ZTOT new Silent SMSs"
		silentsmswarn;
		echo "Clearing radio logcat." 
		#logcat -c -b radio
		ZTOT=0
	else
		echo "All is well, and nothing found."
	fi
	echo -e "\n";
	sleep 20
done

echo -e "\nExiting 0SMS Detector\n";
exit 0

#--------------------------------------
# To check success of a command use "$?":
#--------------------------------------
#[[ $? ]]
# /sdcard/eva/radiolog
#((logcat -v time -b radio -s AT:D GSM:D | grep -E "message1|message2") > /sdcard/radiolog) &
#((logcat -d -v time -b radio -s AT:D GSM:D | grep -E "$ZSMS1") > /sdcard/radiolog) &
#======================================================================

