#!/bin/bash
# helper for run (bubbling) in florr.io game
# to work at least Legendary Relad skill is needed to allow you to change petals instantly
# during bubbling the rotation of petals is undesirable
# Yin Yang petal can be used to stop the rotation - set it in the hotbar
# once bubbles are in specified position, run this script - they will keep their direction
# now bubbling is easy
# to turn off - run script again
# this script is to quickly press specified key to change Yin Yang to another petal to stop rotation
# in fact, the petals slightly rotate back and forth
# use hotkey assignment to run this script
# set the following variables in the config:
# runclick_keycode=11      # 11 is key '2'
# runclick_sleeptime=0.1

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"

source ./functions/logger.sh

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable.py LogDir`
eval LogFile=`./functions/get_variable.py LogFile`
eval TmpDir=`./functions/get_variable.py TmpDir`

eval runclick_keycode=`./functions/get_variable.py runclick_keycode`
eval runclick_sleeptime=`./functions/get_variable.py runclick_sleeptime`

lockfile="$TmpDir/run-clicker.pid"

if [ ! -d "$TmpDir" ]; then mkdir -p "$TmpDir" ; fi

# Override default value
SCRIPT_LOGGING_LEVEL="INFO"

if [ -f $lockfile ]; then
  pid=`cat $lockfile`
  logger "INFO" "Terminating pid $pid..."
  kill $pid 2> >(errAbsorb)
  rm $lockfile 2> >(errAbsorb)
else
  logger "INFO" "Starting (pid $$)..."
  echo $$ > $lockfile 2> >(errAbsorb)
  while true
  do
    xdotool key $runclick_keycode sleep $runclick_sleeptime key $runclick_keycode sleep $runclick_sleeptime 2> >(errAbsorb)
  done
fi
