#!/bin/bash

source ./functions/logger.sh

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable.py LogDir`
eval LogFile=`./functions/get_variable.py LogFile`

# Override default value
SCRIPT_LOGGING_LEVEL="INFO"


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


keycode=65

if $work_with_windows ; then
    currentwindowid=`xdotool getactivewindow` 2> >(errAbsorb)
    xdotool  windowactivate $winid  2> >(errAbsorb)    # it didn't work properly if it was 1 command instead of 2 (xdotool bug?)
 
    # `xdotool getactivewindow` will not work with Wayland (Ubuntu) properly.
    if [ ! -z $currentwindowid ]; then
        xdotool keydown $keycode windowactivate $currentwindowid 2> >(errAbsorb)
    else
        xdotool keydown $keycode 2> >(errAbsorb)
    fi
else
    xdotool keydown $keycode 2> >(errAbsorb)
fi  
