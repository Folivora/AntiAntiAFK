#!/bin/bash

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)
SCRIPT_LOGGING_LEVEL="INFO" # default

LogDir="logs"
LogFile=$LogDir"/aaafk.log"

logger () {
  log_priority=$1
  log_message=$2

  #check if level exists
  [[ ${levels[$log_priority]} ]] || return 1

  #check if level is enough
  (( ${levels[$log_priority]} < ${levels[$SCRIPT_LOGGING_LEVEL]} )) && return 2

  echo `date +%Y%m%d\|%H:%M:%S\|`" `basename $0`| ${log_priority}| ${log_message}" >> $LogFile 
}

errAbsorb () {
 # syntax:   <command> 2> >(errAbsorb)
 while read inputLine; 
 do
   logger "ERROR" "$inputLine"
 done
}
