#!/bin/bash

source ./functions/logger.sh
source ./functions/get_winid.sh

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable_wrapper.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable_wrapper.py LogDir`
eval LogFile=`./functions/get_variable_wrapper.py LogFile`
eval TmpDir=`./functions/get_variable_wrapper.py TmpDir`

# Override default value
SCRIPT_LOGGING_LEVEL="INFO"


logger "INFO" "Starting..."

# Determine window id (variable 'winid' will be defined)
get_winid $TmpDir


# 1. There's only two way to toggle to attack mode - with mouse's left button and with space key.
#    We need to use only space key here because using mouse's left click will lock working of other 
#    scripts which use left click too. 
# 2. There's must not switching back to currentwinid with windowactivate when we are using space to toggle to attack
#    mode because keydown of space will no longer be sent to winid but will be sent to currentwinid in this case.
#    (Tested on MATE DE 1.20.4 with debian 10)

keycode=65  # Space
xdotool windowactivate $winid windowfocus $winid keydown $keycode 2> >(errAbsorb)
