#!/bin/bash

source ./functions/logger.sh
source ./functions/get_winid.sh
source ./functions/prepare-tmpdir.sh

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable_wrapper.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable_wrapper.py LogDir`
eval LogFile=`./functions/get_variable_wrapper.py LogFile`

eval TmpDir=`./functions/get_variable_wrapper.py TmpDir`
     ClkTmpScrFile=`./functions/get_variable_wrapper.py ClkTmpScrFile`

eval work_with_windows=`./functions/get_variable_wrapper.py work_with_windows`


# Override default value
SCRIPT_LOGGING_LEVEL="INFO"

logger "INFO" "Starting..."

# Determine window id (variable 'winid' will be defined)
get_winid $TmpDir

# Update variable $TmpDir, create dir or clear one if it exist.
prepare_tmpdir $winid

# Update var below which contains $TmpDir var in the path.
eval ClkTmpScrFile=$ClkTmpScrFile


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

    if $work_with_windows ; then
       currentwindowid=`xdotool getactivewindow` 2> >(errAbsorb)
       xdotool  windowactivate $winid  2> >(errAbsorb)    # it didn't work properly if it was 1 command instead of 2 (xdotool bug?)
    
       # `xdotool getactivewindow` will not work with Wayland (Ubuntu) properly.
       if [ ! -z $currentwindowid ]; then
           xdotool key $keycode 2> >(errAbsorb)
           sleep $sleeptime2 
           xdotool key $keycode windowactivate $currentwindowid  2> >(errAbsorb)
       else
           xdotool key $keycode 2> >(errAbsorb)
           sleep $sleeptime2 
           xdotool key $keycode 2> >(errAbsorb)
       fi
    else
       xdotool key $keycode 2> >(errAbsorb)
       sleep $sleeptime2 
       xdotool key $keycode 2> >(errAbsorb)
    fi

    logger "INFO" "The key with keycode $keycode has been pressed twice with interval of $sleeptime2 sec."

  else
    logger "INFO" "The player is dead (screentime $screentime). Do nothing."
  fi
done
