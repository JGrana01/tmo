#!/bin/sh

#
# tmo.sh - an Asuswrt-Merlin script to monitor and make changes to the
# T-Mobile Sagemcom Fast Gateway
#
# You can check/enable/disable the 2 WiFi radios
# And examine some of the existing gateway configuration
#

#ErrorActionPreference='SilentlyContinue'

# location where configutration data is read from the Sagemcom

CONFIG=/jffs/scripts/config.txt
CONFIGC=/jffs/scripts/configc.txt

# if you want to keep track for how many reboots have occured, set to 1 and define the log file (REBOOTLOGFILE)
# if not, set to 0

LOGREBOOTS=1
REBOOTLOGFILE=/jffs/logs/rebootcnt

#
# username and password when logging into the T-Mobile Sagemcom Fast gateway
# needed for scripts that call tmo. Sorry, in plain text...
#

USER="admin"
PASS="thepassword"


# generate login token.

function token {
  if [ "$1" = "interactive" ]; then
#       read -s -p "Enter Username For The Gateway: " USER
        read -p "Enter Username For The Gateway: " USER
        read -s -p "Enter Password For The Gateway: " PASS
  fi
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

function ShowMenu {
  echo "Options for Gateway"
  echo "1: Press '1' to Turn Off 2.4 Ghz Radio."
  echo "2: Press '2' to Turn On 2.4 Ghz Radio."
  echo "3: Press '3' to Turn Off 5 Ghz Radio."
  echo "4: Press '4' to Turn on 5 Ghz Radio."
  echo "5: Press '5' to Reboot Gateway."
  echo "6: Press '6' to Display Configuration (and optional save)."
  echo "7: Press '7' to show 5G and LTE Signal Status"
  echo "8: Press '8' to show all Gateway information"
  echo "S: Press 'S' to Show WiFi Status."
  echo "Q: Press 'Q' to Quit."
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

function config {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/network/configuration?get=ap' -o $CONFIG
  cat $CONFIG |tr "," "\n" |tr -d "^ " > $CONFIGC
}

function signal {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway?get=signal' -o $CONFIG
  cat $CONFIG |tr "," "\n" |tr -d "^ " > $CONFIGC
}
function gwall {
  curl -s -H "$HEADER" 'http://192.168.12.1/TMI/v1/gateway?get=all' -o $CONFIG
  cat $CONFIG |tr "," "\n" |tr -d "^ " > $CONFIGC
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

function menu {
  ShowMenu
  SELECTION=S
  read -p "Please make a selection: " SELECTION
  case $SELECTION in
    1)
      echo "WiFi 2.4 Off"
      wifioff24
      sleep 5
      status
      sleep 3
      menu;;
    2)
      echo "WiFi 2.4 On"
      wifion24
      sleep 5
      status
      sleep 3
      menu;;
    3)
      echo "WiFi 5 Ghz Off"
      wifioff5
      sleep 5
      status
      sleep 3
      menu;;
    4)
      echo "WiFi 5 Ghz On"
      wifion5
      sleep 5
      status
      sleep 3
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
#      reboot
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
           cp $CONFIG /jffs/scripts/tmogwconfig.txt
           echo "Saved in /jffs/scripts/tmogwconfig.txt"
           pause
         ;;
         *)
           menu
        ;;
      esac
      read a
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
    q|Q)
      return;;
    s|S)
      status
      menu;;
    *)
      echo "huh? " $SELECTION
      sleep 1
      menu;;
  esac
}

if [ -z "$1" ]; then
        token interactive
        menu
        exit 0
fi

token script
case "$1" in
        config)
                config
                logger -t "tmo.sh" "Received config"
                cat $CONFIG
                exit 0
                ;;
        status)
                status
                exit 0
                ;;
        signal)
                signal
                cat $CONFIGC
                exit 0
                ;;
        signals)  # signal silent
                signal
                exit 0
                ;;
        all)
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
        login)
                token interactive
                logger -t "tmo.sh" "Got tmoheader"
                cat $Header
                exit 0
                ;;

esac
