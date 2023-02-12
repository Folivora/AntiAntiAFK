#!/bin/bash

source ./functions/logger.sh
source ./functions/get_winid.sh

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable_wrapper.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable_wrapper.py LogDir`
eval LogFile=`./functions/get_variable_wrapper.py LogFile`
eval TmpDir=`./functions/get_variable_wrapper.py TmpDir`

eval SpawnLogFile=`./functions/get_variable_wrapper.py SpawnLogFile`

eval SptTmpScrFile=`./functions/get_variable_wrapper.py SptTmpScrFile`
eval SptTmpBWScrFile1=`./functions/get_variable_wrapper.py SptTmpBWScrFile1`
eval SptTmpBWScrFile2=`./functions/get_variable_wrapper.py SptTmpBWScrFile2`
eval SptTmpScrFile1=`./functions/get_variable_wrapper.py SptTmpScrFile1`
eval SptTmpScrFile2=`./functions/get_variable_wrapper.py SptTmpScrFile2`
eval SptTmpOCRfile=`./functions/get_variable_wrapper.py SptTmpOCRfile`

# Override default value
SCRIPT_LOGGING_LEVEL="INFO"


logger "INFO" "Starting..."

# Determine window id for the screenshot capturing (variable 'winid' will be defined)
get_winid $TmpDir

TmpDir=$TmpDir"/"`basename $0`"/$winid"
if [ ! -d "$TmpDir" ]; then 
    mkdir -p "$TmpDir"
else
    if [ "$(ls ${TmpDir})" ]; then
       rm ${TmpDir}/*.png 2> >(errAbsorb)
    fi  
fi


TriggerPhrase1="An Ultra [a-z]* has spawned"
TriggerPhrase2="Press \[ENTER\] or click here"
logger "DEBUG" "Set value of variables: TriggerPhrase1=\"$TriggerPhrase1\". TriggerPhrase2=\"$TriggerPhrase2\""

while true
do 
  sleeptime=10
  sleep $sleeptime 

  import -silent -window $winid -gravity SouthWest -crop 25x10%+0+0 +repage $SptTmpScrFile 2> >(errAbsorb)
  screentime=`date +%Y%m%d-%H-%M-%S`
  logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."

  #convert $SptTmpScrFile -colorspace YCbCr -channel Red -fx "0.1" +channel \ 
  #                    -channel R -separate \ 
  #                    -brightness-contrast 0x50  $SptTmpBWScrFile1

  convert $SptTmpScrFile -colorspace YCbCr -channel Red -fx "0.1" +channel $SptTmpScrFile1 2> >(errAbsorb)
  convert $SptTmpScrFile1 -channel R -separate $SptTmpScrFile1 2> >(errAbsorb)
  convert $SptTmpScrFile1 -brightness-contrast 0x50 $SptTmpScrFile1 2> >(errAbsorb)
  convert $SptTmpScrFile1 -negate -threshold 60% $SptTmpBWScrFile1 2> >(errAbsorb)
  
  # Search the TriggerPhrase1 (about spawning)
  tesseract -l eng -c textord_min_xheight=4 $SptTmpBWScrFile1 - >$SptTmpOCRfile quiet 2> >(errAbsorb) 
  foundPhrase=`grep -iP "$TriggerPhrase1" $SptTmpOCRfile`

  if [ -n "${foundPhrase}" ]; then
    # The TriggerPhrase1 was found.
    # Search TriggerPhrase2 (Chat check. Need to check the message about spawn is new).
    logger "DEBUG" "Found the TriggerPhrase1: \"$foundPhrase\"."

    convert $SptTmpScrFile -brightness-contrast 0x70 $SptTmpScrFile2
    convert $SptTmpScrFile2 -negate -threshold 70% $SptTmpBWScrFile2

    if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ]; then 
      if [ -z $LogDir ]; then  eval `grep "LogDir=" $ConfigFile` ; fi
      bkpDir=$LogDir"/"$screentime"-spawn"
      mkdir -p $bkpDir
      cp $SptTmpScrFile    $bkpDir"/"$screentime"-spawn.png" 
      cp $SptTmpScrFile1   $bkpDir"/"$screentime"-spawn1.png" 
      cp $SptTmpScrFile2   $bkpDir"/"$screentime"-spawn2.png" 
      cp $SptTmpBWScrFile1 $bkpDir"/"$screentime"-spawnBW1.png" 
      cp $SptTmpBWScrFile2 $bkpDir"/"$screentime"-spawnBW2.png" 
      cp $SptTmpOCRfile    $bkpDir"/"$screentime"-spawnOCR.txt" 
    fi

    # Search the TriggerPhrase2 (chat check)
    logger "DEBUG" "Search the TriggerPhrase2."
    result=`tesseract -l eng -c textord_min_xheight=4 $SptTmpBWScrFile2 - quiet 2> >(errAbsorb) |  grep -i "$TriggerPhrase2" | wc -l`

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
