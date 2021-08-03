[ -z $BASH ] && { exec bash "$0" "$@" || exit; }
#!/bin/bash
# file: mega4.sh


# check if sudo is used
if [ "$(id -u)" != 0 ]; then
  echo 'Sorry, you need to run this script with sudo'
  exit 1
fi

# get current directory
cur_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# utilities
. "$cur_dir/utilities.sh"


control_ports()
{
  local hub=''
  if [[ ${#devices[@]} -eq 1 ]]; then
    local params=(${devices[0]//,/ })
	  hub=${params[0]}
	else
	  read -p '  Please specify the hub to control: ' hub
  fi
  
	if $(hub_id_ok $hub) ; then
		read -p "  Please specify the port(s) to turn $1 (separated by comma, or use - for ranges): " ports
  	if [[ $ports =~ ^[1-4,-]+$ ]] ; then
      local func=$(printf "turn_%s_ports" $1)
      exec 3< <($func $hub $ports)
      wait_until_done
      printf "                          "
    else
      echo "  Sorry \"$ports\" is not valid port(s)."
    fi
	else
	  echo "Sorry the hub \"$hub\" is not recognized."
	fi
}


echo '================================================================================'
echo '|                                                                              |'
echo '|   MEGA4: 4-Port USB3.1 PPPS Hub for Raspberry Pi 4B                          |'
echo '|                                                                              |'
echo '|                   < Version 1.00 >                                           |'
echo '|                                                                              |'
echo '================================================================================'

# ask user for action
while true; do

  # list all MEGA4 hubs
  exec 3< <(get_devices_info)
  wait_until_done
  read <&3 info
  devices=($info)
  IFS=$'\n' devices=($(sort <<<"${devices[*]}")); unset IFS
  
  for device in "${devices[@]}"; do
   print_device_info "$device" "$info"
  done

  echo 'Now you can:'
  echo ' 1. Turn port power ON...'
  echo ' 2. Turn port power OFF...'
  echo ' 3. Exit'
  read -p 'What do you want to do? (1~3) ' action
  case $action in
      1 ) control_ports 'on';;
      2 ) control_ports 'off';;
      3 ) exit;;
      * ) echo 'Please choose from 1 to 3';;
  esac
  
  echo ''
  echo '================================================================================'

done