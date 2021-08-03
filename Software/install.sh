[ -z $BASH ] && { exec bash "$0" "$@" || exit; }
#!/bin/bash
# file: install.sh
#
# This script will install the software for MEGA4.
# It is recommended to run it in your home directory.
#

# check if sudo is used
if [ "$(id -u)" != 0 ]; then
  echo 'Sorry, you need to run this script with sudo'
  exit 1
fi

# target directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/mega4"

# error counter
ERR=0

echo '================================================================================'
echo '|                                                                              |'
echo '|                   MEGA4 Software Installation Script                      |'
echo '|                                                                              |'
echo '================================================================================'

# check if it is Raspberry Pi 4
isRpi4=$(cat /proc/device-tree/model | sed -n 's/.*\(Raspberry Pi 4\).*/1/p')
if [[ $isRpi4 -ne 1 ]]; then
  echo 'Warning: this seems not a Raspberry Pi 4, you may not get the best USB performance.'
fi

# make sure en_GB.UTF-8 locale is installed
echo '>>> Make sure en_GB.UTF-8 locale is installed'
locale_commentout=$(sed -n 's/\(#\).*en_GB.UTF-8 UTF-8/1/p' /etc/locale.gen)
if [[ $locale_commentout -ne 1 ]]; then
	echo 'Seems en_GB.UTF-8 locale has been installed, skip this step.'
else
	sed -i.bak 's/^.*\(en_GB.UTF-8[[:blank:]]\+UTF-8\)/\1/' /etc/locale.gen
	locale-gen
fi

# disable usb autosuspend (make devices more responsive)
echo '>>> Disable USB autosuspend'
auto_suspend=$(grep 'usbcore.autosuspend=-1' /boot/cmdline.txt)
if [[ -z "$auto_suspend" ]]; then
  sudo sed -i -e 's/$/ usbcore.autosuspend=-1/' /boot/cmdline.txt
fi

# install MEGA4 software
if [ $ERR -eq 0 ]; then
  echo '>>> Install MEGA4 software'
  if [ -d "mega4" ]; then
    echo 'Seems MEGA4 software is installed already, skip this step.'
  else
    wget https://www.uugear.com/repo/MEGA4/LATEST -O mega4.zip || ((ERR++))
    unzip mega4.zip -d mega4 || ((ERR++))
    cd mega4
    chmod +x mega4.sh
    chmod +x uhubctl_32
    chmod +x uhubctl_64
    cd ..
    chown -R $SUDO_USER:$(id -g -n $SUDO_USER) mega4 || ((ERR++))
    sleep 2
    rm mega4.zip
  fi
fi

# install UUGear Web Interface
curl https://www.uugear.com/repo/UWI/installUWI.sh | bash

echo
if [ $ERR -eq 0 ]; then
  echo '>>> All done. Please reboot your Pi :-)'
else
  echo '>>> Something went wrong. Please check the messages above :-('
fi
