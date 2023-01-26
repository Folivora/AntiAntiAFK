#!/bin/bash

TmpScrFile="/tmp/scr.png"
LogDir="logs/"
LogFile=$LogDir"afk_clicker.log"

logger () {
  echo `date +%Y-%m-%d\|%H:%M:%S\|`" clicker.sh|  $1" >> $LogFile 
}
logger "Starting..."

# Determine window id for the screenshot capturing
until [ -n "${winid}" ]
do
  echo "Search florr.io window id.."
  sleep 1
  winid=`xwininfo -tree -root | grep "florr.io" | awk '{print $1}'`
done
logger "florr.io window id is $winid"
echo   "florr.io window id is $winid"

while true
do
  # Sleep ~5-9 mins
  sleeptime=$(echo $(shuf -i 345-555 -n 1)"."$(shuf -i 1-9 -n 1))
  sleep $sleeptime 

  # Check color of pixel (1DD129FF = player is dead, don't press key)
  #flameshot full -r > $TmpScrFile 
  import -silent -window $winid $TmpScrFile
  screentime=`date +%Y%m%d-%H-%M-%S`
  pixcolor=$(convert $TmpScrFile -format "%[hex:u.p{675,500}]\n" info:)
  if [ "$pixcolor" != "1DD129FF" ]; then

    keycode=$(shuf -n1 -e 10 15)  # 10 is key '1', 15 is key '6'.
    sleeptime2=$(echo $(shuf -i 1-10 -n 1)"."$(shuf -i 0-9 -n 1))

    xdotool key $keycode 
    sleep $sleeptime2 
    xdotool key $keycode 
    logger "The key with keycode $keycode has been pressed twice with interval of $sleeptime2 sec."

  else
    logger "The player is dead (screentime $screentime). Do nothing."
  fi
done
