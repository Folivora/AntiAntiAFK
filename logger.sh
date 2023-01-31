#!/bin/bash

ConfigFile="./aaafk.cfg"

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)

# Load default values from config if the variables are empty.
# Value of these vars can be overridden in a script from which below functions are calling. 
if [ -z $SCRIPT_LOGGING_LEVEL ]; then  SCRIPT_LOGGING_LEVEL=`grep "SCRIPT_LOGGING_LEVEL" $ConfigFile  | awk -F '=' '{print $2}'` ; fi 
if [ -z $LogDir ]; then  LogDir=`grep "LogDir" $ConfigFile  | awk -F '=' '{print $2}'` ; fi 
if [ -z $LogFile ]; then  LogFile=$LogDir"/"`grep "LogFile" $ConfigFile  | awk -F '=' '{print $2}'` ; fi


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
