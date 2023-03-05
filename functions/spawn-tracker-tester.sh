#!/bin/bash
dir_samples=screensamples/spawn-messages
dir_results=screensamples/spawn-messages/tests_results


show_help()
{
    echo "Usage: spawn-tracker-tester.sh [-l params] [-t params]"
    echo " "
    echo "Options:  -l <param>               - Settings (variables) for the current script." 
    echo "             \"<param1> <param2>\"     Quotation marks are required if more than one parameter is specified."
    echo "                                     Optional usage."
    echo " " 
    echo "          -t <param>               - Settings (variables) for the transfering to the afk-check-clicker script." 
    echo "             \"<param1> <param2>\"     Quotation marks are required if more than one parameter is specified."
    echo "                                     Optional usage."
    echo " " 
    echo "Example:  spawn-tracker-tester.sh -l dir_results=./dir123 -t \"SpawnLogFile=file.log\""
    exit 0
}

tParams=""
while getopts "l:t:h" opt
do
    case $opt in
        l)
      # settings for the current script can be also given as parameters
      # they override above defaults
      arrOPTARG=($OPTARG)
      for arg in "${arrOPTARG[@]}"; do
          if echo "$arg" | grep -F = &>/dev/null 
            then eval "$arg"; 
            else echo "ERROR: $arg - wrong parameter"
          fi
      done
  ;;
        t)
      tParams=""
      # Verifying parameters for transfering to the script
      arrOPTARG=($OPTARG)
      for arg in "${arrOPTARG[@]}"; do
          if echo "$arg" | grep -F = &>/dev/null
               then tParams=`echo $tParams" $arg"`
               else echo "ERROR: $arg - wrong parameter"
          fi
      done
  ;;
        h)
      show_help
  ;;
        *)
      echo "Unknown option $opt. Use option -h to show help. Abort."
      exit 1
  ;;
    esac
done


mkdir -p $dir_results

i=0
countFiles=`ls -l $dir_samples/*.png | wc -l`
for fname in $dir_samples/*.png; do
  ((i+=1)) 
  bfname=`basename "$fname"`".txt"
  echo "$i/$countFiles => $fname"
  /usr/bin/time -f "          %E real, %U user, %S sys" \
    ./spawn-tracker.sh TEST_MODE=true SptTmpScrFile="$fname" TestsDir="$dir_results" $tParams


done
