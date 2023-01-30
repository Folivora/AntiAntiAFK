#!/bin/bash

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)
script_logging_level="INFO"

LogDir="logs"
LogFile=$LogDir"/afk_clicker.log" 
SpawnLogFile=$LogDir"/mobs_spawn.log"
TmpScrFile="/tmp/aaafk_spawn.png"
TmpBWScrFile1="/tmp/aaafk_spawn_bw1.png"
TmpBWScrFile2="/tmp/aaafk_spawn_bw2.png"
TmpScrFile1="/tmp/aaafk_spawn_tmp1.png" # Remove later. See the line 64.
TmpScrFile2="/tmp/aaafk_spawn_tmp2.png" # Remove later. See the line 81. 
TmpOCRfile="/tmp/aaafk_spawn_ocr.txt"

logger () {
  log_priority=$1
  log_message=$2

  #check if level exists
  [[ ${levels[$log_priority]} ]] || return 1

  #check if level is enough
  (( ${levels[$log_priority]} < ${levels[$script_logging_level]} )) && return 2

  echo `date +%Y%m%d\|%H:%M:%S\|`" spawn-tracker.sh| ${log_priority}| ${log_message}" >> $LogFile 
}

errAbsorb () {
 # syntax:   <command> 2> >(errAbsorb)
 while read inputLine; 
 do
   logger "ERROR" "$inputLine"
 done
}

logger "INFO" "Starting..."


# Determine window id for the screenshot capturing
until [ -n "${winid}" ]
do
  echo "Search florr.io window id.."
  sleep 1 
  winid=`xwininfo -tree -root | grep "florr.io" | awk '{print $1}' | head -n1`
done
logger "INFO" "florr.io window id is $winid"
echo   "florr.io window id is $winid"

TriggerPhrase1="An Ultra [a-z]* has spawned"
TriggerPhrase2="Press \[ENTER\] or click here"
logger "DEBUG" "Set value of variables: TriggerPhrase1=\"$TriggerPhrase1\". TriggerPhrase2=\"$TriggerPhrase2\""

while true
do 
  sleeptime=10
  sleep $sleeptime 

  import -silent -window $winid -gravity SouthWest -crop 25x10%+0+0 +repage $TmpScrFile 2> >(errAbsorb)
  screentime=`date +%Y%m%d-%H-%M-%S`
  logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."

  #convert $TmpScrFile -colorspace YCbCr -channel Red -fx "0.1" +channel \ 
  #                    -channel R -separate \ 
  #                    -brightness-contrast 0x50  $TmpBWScrFile1

  convert $TmpScrFile -colorspace YCbCr -channel Red -fx "0.1" +channel $TmpScrFile1 2> >(errAbsorb)
  convert $TmpScrFile1 -channel R -separate $TmpScrFile1 2> >(errAbsorb)
  convert $TmpScrFile1 -brightness-contrast 0x50 $TmpScrFile1 2> >(errAbsorb)
  convert $TmpScrFile1 -negate -threshold 60% $TmpBWScrFile1 2> >(errAbsorb)
  
  # Search the TriggerPhrase1 (about spawning)
  tesseract -l eng -c textord_min_xheight=4 $TmpBWScrFile1 - >$TmpOCRfile quiet 2> >(errAbsorb) 
  foundPhrase=`grep -iP "$TriggerPhrase1" $TmpOCRfile`

  if [ -n "${foundPhrase}" ]; then
    # The TriggerPhrase1 was found.
    # Search TriggerPhrase2 (Chat check. Need to check the message about spawn is new).
    logger "DEBUG" "Found the TriggerPhrase1: \"$foundPhrase\"."

    convert $TmpScrFile -brightness-contrast 0x70 $TmpScrFile2
    convert $TmpScrFile2 -negate -threshold 70% $TmpBWScrFile2

    if [ "$script_logging_level" = "DEBUG" ]; then 
      bkpDir=$LogDir"/"$screentime"-spawn"
      mkdir -p $bkpDir
      cp $TmpScrFile    $bkpDir"/"$screentime"-spawn.png" 
      cp $TmpScrFile1   $bkpDir"/"$screentime"-spawn1.png" 
      cp $TmpScrFile2   $bkpDir"/"$screentime"-spawn2.png" 
      cp $TmpBWScrFile1 $bkpDir"/"$screentime"-spawnBW1.png" 
      cp $TmpBWScrFile2 $bkpDir"/"$screentime"-spawnBW2.png" 
      cp $TmpOCRfile    $bkpDir"/"$screentime"-spawnOCR.txt" 
    fi

    # Search the TriggerPhrase2 (chat check)
    logger "DEBUG" "Search the TriggerPhrase2."
    result=`tesseract -l eng -c textord_min_xheight=4 $TmpBWScrFile2 - quiet 2> >(errAbsorb) |  grep -i "$TriggerPhrase2" | wc -l`

    if [ $result -ge 1 ]; then
      logger "INFO" "Ultra mob was spawned at $screentime. Found message is: $foundPhrase"
      echo          "Ultra mob was spawned at $screentime. Found message is: $foundPhrase" >> $SpawnLogFile
      echo          "Ultra mob was spawned at $screentime. Found message is: $foundPhrase" 
      sleep 60
    else
      logger "DEBUG" "The TriggerPhrase2 not found in current screenshot. Seems the message about spawn is old."
    fi

  else
    logger "DEBUG" "The TriggerPhrase1 not found in current screenshot."
  fi

done
