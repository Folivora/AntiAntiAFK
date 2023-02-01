#!/bin/bash

ConfigFile="./aaafk.cfg"

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)

# Load default values from config if the variables are empty.
# Value of these vars can be overridden in a script from which below functions are calling. 
if [ -z $SCRIPT_LOGGING_LEVEL ]; then  eval `grep "SCRIPT_LOGGING_LEVEL" $ConfigFile` ; fi 
if [ -z $LogDir ]; then  eval `grep "LogDir=" $ConfigFile` ; fi 
if [ -z $LogFile ]; then  eval `grep "LogFile=" $ConfigFile` ; fi

logger () {
  log_priority=$1
  log_message=$2

  #check if level exists
  [[ ${levels[$log_priority]} ]] || return 1

  #check if level is enough
  (( ${levels[$log_priority]} < ${levels[$SCRIPT_LOGGING_LEVEL]} )) && return 2

  mkdir -p "$LogDir"
  echo `date +%Y%m%d\|%H:%M:%S\|`" `basename $0`| ${log_priority}| ${log_message}" >> $LogFile 
}

errAbsorb () {
 # syntax:   <command> 2> >(errAbsorb)
 while read inputLine; 
 do
   logger "ERROR" "$inputLine"
 done
}
