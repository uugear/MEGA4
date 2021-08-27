#!/bin/bash
# file: utilities.sh
#
# This script provides some useful utility functions
#

# get current directory
mydir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# check it is running in 32-bit or 64-bit OS
if [ "$(uname -m)" == 'aarch64' ]; then
  uhubctl="$mydir/uhubctl_64"
else
  uhubctl="$mydir/uhubctl_32"
fi

hub_id_ok()
{
	if [[ $1 =~ ^[0-9.-]+$ ]] && [[ ! -z $($uhubctl | grep "hub $1 \[2109:2817") ]]; then
    return 0
  else
    return 1
  fi
}


get_devices_info()
{
  local hubs=$($uhubctl)
  local skip=1
  declare -a ids
  declare -A info
  
  # first run to find all USB2 hubs and check port state
  while IFS= read -r line; do
    if [[ $line == Current* ]]; then
      if [[ $line == *"[2109:2817 VIA Labs, Inc. USB2.0 Hub, USB 2.10, 4 ports, ppps]"* ]]; then
        skip=0
        id=$(echo -n $line | sed 's/Current status for hub //' | sed 's/ \[2109:2817 VIA Labs, Inc. USB2.0 Hub, USB 2.10, 4 ports, ppps\]//')
        ids+=($id)
      else
        skip=1
      fi
    elif [[ $skip == 0 && $line == *Port* ]]; then
      port=$(echo -n $line | sed 's/Port //' | sed 's/:.*//')
      
      if [[ $line == *power* ]]; then
      
        if [[ $line == *connect* ]]; then
          info[$id,$port]=2
        else
          info[$id,$port]=1
        fi
      else
        info[$id,$port]=0
      fi
    fi
  done <<< "$hubs"
  
  # this makes sure the hubs info are collected beforehand
  # second run to find USB3 hubs and check if any port used
  local devIndex=-1;
  while IFS= read -r line; do
    if [[ $line == Current* ]]; then
      if [[ $line == *"[2109:0817 VIA Labs, Inc. USB3.0 Hub, USB 3.10, 4 ports, ppps]"* ]]; then
        devIndex=$(($devIndex + 1))
        id=${ids[$devIndex]}
        skip=0
      else
        skip=1
      fi
    elif [[ $skip == 0 && $line == *Port* ]]; then
      port=$(echo -n $line | sed 's/Port //' | sed 's/:.*//')
      if [[ $line == *power* ]] && [[ $line == *connect* ]]; then
        if [[ ${info[$id,$port]} == 1 ]]; then
          info[$id,$port]=2;
        fi
      fi
    fi
  done <<< "$hubs"
  
  local space=''
  for id in "${ids[@]}"
  do
    echo -n "$space$id,${info[$id,1]},${info[$id,2]},${info[$id,3]},${info[$id,4]}"
    space=' ' 
  done
  echo
}

port_state()
{
  if [[ "$1" == '2' ]]; then
    echo '*ON'
  elif [[ "$1" == '1' ]]; then
    echo ' ON'
  else
    echo 'OFF'
  fi
}

center_text()
{
  local text=$1
  local length=$2
  let leading=($length-${#text})/2
  let trailing=$length-$leading-${#text}
  if [[ $leading -lt 0 ]]; then
  	let leading=0
  	let trailing=0
  fi
  printf "%${leading}s"
  printf $text
  printf "%${trailing}s"
}

print_device_info()
{
  local params=(${1//,/ })
  if [[ ${#params[@]} -ne 5 ]]; then
    echo "Device info '$1' is incorrect."
    return
  fi
  
  local parent=${params[0]}
  parent=${parent%.*}
  if [[ "$parent" == "${params[0]}" ]] || [[ $2 != *"${parent},"* ]]; then
    parent='RPi'
  fi
  
  parent=$(center_text $parent 10)

  echo '      _______        _______        _______'
  echo '   __|       |______|       |______|       |__'
  echo '  /  |   1   |      |   2   |      |   3   |  \'
  echo '  |  |  PS1  |      |  PS2  |      |  PS3  |  |' | sed "s/PS1/$(port_state ${params[1]})/" | sed "s/PS2/$(port_state ${params[2]})/" | sed "s/PS3/$(port_state ${params[3]})/"
  echo '  |  |_______|      |_______|      |_______|  |'
  echo '  |                                           |'
  echo '  |                                           /'
  echo ' -------                                 ----------'
  echo '|       |                               |          |'
  echo '|   4   |              Hub:             |   To:    |'
  echo '|  PS4  |[            HubID            ]|[  RPi   ]|' | sed "s/PS4/$(port_state ${params[4]})/" | sed "s/\[            HubID            \]/$(center_text ${params[0]} 31)/" | sed "s/\[  RPi   \]/$parent/"
  echo '|       |                               |          |'
  echo ' -------                                 ----------'
  echo '  |                                           \'
  echo '  |                                           |'
  echo '  |                                           |'
  echo '  |   ___                                     |'
  echo '  \__|   |____________________________________/'
  echo "     '---'"
}

wait_until_done()
{
  local pid=$!
  local spin='-\|/'
  local i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\rOperation in progress...${spin:$i:1} "
    sleep 0.5
  done
  printf "\r"
}

turn_on_ports()
{
  local hub=$1
  local ports=$2
  $uhubctl -l $hub -a on -p $ports
}

turn_off_ports()
{
  local hub=$1
  local ports=$2
  $uhubctl -l $hub -a off -p $ports -r 200
}