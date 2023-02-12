#!/bin/bash

# this script must be "sourced" after logger.sh
#source ./functions/logger.sh


eval WindowName=`./functions/get_variable_wrapper.py WindowName`  # Remove when logger will be added in get_winid.py


get_winid () {
    gvTmpDir=$1
    if [ ! -d "$gvTmpDir" ]; then mkdir -p "$gvTmpDir" ; fi

    tmpWinIDfile=$gvTmpDir"/"`echo $RANDOM | md5sum |head -c 10` 
    ./functions/get_winid.py -o $tmpWinIDfile
    winid=`cat $tmpWinIDfile`
    rm $tmpWinIDfile

    # This log entry must be relocated to get_winid.py in the future. Remove later.
    logger "INFO" "\"$WindowName\" window id is $winid"

}
