# tmo.sh
Linux shell script to access and change some settings on T-Mobile Sagemcom Fast 5688W Gateway

This Linux shell script (tested on an Asuswrt-Merlin AX88U Pro) is based on a MS PowerShell scripts on Nate Taters YouTube channel.
I converted it to a Linux shell scripts (with help from ChatGPT!) and added some additional commands to display the 5G/LTE radio information
and overall gateway information. Added thanks to @thelonelycoder on snbforums for the password encryption code!

This script will allow you to enable/disable the WiFi radios (2.4 and 5Ghz). Helpful when running as just a modem in front of an Asus router.
I also added a reboot command.

I found that when my download speeds got low (less than 15 Mbits/sec.) a reboot of the Sagemcom usually got them back to 100Mbit+.

The script can be invoked by the command line:

$ /jffs/scripts/tmo.sh

In interactive mode, you will be prompted for the username (usually admin) and the password.

You will then be shown the main menu:

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

P: Press 'P' to set/change TMO Gateway password

Q: Press 'Q' to Quit.

Please make a selection:


It can also be called from another shell script. It knows its running non-interactive so you will need to first set the password foe the Gateway. tmo.sh will encrypt the password and store in the file ~tmo/tmopw.enc for use. You should only need to do this once, unless to change the default admin password on the Gateway itself.


In this mode, you pass it a command (i.e. /jffs/scripts/tmo.sh status. All output except signals is sent to standard out

config - displays the present configuration of the gateway

status - show the state of the two WiFi bands (enabled or disabled)

signal - show the present state of both the LTE and the 5G radios. Bands, levels etc.

signals - retrieve signal status and store (silently) in /jffs/scripts/config.txt

all - show all the gateway information - both WiFi and Radios

reboot - reboot the Sagemcom Fast Gateway

password - input the TMO Gateway admin password - needed for most commands

install - create the directory /jffs/scripts/tmo, put tmo.sh there with a conf file and also create a link in /opt/bin to tmo.sh


