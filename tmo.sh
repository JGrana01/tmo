#!/bin/sh


#
# tmo.sh - an Asuswrt-Merlin script to monitor and make changes to the 
# T-Mobile Sagemcom Fast Gateway
#
# You can check/enable/disable the 2 WiFi radios
# And examine some of the existing gateway configuration
#
# this version (tmo.sh) uses dialog for a more graphical UI
# but also supports a non-interactive mode
#

# location where configutration data is read from the Sagemcom and stored

SCRIPTNAME="tmo"

SCRIPTDIR="/jffs/addons/$SCRIPTNAME"
SCRIPTVER="0.8"
PWENC=-pbkdf2
CONFIG="$SCRIPTDIR/config.txt"
CONFIGC="$SCRIPTDIR/configc.txt"
RADIOS="$SCRIPTDIR/radios.txt"

# dialog text formatting

BOLD="\Zb"
NORMAL="\Zn"
RED="\Z1"
GREEN="\Z2"

# dialog variables

DIALOG_CANCEL=1
DIALOG_ESC=255
DIALOG_QUIT="Q"
HEIGHT=19
WIDTH=0

display_result() {
  dialog --title "$1" \
    --no-collapse \
    --colors \
    --msgbox "$result" 8 20
}

display_file() {
 dialog --title "$1" \
    --no-collapse \
    --textbox "$2" 0 0
}


display_info() {
  dialog --infobox "$1" "$2" "$3"
  sleep $4
}


selectband() {
  while true; do
    exec 3>&1
    selection=$(dialog \
      --backtitle "Select WiFi Band to Monitor" \
      --title "WiFi Band" \
      --clear \
      --cancel-label "Exit" \
      --menu "Please select:" 9 30 4 \
    "1" "2.4 GHz Band" \
    "2" "5 GHz Band" \
      2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case $exit_status in
      $DIALOG_CANCEL)
        clear
        menu
       ;;
      $DIALOG_ESC)
        clear
        menu
        ;;
    esac
    case $selection in
      1 )
        barsm=A
        return
        ;;
      2 )
        barsm=X
        return
    esac
  done
}


#
# username and password when logging into the T-Mobile Sagemcom Fast gateway
# needed for scripts that call tmo. Sorry, in plain text...
# sourced from /jffs/scripts/tmo/tmo.conf
#

init_tmo() {
	if [ -d "/opt/bin" ] && [ ! -L "/opt/bin/tmo" ]; then
		ln -s "/jffs/scripts/tmo.sh" /opt/bin/tmo
		chmod 0755 "/opt/bin/tmo"
	fi
	write_tmo_config
}

write_tmo_config() {
	mkdir -p "${SCRIPTDIR}"
	echo "# TMO login settings  #" > "${SCRIPTDIR}/tmo.conf"
	echo "USER="admin"" >> "${SCRIPTDIR}/tmo.conf"
	echo "PWENC="-pbkdf2"" >> "${SCRIPTDIR}/tmo.conf"
	echo "# PASS is encoded in tmopw.enc" >> "$SCRIPTDIR/tmo.conf"
	if [ ! -x /opt/bin/opkg ]; then
		echo "NOMENU=1" >> "${SCRIPTDIR}/tmo.conf"
	else
		echo "NOMENU=0" >> "${SCRIPTDIR}/tmo.conf"
	fi
	echo "# if you want to keep track for how many reboots have occured, set to 1 and define the log file (REBOOTLOGFILE)" >> "${SCRIPTDIR}/tmo.conf"
	echo "LOGREBOOTS=0" >> "${SCRIPTDIR}/tmo.conf"
	echo "REBOOTLOGFILE=$SCRIPTDIR/rebootcnt" >> "${SCRIPTDIR}/tmo.conf"

# generate initial fake password
	echo -n "NotArealPassword" | /usr/sbin/openssl aes-256-cbc $PWENC -out "${SCRIPTDIR}/tmopw.enc" -pass pass:ditbabot,isoi

}


getbars() {
	bars5=$(grep -m 2 "bars" $CONFIGC | tail -1 | sed 's/bars //')
	band5=$(grep -m 2 "bands" $CONFIGC | tail -1 | sed 's/bands //')
	bars24=$(grep -m 2 "bars" $CONFIGC | head -1 | sed 's/bars //')
	band24=$(grep -m 2 "bands" $CONFIGC | head -1 | sed 's/bands //')
	if [ ! -z "$1" ]; then
		if [ "$1" = "A" ]; then
                  monbar="$bars24"
		  monband="$band24"
		else
                  monbar="$bars5"
		  monband="$band5"
		fi
	fi
}


wifistate() {
	tmostatus
	if [ $(grep $1 $RADIOS | grep -c Enabled) -gt 0 ]; then
		if [ $2 = "0" ]; then
			echo "ON"
		else
			echo "${GREEN}ON"
		fi
	else
		if [ $2 = "0" ]; then
			echo "OFF"
		else
			echo "${RED}OFF"
		fi
	fi
}



input_password() {
	data=$SCRIPTDIR.tmp
	# trap and remove temporary file
	trap "rm -f $data" 0 1 2 5 15

	# get password with the --insecure option
	dialog --title "Gateway Password" \
	--clear \
	--insecure \
	--passwordbox "Enter the password of the Gateway" 9 40 2> $data

	ret=$?

# make decison
	case $ret in
  		1)
			display_info "Cancel pressed" 4 20 2
    			rm -f $data
  		;;
  	255)
			display_info "Cancel pressed" 4 20 2
    			echo "NotARealPassword" > $data
    			retutn
  		;;
	esac
}

set_tmopwdi() {
	if [ ! -f "${SCRIPTDIR}/tmo.conf" ]; then
		write_tmo_config
	fi
	. "${SCRIPTDIR}/tmo.conf"

	/usr/sbin/openssl version | awk '$2 ~ /(^0\.)|(^1\.(0\.|1\.0))/ { exit 1 }' && PWENC=-pbkdf2
	if  [ ! -f "${SCRIPTDIR}/tmopw.enc" ]; then
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
					gettmopwd
					token
				fi
			break;;
			e|E)
				break;;
			*)	printf "\\n input is not an option\\n";;
		esac
		done
}
set_tmopwd() {
	if [ ! -f "${SCRIPTDIR}/tmo.conf" ]; then
		write_tmo_config
	fi

	. "${SCRIPTDIR}/tmo.conf"

	/usr/sbin/openssl version | awk '$2 ~ /(^0\.)|(^1\.(0\.|1\.0))/ { exit 1 }' && PWENC=-pbkdf2
	if  [ ! -f "${SCRIPTDIR}/tmopw.enc" ]; then
		display_info "There is no password set to access the Gateway - please set one now" 5 30 3
	else
	 	dialog --title "Gateway Password" \
		   --yesno "Would you like to see the present password?" 6 50
		   response=$?
		   if [ "$response" = "0" ]; then
		      passis=$(/usr/sbin/openssl aes-256-cbc $PWENC -d -in "${SCRIPTDIR}/tmopw.enc" -pass pass:ditbabot,isoi)
		      dialog --msgbox "$passis" 6 50
                  fi
	fi
	dialog --title "Input Gateway Password" \
	--backtitle "tmo" \
	--yesno "Input password of Gateway now?" 6 50
	response=$?
	case "$response" in
		0 ) 
                	input_password
                	if [ -f $data ] && [ ! -z $data ]; then
				PASSWORD=$(cat $data)
                		rm $data
				echo -n $PASSWORD | /usr/sbin/openssl aes-256-cbc $PWENC -out "${SCRIPTDIR}/tmopw.enc" -pass pass:ditbabot,isoi
				gettmopwd
				token
				display_info "Password changed" 5 20 2
			else
				display_info "Password not changed" 5 24 2
			fi
                	;;
		1 )
			if [ -f "{SCRIPTDIR}/tmopw.enc" ]; then
				dialog --msgbox "Password unchanged" 5 25
			else
				dialog --msgbox "You will need to input the Gateway password before using this program" 7 60
			fi
                	;;
		* )	
				dialog --msgbox "Input is not an option" 5 30
               	;;
		esac
}

verifypw() {
	config
	if [ $(grep -c "Authorization" $CONFIG ) -gt 0 ]; then
		dialog --title "Verify Gateway Password" \
		--yesno "The password was rejected by the Gateway. Try to change it?" 7 60
		response=$?
		case $response in
   		0)
	 		set_tmopwd ;;
   		1)
			display_info "Ok. You will need to set a correct password before using the program..." 6 20 2
		;;
   		255)
			display_info "You will need to set a correct password before using the program..." 6 20 2
		;;
		esac
	fi
}
verifypwi() {
	config
	if [ $(grep -c "Authorization" $CONFIG ) -gt 0 ]; then
		echo "The password was rejected by the Gateway. Try to change it? (Y or N)"
		read response
		case $response in
   		Y|y)
	 		set_tmopwdi ;;
   		N|n)
			echo "Ok. You will need to set a correct password before using the program..."
			exit 1
		;;
   		*)
			echo "You will need to set a correct password before using the program..."
			exit 1
		;;
		esac
	fi
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

tmoinstall() {
	echo "Creating script director "${SCRIPTDIR}"
	mkdir -p "${SCRIPTDIR}"
	if [ ! -x /opt/bin/opkg ]; then
		printf "\\ntmo requires Entware to be installed\\n"
		printf "\\nInstall Entware using amtm and run tmo.sh install\\n\\n"
		exit
	else
		echo "Checking for and installing required apps"
		opkg update
		for app in dialog jq column; do
			if [ ! -x /opt/bin/$app ]; then
				echo "Installing $app to /opt/bin"
				opkg install $app
			fi
		done
	fi
	init_tmo
	cat <<EOF

	     tmo.sh     Version $SCRIPTVER
	tmo.sh has been copied to $SCRIPTDIR and a link set in /opt/bin as tmo
	You can run it from /jffs/scripts/tmo.sh or /opt/bin/tmo. If /opt/bin is in
	your PATH, you can simply run tmo.
	Before using tmo.sh the firt time, you will need to input the password to the Sagemcom Gateway
	The default password is printed on the label on the Gateway, under the default User (admin)
	unless you have changed the default gateway password via the TMobile Internet App
	Run tmo with the password command:
	   $ tmo password
        Unless you change the Gateway admin password, you only need to do this once. tmo stores an
	encrypted version for use
	tmo.sh can be run via a menu system based on dialog. Just run tmo.sh without any command
	command line arguements. It also supports a list of arguments that return various
	results based on the argument.
EOF
}

removetmo() {
	rm -rf "${SCRIPTDIR}"
	rm -f /jffs/scripts/tmo.sh
	if [ -d /opt/bin ]; then
		rm -f /opt/bin/tmo
	fi
}

tmouninstall() {
	printf "\\n Uninstall tmo and it's data/directort? [Y=Yes] ";read -r continue
	case "$continue" in
		Y|y) printf "\\n Uninstalling...\\n"
	           removetmo
		   rm -rf "${SCRIPTDIR}"
                   rm -f /jffs/scripts/tmo.sh
                   if [ -d /opt/bin ]; then
			rm -f /opt/bin/tmo
		   fi
		   printf "\\ntmo uninstalled\\n"
		;;
		*) printf "\\ntmo NOT uninstalled\\n"
		;;
	esac
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


menu() {

while true; do
  exec 3>&1
  verifypw
  selection=$(dialog \
    --backtitle "TMO Sagemcom Gateway Utility  $SCRIPTVER" \
    --title "Menu" \
    --clear \
    --colors \
    --cancel-label "Exit" \
    --menu "Please select:" $HEIGHT $WIDTH 4 \
  "1" "Show all Gateway information" \
  "2" "Show WiFi Configuration" \
  "3" "Show 5G and LTE Signal Status" \
  "4" "Display Signal Strength" \
  "5" "Show Connected Clients" \
  "6" "Toggle 2.4 GHz Radio which is ${BOLD}$(wifistate 2.4 1)${NORMAL}" \
  "7" "Toggle 5 GHz Radio which is ${BOLD}$(wifistate 5 1)${NORMAL}" \
  "P" "Set Password Used to Access Gateway" \
  "R" "Reboot Gateway" \
  "Q" "Press Q to Quit" \
  "U" "Uninstall tmo" \
    2>&1 1>&3)
  exit_status=$?
  exec 3>&-
  case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Program terminated."
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
  esac
  case $selection in
    1 )
      gwall
      display_file "Gateway Info" $CONFIGC
      ;;
    2 )
      config
      sed -i 's/5.0ghz/\n5.0ghz/g' $CONFIGC
      display_file "WiFi Configuration" $CONFIGC
      ;;
    3 )
      signal
      sed -i 's/5g/\n5g/g' $CONFIGC
      display_file "WAN Radio Signals" $CONFIGC
      ;;
    4 )
      selectband
      if [ "$barsm" = "A" ]; then
             bandtitle="2.4GHz   Band:"
      else
             bandtitle="5GHz   Band:"
      fi
      while true
      do
         signal
	 getbars "$barsm"
	 echo $(expr $monbar \* 20) | dialog --keep-window --title "$bandtitl $monband" \
         --guage "Press Enter to exit..." 7 70 0
         if read -r -t 3; then
            clear
            menu
         fi
       done
     ;;
    5 )
       gclients
       sed -i 's/signal/\nsignal/g' $CONFIGC
       display_file "Connected Clients" $CONFIGC
      ;;
    6 )
      if [ $(wifistate 2.4 0) = "ON" ]; then
      		wifioff24
      		result=$(echo "2.4GHz Radio ${BOLD}${RED}Off${NORMAL}")
      		display_result "2.4GHz Wifi"
      else
      		wifion24
      		result=$(echo "2.4GHz Radio ${BOLD}${GREEN}On${NORMAL}")
      		display_result "2.4GHz Wifi"
      fi
      ;;
    7 )
      if [ $(wifistate 5 0) = "ON" ]; then
      		wifioff5
      		result=$(echo "5GHz Radio ${BOLD}${RED}Off${NORMAL}")
      		display_result "5GHz Wifi"
	else
      		wifion5
      		result=$(echo "5GHz Radio ${BOLD}${GREEN}On${NORMAL}")
      		display_result "5GHz WiFi"
      fi
      ;;
         
    R )
	dialog --title "Reboot Gateway" \
	--backtitle "tmo" \
	--defaultno \
	--yesno "Are you sure you want to reboot the Gateway (takes ~3 min.s)?" 7 60
	response=$?
	case $response in
   	0)
	   display_info "Rebooting..." 4 20 5
	   reboot
	   display_info "See you in 3+ minutes, exiting" 4 35 2
	   clear
	   exit
	;;
   	1)
	   display_info "Not Rebooting" 5 20 2
	;;
   	255)
	   display_info "Not Rebooting" 5 20 2
        ;;
	esac
        ;;
    P )
	set_tmopwd
        ;;

    Q )
        clear
        exit
      ;;
    U )
	dialog --title "Uninstall tmo" \
	--defaultno \
	--yesno "Are you sure you want to uninstall tmo and all it's files ?" 7 60
	response=$?
	case $response in
   	0)
	   display_info "Uninstalling..." 4 20 3
	   removetmo
	   display_info "tmo uninstalled, exiting" 4 35 2
	   clear
	   exit
	;;
   	1)
	   display_info "tmo not removed" 5 20 2
	;;
   	255)
	   display_info "tmo not removed" 5 20 2
        ;;
	esac
   esac
done
}

wifioff24() {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"2.4ghz":{"isRadioEnabled":true/"2.4ghz":{"isRadioEnabled":false/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}

wifion24() {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"2.4ghz":{"isRadioEnabled":false/"2.4ghz":{"isRadioEnabled":true/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}

wifioff5() {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"5.0ghz":{"isRadioEnabled":true/"5.0ghz":{"isRadioEnabled":false/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}
wifion5() {
    curl -s -H "$HEADER" -o $CONFIG http://192.168.12.1/TMI/v1/network/configuration?get=ap
    sed -i 's/"5.0ghz":{"isRadioEnabled":false/"5.0ghz":{"isRadioEnabled":true/g' $CONFIG
    curl -s -H "$HEADER" -d @$CONFIG -H "Content-Type: application/json" -X POST -m 1 http://192.168.12.1/TMI/v1/network/configuration?set=ap
}

pause() {
   echo
   echo -n "Paused, hit any key to continue..."
   read a
}

convertConfig() {
  cat $CONFIG | tr "," "\n" | tr -d "^ " | sed 's/\"//g' | sed 's/:/|/' | sed 's/{//g' | sed 's/}//g' | column -t -s "|" > $CONFIGC
}

config() {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/network/configuration?get=ap' -o $CONFIG
  convertConfig
}

signal() {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway?get=signal' -o $CONFIG
  convertConfig
}
gwall() {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway?get=all' -o $CONFIG
  convertConfig
}
gclients() {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/network/telemetry?get=clients' -o $CONFIG
  convertConfig
}
reboot() {
  curl -s -m 1 -X POST -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway/reset?set=reboot' -d "Content-Length: 0"
}

tmostatus() {
  config
  if [ $(grep "2.4ghz" $CONFIGC | grep -c "isRadioEnabled:true") -gt 0 ]; then
	echo "2.4 GHz WiFi Enabled" > $RADIOS
  else
	echo "2.4 GHz Wifi Disabled" > $RADIOS
  fi
  if [ $(grep "5.0ghz" $CONFIGC | grep -c "isRadioEnabled:true") -gt 0 ]; then
	echo "5.0 GHz WiFi Enabled" >> $RADIOS
  else
	echo "5.0 GHz WiFi Disabled" >> $RADIOS
  fi
}

wifisettingswait() {
  echo "Please wait..."
  sleep 5
  status
}

setradio() {
	if [ $1 = "2.4" ]; then
		if [ $2 = "off" ]; then
			wifioff24
		elif [ $2 = "on" ]; then
			wifion24
		else
			echo "Wrong value off or on"
			exit 1
		fi
	elif [ $1 = "5" ]; then
		if [ $2 = "off" ]; then
			wifioff5
		elif [ $2 = "on" ]; then
			wifion5
		else
			echo "Wrong value off or on"
			exit 1
		fi
	else
		echo "Wrong radio 2.4 or 5"
	
	fi
}

			

printhelp() {
	cat <<EOF

tmo is a utility that is used to manage a T-Mobile Sagemcom Gateway
It can display information on the WiFi or LTE/5G radios and also enable or disable
the WiFi radios.
I also provides a reboot command.

tmo runs either a menu based system by running without any command line
arguments or in script mode where it will return results of a command or do an
action on the command.
To run in menu mode, just type:

$ tmo

In scripts mode, enter an argument:

$ tmo arg

EOF
echo "More.. (press Enter)"
read a
cat <<EOF

The list of script arguments are:

menu	- Run tmo in a menu driven mode using Linux dialog. This is the default
          mode when run without a command line argument

config - will display the network/configuration of the Gateway

status - displays the state of both the 2.4 and 5 GHz radios (enabled or not)

signal - displays detailed information on the radios 

all - displays all information on the gateway

password - set/change the password used to access the Gateway
           (This does NOT change the Gateways password!!!, only the password
           tmo uses to access the Gateway

reboot - will issue a reboot command to the Gateway

radio [2.4|5] [off|on] - turn off or on the 2.4GHz or 5GHz radios

help - show this help info
	
install - setup the script directory, copy the program, link to /opt/bin (if its
	         there!) and setup a default config file

uninstall - remove tmo and its data/directories
EOF
}


gomenu() {

	if [ ! -f "${SCRIPTDIR}/tmo.conf" ]; then
		write_tmo_config
	fi
	. "${SCRIPTDIR}/tmo.conf"

	if [ ! -f "${SCRIPTDIR}/tmopw.enc" ]; then
		set_tmopwd
	fi

	gettmopwd

	token
	if [ "$NOMENU" = "0" ]; then
		menu
	else
		printf "tmo menu mode requires Entware.\\n"
		exit
	fi
}

if [ -z "$1" ]; then
	gomenu
	exit 0
fi

if [ $1 = "install" ];then
	tmoinstall
	touch "${SCRIPTDIR}/tmopw.enc"
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
gettmopwd
token
verifypwi

case "$1" in
	config)
		config
		logger -t "tmo.sh" "Received config"
		cat $CONFIG
		exit 0
		;;
	radio)
		if [ "$#" -eq "3" ]; then
			setradio $2 $3
		else
			 echo "wrong syntax: tmo radio [2.4 or 5] [off or on]"
			 exit 1
		fi
		exit 0
		;;
	status)
		tmostatus
		cat $RADIOS
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
		set_tmopwdi
		exit 0
		;;
	install)
		tmoinstall
		exit 0
		;;
	menu)
		gomenu
		exit 0
		;;
	help)
		printhelp
		exit 0
		;;
	uninstall)
		tmouninstall
		exit 0
		;;
	*)
		echo "Unknown command"
		exit 1
		;;
esac

