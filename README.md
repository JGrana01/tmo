# tmo.sh
Linux shell script to access and change some settings on T-Mobile Sagemcom Fast 5688W Gateway

## About
This Linux shell script (tested on an Asuswrt-Merlin AX88U Pro) is based on a MS PowerShell scripts on Nate Taters YouTube channel.
I converted it to a Linux shell scripts (with help from ChatGPT!) and added some additional commands to display the 5G/LTE radio information
and overall gateway information. Added thanks to @thelonelycoder on snbforums for the password encryption code!

This script will allow you to enable/disable the WiFi radios (2.4 and 5Ghz). Helpful when running as just a modem in front of an Asus router.
I also added a reboot command.

I found that when my download speeds got low (less than 12 Mbits/sec.) a reboot of the Sagemcom usually got it back to 100Mbit+.

## Installation

For Asuswrt-merlin based routers, using your preferred SSH client/terminal, copy and paste the following command, then press Enter:

/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/JGrana01/tmo/master/tmo.sh" -o "/jffs/scripts/tmo.sh" && chmod 0755 /jffs/scripts/tmo.sh && /jffs/scripts/tmo.sh install

## Using

The script runs either in a dialog based menu mode or in a script mode.
To run in menu mode, just invoke without any command line argument:

$ tmo

To run in script mode, pass an argument. I.e.:

$ tmo status

It can also be called from another shell script in script mode. In script mode, after install,  you will need to set the password foe the Gateway. tmo.sh will encrypt the password and store in the file ~tmo/tmopw.enc for use. You should only need to do this once, unless to change the default admin password on the Gateway itself.


In script mode, you pass it any of these arguments:

config - displays the present configuration of the gateway

status - show the state of the two WiFi bands (enabled or disabled)

signal - show the present state of both the LTE and the 5G radios. Bands, levels etc.

signals - retrieve signal status and store (silently) in /jffs/addons/tmo/config.txt

all - show all the gateway information - both WiFi and Radios

radio [2.4|5] [off|on] - turn the 2.4Ghz or 5Ghz WiFi radios off or on

reboot - reboot the Sagemcom Fast Gateway

password - input the TMO Gateway admin password - needed for most commands

install - create the directory /jffs/addons/tmo, create a conf file and initial encrypted password file and then create a link in /opt/bin to tmo.sh

uninstall - remove everything related to tmo.sh


