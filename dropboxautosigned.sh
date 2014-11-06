#!/bin/sh

# ---------------------------------------------------------------------	#
# psuautosigned		Signed-in with PSU Login to access internet.	#
#									#
# version 0.1		- cj (2010-06-11) modified from engautosign-3	#
# version 0.1a		- cj (2010-06-14) read login/password from user	#
#			  if any of them doesn't provide from $CONF	#
# version 0.1b		- cj (2010-06-15) uses of function bug fixed.	#
#			  thanks to aj. Panyarak for this.		#
# version 0.1c		- cj (2010-06-18) fix bug when receive login	#
#			  and password from command line, thanks to 	#
#			  k. nagarindkx for finding this BIG bug.	#
# version 0.1d		- cj (2010-06-18) make it work with dash.	#
# version 0.2		- cj (2010-06-23) login page moved.		#
# version 0.2a		- cj (2010-06-24) logout supported.		#
# version 0.2b		- cj (2010-07-05) login page moved, again.	#
# version 0.2c		- cj (2011-05-12) login page changed, maybe	#
#			  caused by OS upgrade.				#
# version 0.2d		- cj (2011-05-18) some bug still exists, need	#
#			  to use address outside .psu.ac.th for the	#
#			  first connection, or else we are stuck.	#
#			  Also TIMEOUT added.				#
# version 0.2e		- cj (2011-05-20) port moved, address changed,	#
#			  once again?					#
# version 0.2f		- cj (2011-05-23) logout page changed.		#
# version 0.2g		- cj (2011-05-24) try to cope with internal	#
#			  server error on first logout.			#
# version 0.2h		- cj (2011-12-08) Captive Portal change from	#
#			  cp.psu.ac.th to cp-ufw.psu.ac.th		#
# version 0.3		- cj (2011-12-13) Support PANOS 4.1.1		#
# version 0.3a		- cj (2011-12-13) minor bug fixed.		#
# version 0.3b		- cj (2011-12-30) Improve error handling.	#
# version 0.4		- cj (2013-03-06) clean up code and handling	#
#			  error changed a bit.				#
# version 0.4a		- cj (2013-03-11) more clean up.		#
# ---------------------------------------------------------------------	#

CONF="$HOME/testdropbox/dropbox-in-docker/.dropboxautosigned"
COOKIES="$HOME/testdropbox/dropbox-in-docker/.dropboxautosigned-cookies.txt"

TIMEOUT="--connect-timeout 3 --max-time 5"
LOGIN="https://www.dropbox.com/login"
KEEPALIVE="https://www.dropbox.com/web_timing_log"
LOGOUT="https://www.dropbox.com/login"

# How long before we try refresh login page
SLEEPTIME=600
RETRYTIME=60
RES="/tmp/.$$.html"

CURL="/usr/bin/curl"
[ ! -x $CURL ] && echo "Can't execute ${CURL}." && exit

RET=0

# Read USER and PASS from configuration file
readconf() {
	USER=`grep ^user= $CONF`
	PASS=`grep ^passwd= $CONF`
	# support for old format 'user=xxx, pwd=yyy'
	[ -z "$PASS" ] && PASS=`grep ^pwd= $CONF | sed -e 's/^pwd/passwd/'`
	if [ -z "$USER" -o -z "$PASS" ]; then
		[ -z "$USER" ] && echo "Please set username 'user=' in $CONF"
		[ -z "$PASS" ] && echo "Please set password 'passwd=' in $CONF"
		exit
	fi
}

# Get USER and PASS from User
getuserpasswd() {
	# If we are running from terminal?
	[ "`tty`" = "not a tty" ]		&& \
		echo "Not running in terminal."	&& \
		exit

	# Yes, we are in the terminal
	stty echo;	echo -n "User: ";	read USER
	stty -echo;	echo -n "Passwd: ";	read PASS; echo ""
	stty echo
	if [ -z "$USER" -o -z "$PASS" ]; then
		[ -z "$USER" ] && echo "User must be defined."
		[ -z "$PASS" ] && echo "Password must be defined."
		exit
	fi
	USER="user=$USER"
	PASS="passwd=$PASS"
}

# Check whether we already login
do_checklogin() {
	# get header of login page
	RET=999
	COUNT=0
	while [ $RET != 0 ]; do
		$CURL $TIMEOUT -i -s -S -k $KEEPALIVE -c $COOKIES > $RES
		RET=$?
		if [ $RET != 0 ]; then
			COUNT=`expr $COUNT + 1`
			D=`date "+%Y-%m-%d %H:%M:%S"`
			echo "$D ERROR: do_checklogin() [:$COUNT]failed."
			sleep $RETRYTIME
		fi
	done

	# if get relocation header, then mean we need to login
	notLogin=`cat $RES | grep '^HTTP' | grep 'Moved'`

	# Get the captive portal page
	if [ "$notLogin" ]; then
		CPPAGE=`cat $RES | grep '^Location: ' | cut -f2- -d' '`
	fi
}

# get keepalive page
do_getkeepalive() {
	RET=999
	COUNT=0
	while [ $RET != 0 ]; do
		$CURL $TIMEOUT -s -S -k -L $KEEPALIVE -c $COOKIES > $RES
		RET=$?
		if [ "$RET" != 0 ]; then
			COUNT=`expr $COUNT + 1`
			D=`date "+%Y-%m-%d %H:%M:%S"`
			echo "$D ERROR: do_getkeepalive() [:$COUNT] failed."
			sleep $RETRYTIME
		fi
	done
}

# Signed-in
do_authen() {
	do_checklogin

	# Did we authenticated?
	if [  "$notLogin" ]; then
		# No, try authenticate first
		echo "Try authenticated at `date`"
		COUNT=0
		while true; do
			$CURL	$TIMEOUT -s -k -L $CPPAGE 	\
				-c $COOKIES -b $COOKIES		\
				-d "$U"				\
				--data-urlencode "$P"		\
				-d "$O"				> $RES
			if [ "$?" != 0 ]; then
				COUNT=`expr $COUNT + 1`
				D=`date "+%Y-%m-%d %H:%M:%S"`
				echo "$D ERROR: do_authen() [:$COUNT] failed."
				sleep $RETRYTIME
			else
				break
			fi
		done
	fi

	# Since December 2011, PSU ufw captive portal failed
	# to response after authenticate, so we just ignore
	# the output and proceed to keepalive page ourself.

	do_getkeepalive

	cat $RES					|\
	egrep '^Last|Your'				|\
	sed	-e 's/<br>//'				\
		-e 's/ *Your IP Address is /: /'	\
		-e 's/ *<\/font>//'			|\
	tr '\n' ' '
	echo

	rm -f $RES
}

# Signed-out
do_logout() {
	do_checklogin
	if [  "$notLogin" ]; then
		echo "You are not logged in..."
		rm -f $RES
		exit
	fi

	la=0

	# When we get 'Internal Server Reply' then wait for 3 seconds
	# and then try again...
	while test $la -lt 3; do
		la=`expr $la + 1`
		if [ "$la" -gt 3 ]; then	# Too many error!
			echo "Can't get valid response from firewall"
			cat $RES
			rm -f $RES
			exit
		fi

		$CURL $TIMEOUT -s -S -k -L $LOGOUT 		\
			-d "submit=LOGOUT"			\
			-c $COOKIES -b $COOKIES -d "" 		> $RES
		if [ "$?" != 0 ]; then
			D=`date "+%Y-%m-%d %H:%M:%S"`
			echo "$D ERROR: do_logout() failed."
			sleep 10
			continue
		fi
		if [ "`grep 'Internal Server Error' $RES`" ]; then
			sleep 3
		else
			break
		fi
	done

	if [ -z "`grep 'has been logged out' $RES`" ]; then
		echo "Hmmmm, not recognize response from firewall...."
		cat $RES
		rm -f $RES
		exit
	fi

	local login=`	cat $RES				|\
			grep 'Login='				|\
			sed	-e 's/^.*Login=//'		\
				-e 's/\r//'		`

	local ip=`	cat $RES				|\
			grep 'IP='				|\
			sed	-e 's/^.*;IP=//'		\
				-e 's/ has been logged out.*$//'`

	local date=`	cat $RES				|\
			grep 'IP='				|\
			cut -f5 -d\>				|\
			cut -f1 -d\<				`

	echo "User $login from $ip has logout at $date"
}

# Get authentication information
getautheninfo() {
	# if config file $CONF exist, read user/password from config file.
	if [ -f "$CONF" ]; then
		readconf
	else	# Then ask user to provide them.
		getuserpasswd
	fi

## The usual AUTHSTRING="${USER}&${PASS}&ok=Login"
## Separate AUTHSTRING to 'user=xxx' 'pwd=xxx' and 'ok=Login'

	O="ok=Login"
	U="$USER"
	P="$PASS"
}

# Main body as a function #

do_main() {

	# Default usage it loop until the terminal is closed or the
	# ^C is given.

	case "$action" in
	login)
		getautheninfo
		echo "-------------------------------------------"
		echo "Using default sleep value = $SLEEPTIME secs"
		echo "Please ^C to break from loop"
		echo "-------------------------------------------"
		while true; do
			do_authen
			sleep $SLEEPTIME
		done
	;;
	noloop)
		getautheninfo
		do_authen
		echo "Done."
	;;
	logout)
		do_logout
	#	echo "Logging out at $(date), goodbye."
	;;
	*)
		echo "Usage: $0 [login|logout|noloop]"
		exit
	;;
	esac
}

### Start Here ###
action="$1"
# Set default action if argument is not provided.
[ "$action" = "" ] && action="login"

# Main function here
do_main

# ---------------------------------------------------------------------	#
# end of file.								#
# ---------------------------------------------------------------------	#