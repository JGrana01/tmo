#!/bin/sh

#
# tmo.sh - an Asuswrt-Merlin script to monitor and make changes to the 
# T-Mobile Sagemcom Fast Gateway
#
# You can check/enable/disable the 2 WiFi radios
# And examine some of the existing gateway configuration
#

# location where configutration data is read from the Sagemcom and stored

SCRIPTDIR="/jffs/scripts/tmo"
SCRIPTVER="0.2"
PWENC=-pbkdf2
CONFIG="$SCRIPTDIR/config.txt"
CONFIGC="$SCRIPTDIR/configc.txt"

# if you want to keep track for how many reboots have occured, set to 1 and define the log file (REBOOTLOGFILE)
# if not, set to 0

LOGREBOOTS=1
REBOOTLOGFILE="$SCRIPTDIR/rebootcnt"

#
# username and password when logging into the T-Mobile Sagemcom Fast gateway
# needed for scripts that call tmo. Sorry, in plain text...
# sourced from /jffs/scripts/tmo/tmo.conf
#

init_tmo() {
	if [ -d "/opt/bin" ]; then
		ln -s "$SCRIPTDIR/tmo.sh" /opt/bin
		chmod 0755 "/opt/bin/tmo.sh"
	fi
	write_tmo_config
}

write_tmo_config(){
	mkdir -p "${SCRIPTDIR}"
	echo "# TMO login settings  #" > "${SCRIPTDIR}/tmo.conf"
	echo "USER="admin"" >> "${SCRIPTDIR}/tmo.conf"
	echo "PWENC="-pbkdf2"" >> "${SCRIPTDIR}/tmo.conf"
	echo "# PASS is encoded in tmopw.enc" >> "$SCRIPTDIR/tmo.conf"
}

set_tmopwd() {

	if [ ! -f "${SCRIPTDIR}/tmo.conf" ]; then
		write_tmo_config
	fi
	. "${SCRIPTDIR}/tmo.conf"

	/usr/sbin/openssl version | awk '$2 ~ /(^0\.)|(^1\.(0\.|1\.0))/ { exit 1 }' && PWENC=-pbkdf2
	if ! [ -f "${SCRIPTDIR}/tmopw.enc" ]; then
		printf "\\n There is no password set for $USER - please set one now\\n"
	else
		echo
		[ -f "${SCRIPTDIR}/tmopw.enc" ] && echo "Current password for $USER: $(/usr/sbin/openssl aes-256-cbc $PWENC -d -in "${SCRIPTDIR}/tmopw.enc" -pass pass:ditbabot,isoi)"
		echo
	fi
		while true; do
		printf "\\n Change password for $USER now? [1=Yes e=Exit] ";read -r continue
		case "$continue" in
			1) printf "\\n Enter new Password: [e=Exit] ";read -r value
				if [ "$value" != e ]; then
					PASSWORD=$value
					echo -n $PASSWORD | /usr/sbin/openssl aes-256-cbc $PWENC -out "${SCRIPTDIR}/tmopw.enc" -pass pass:ditbabot,isoi
				fi
			break;;
			e|E)
				break;;
			*)	printf "\\n input is not an option\\n";;
		esac
		done
}

set_tmouser() {
	if [ ! -f "${SCRIPTDIR}/tmo.conf" ]; then
		write_tmo_config
	fi
	. "${SCRIPTDIR}/tmo.conf"
	
	printf "\\nPresent User: $USER\\n"
	while true; do
	printf "\\n Change User name now? [1=Yes e=Exit] ";read -r continue
	case "$continue" in
		1) printf "\\n Enter new User name: [e=Exit] ";read -r value
			if [ "$value" != e ]; then
				USER=$value
			fi
			sed -i "/USER/d" "${SCRIPTDIR}/tmo.conf"
			echo "USER=$USER" >> "${SCRIPTDIR}/tmo.conf"
			break;;
		e|E)
			exit;;
		*)	printf "\\n input is not an option\\n";;
	esac
 	done
}

gettmopwd() {

	if [ -f "${SCRIPTDIR}/tmopw.enc" ]; then
		PASS="$(/usr/sbin/openssl aes-256-cbc $PWENC -d -in "${SCRIPTDIR}/tmopw.enc" -pass pass:ditbabot,isoi)"
	else
		printf "\\nError - no password set for TMO Gateway\\n"
		PASS=""
	fi
}


# generate login token.

token() {
  BODY=$(cat <<EOF
{
  "username": "$USER" ,
  "password": "$PASS"
}
EOF
)
  LOGIN=$(curl -s -X POST -H 'Content-Type: application/json' -d "$BODY" 'http://192.168.12.1/TMI/v1/auth/login')
  TOKEN=$(echo "$LOGIN" | jq -r '.auth.token')
  export HEADER="Authorization: Bearer $TOKEN"
  echo $HEADER > tmoheader
}

ShowMenu() {
#  echo "Options for Gateway"
#  echo "1: Press '1' to Turn Off 2.4 Ghz Radio."
#  echo "2: Press '2' to Turn On 2.4 Ghz Radio."
#  echo "3: Press '3' to Turn Off 5 Ghz Radio."
#  echo "4: Press '4' to Turn on 5 Ghz Radio."
#  echo "5: Press '5' to Reboot Gateway."
#  echo "6: Press '6' to Display Configuration (and optional save)."
#  echo "7: Press '7' to show 5G and LTE Signal Status"
#  echo "8: Press '8' to show all Gateway information"
#  echo "S: Press 'S' to Show WiFi Status."
#  echo "Q: Press 'Q' to Quit."

 cat <<EOM

 Options for Gateway

  1: Press '1' to Turn Off 2.4 Ghz Radio.
  2: Press '2' to Turn On 2.4 Ghz Radio.
  3: Press '3' to Turn Off 5 Ghz Radio.
  4: Press '4' to Turn on 5 Ghz Radio.
  5: Press '5' to Reboot Gateway.
  6: Press '6' to Display Configuration (and optional save).
  7: Press '7' to show 5G and LTE Signal Status
  8: Press '8' to show all Gateway information
  9: Press '9' to Show WiFi Status.
  P: Press 'P' to set/change TMO Gateway password.
  Q: Press 'Q' to Quit.
EOM
  printf "\\n"

}

function wifioff24 {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"2.4ghz":{"isRadioEnabled":true/"2.4ghz":{"isRadioEnabled":false/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}

function wifion24 {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"2.4ghz":{"isRadioEnabled":false/"2.4ghz":{"isRadioEnabled":true/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}

function wifioff5 {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"5.0ghz":{"isRadioEnabled":true/"5.0ghz":{"isRadioEnabled":false/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}
function wifion5 {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"5.0ghz":{"isRadioEnabled":false/"5.0ghz":{"isRadioEnabled":true/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}

function pause {
   echo
   echo -n "Paused, hit any key to continue..."
   read a
}

convertConfig() {
  cat $CONFIG | tr "," "\n" | tr -d "^ " | sed 's/\"//g' | sed 's/:/|/' | column -t -s "|" > $CONFIGC
}

function config {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/network/configuration?get=ap' -o $CONFIG
  convertConfig
}

function signal {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway?get=signal' -o $CONFIG
  convertConfig
}
function gwall {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway?get=all' -o $CONFIG
  convertConfig
}
function reboot {
  curl -s -m 1 -X POST -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway/reset?set=reboot' -d "Content-Length: 0"
}

function status {
  config
  echo
  if [ `grep 2.4ghz $CONFIGC | grep true` ]; then
	echo "2.4 Ghz WiFi Enabled"
  else
	echo "2.4 Ghz Wifi Disabled"
  fi
  if [ `grep 5.0ghz $CONFIGC | grep true` ]; then
	echo "5.0 Ghz WiFi Enabled"
  else
	echo "5.0 Ghz WiFi Disabled"
  fi
  echo
  pause
}

wifisettingswait() {
  echo "Please wait..."
  sleep 5
  status
}

menu() {
  ShowMenu
  SELECTION=""
  read -p "Please make a selection: " SELECTION
  case $SELECTION in
    1)
      echo "Setting WiFi 2.4 Off"
      wifioff24
      wifisettingswait
      menu;;
    2)
      echo "Setting WiFi 2.4 On"
      wifion24
      wifisettingswait
      menu;;
    3)
      echo "Setting WiFi 5 Ghz off"
      wifioff5
      wifisettingswait
      menu;;
    4)
      echo "Setting WiFi 5 Ghz On"
      wifion5
      wifisettingswait
      menu;;
    5)
      echo
      echo -n "Are you sure you want to reboot the Gateway? "
      read answer
      case $answer in
         Y|y)
           echo "ok"
         ;;
         *)
           echo "Not rebooting"
           menu
        ;;
      esac
      echo "Rebooting Gateway"
      echo "This will take some time"
      echo "After booting - you will need to login again"
      sleep 3
      reboot
      exit;;
    6)
      echo "Downloading config"
      config
      cat $CONFIGC
      echo
      echo -n "Do you want to save a copy of the configuration? (Y/N) "
      read answer
      case $answer in
         Y|y)
           cp $CONFIG $SCRIPTDIR/tmogwconfig.txt
           echo "Saved in $SCRIPTDIR/tmogwconfig.txt"
	   pause
         ;;
         *)
           menu
        ;;
      esac
      echo "Returning to Menu"
      menu;;
    7)
      echo "Getting signal information"
      signal
      cat $CONFIGC
      pause
      menu;;
    8)
      echo "Getting all Gateway information"
      gwall
      cat $CONFIGC
      pause
      menu;;
    9)
      status
      menu;;
    q|Q)
      return;;
    p|P)
      set_tmopwd
      menu;;
    *)
      echo "huh? " $SELECTION
      sleep 1
      menu;;
  esac
}

if [ -z "$1" ]; then
	token
	if [ ! -f "${SCRIPTDIR}/tmo.conf" ]; then
		write_tmo_config
	fi
	. "${SCRIPTDIR}/tmo.conf"

	if ! [ -f "${SCRIPTDIR}/tmopw.enc" ]; then
		set_tmopwd
	fi

	gettmopwd

	token

	menu
	exit 0
fi

token

if [ ! -f "${SCRIPTDIR}/tmo.conf" ] || [ ! -f "${SCRIPTDIR}/tmopw.enc" ]; then
	printf "\\nSorry, no $SCRIPTDIR/tmo.conf and/or $SCRIPTDIR/tmopw.enc\\n"
	printf "\\nEither run once interactive or run tmo.sh with the password command\\n"
	printf "\\ni.e. /jffs/scripts/tmo.sh password\\n"
	exit
fi

. "${SCRIPTDIR}/tmo.conf"

case "$1" in
	config)
		config
		logger -t "tmo.sh" "Received config"
		cat $CONFIG
		exit 0
		;;
	status)
		status
		logger -t "tmo.sh" "Received WiFi status"
		exit 0
		;;
	signal)
		signal
		logger -t "tmo.sh" "Received Signal status"
		cat $CONFIGC
         	exit 0
		;;
	signals)  # signal silent
		signal
		logger -t "tmo.sh" "Received Signal status (silent)"
         	exit 0
		;;
	all)
		logger -t "tmo.sh" "Getting all TMO Gateway status"
		gwall
        	exit 0
		;;
	reboot)
		reboot
		logger -t "tmo.sh" "Rebooted TMO"
		if [ $LOGREBOOTS = 1 ]; then
			awk -F, '{$2=$2+1}1' OFS=, $REBOOTLOGFILE > /tmp/rbc && mv /tmp/rbc $REBOOTLOGFILE
			logger -t "tmo.sh" "Logged Reboot Count"
		fi
		exit 0
		;;
	password)
		set_tmopwd
		exit 0
		;;
	install)
		mkdir -p "${SCRIPTDIR}"
		mv /jffs/scripts/tmo.sh "${SCRIPTDIR}"
		init_tmo
		printf "\\n\\n     tmo.sh     Version $SCRIPTVER\\n"
		printf "\\ntmo.sh has been moved to $SCRIPTDIR and a link set in /opt/bin\\n"
		printf "Before using tmo.sh the firt time, you will need to input the password to the Sagemcom Gateway\\n"
		printf "The default password is printed on the label on the Gateway, under the default User (admin)\\n"
		printf "unless you have changed the default gateway password via the TMobile Internet App\\n"
		printf "Run tmo.sh with the password command:\\n\\n"
		printf "   $ tmo.sh password\\n\\n"
		printf "Unless you change the Gateway admin password, you only need to do this once. tmo.sh stores an\\n"
		printf "encrypted version for use\\n\\n"
		exit 0
		;;
esac

