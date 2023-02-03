#!/bin/bash

source ./functions/logger.sh

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable.py LogDir`
eval LogFile=`./functions/get_variable.py LogFile`
eval TmpDir=`./functions/get_variable.py TmpDir`

eval ClkTmpScrFile=`./functions/get_variable.py ClkTmpScrFile`


# Override default value
SCRIPT_LOGGING_LEVEL="INFO"

if [ ! -d "$TmpDir" ]; then mkdir -p "$TmpDir" ; fi

logger "INFO" "Starting..."
# Determine window id for the screenshot capturing
until [ -n "${winid}" ]
do
  echo "Search florr.io window id.."
  sleep 1
  winid=`xwininfo -tree -root | grep "florr.io" | awk '{print $1}'`
done
logger "INFO" "florr.io window id is $winid"
echo          "florr.io window id is $winid"

while true
do
  # Sleep ~5-9 mins
  sleeptime=$(echo $(shuf -i 345-555 -n 1)"."$(shuf -i 1-9 -n 1))
  sleep $sleeptime 

  # Check color of pixel (1DD129FF = player is dead, don't press key)
  #flameshot full -r > $ClkTmpScrFile 
  import -silent -window $winid $ClkTmpScrFile 2> >(errAbsorb)
  screentime=`date +%Y%m%d-%H-%M-%S`
  pixcolor=$(convert $ClkTmpScrFile -format "%[hex:u.p{675,500}]\n" info: 2> >(errAbsorb))
  if [ "$pixcolor" != "1DD129FF" ]; then

    keycode=$(shuf -n1 -e 10 15)  # 10 is key '1', 15 is key '6'.
    sleeptime2=$(echo $(shuf -i 1-10 -n 1)"."$(shuf -i 0-9 -n 1))

    xdotool key $keycode 2> >(errAbsorb)
    sleep $sleeptime2 
    xdotool key $keycode 2> >(errAbsorb) 
    logger "INFO" "The key with keycode $keycode has been pressed twice with interval of $sleeptime2 sec."

  else
    logger "INFO" "The player is dead (screentime $screentime). Do nothing."
  fi
done
