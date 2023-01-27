#!/bin/bash

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)
script_logging_level="DEBUG"

CALIBRATION=false

CalibrationFile="./calibration.png"
TmpScrFile="/tmp/test-ocr.png"
TmpBWScrFile="/tmp/test-ocr-bw.png"
LogDir="logs/"
LogFile=$LogDir"afk_clicker.log"

logger () {
  log_priority=$1
  log_message=$2

  #check if level exists
  [[ ${levels[$log_priority]} ]] || return 1

  #check if level is enough
  (( ${levels[$log_priority]} < ${levels[$script_logging_level]} )) && return 2

  echo `date +%Y%m%d\|%H:%M:%S\|`" afk-check-clicker.sh| ${log_priority}| ${log_message}" >> $LogFile 
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


while true
do 
  sleeptime=20
  if ! $CALIBRATION ; then sleep $sleeptime ; fi

  #flameshot full -r > $TmpScrFile 
  import -silent -window $winid $TmpScrFile
  screentime=`date +%Y%m%d-%H-%M-%S`
  logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."
  convert $TmpScrFile -negate -threshold 40% $TmpBWScrFile
  
  TriggerPhrase="AFK Check"
  logger "DEBUG" "TriggerPhrase=\"AFK Check\""
  
  # Search the trigger phrase
  result=`tesseract -l eng $TmpBWScrFile - quiet |  grep "$TriggerPhrase" | wc -l`
  logger "DEBUG" "Search the trigger phrase complete. $result matches were found."

  if [ $result -ge 1 ]; then
    # The TriggerPhrase was found
    # 
    cp $TmpScrFile $LogDir"/"$screentime".png"

    if [ $result -ge 2 ]; then
      logger "ERROR" "The trigger phrase \"$TriggerPhrase\" has been found in $result places (screentime $screentime). Exit."
      exit 0
    fi

    logger "INFO" "The trigger phrase \"$TriggerPhrase\" has been found (screentime $screentime). Search the coordinates is starting."
  

    ################################################################
    ## Trying to find coordinates of the trigger phrase BY WIDTH. ##
    ################################################################
    logger "DEBUG" "--- Trying to find coordinates of the TriggerPhrase BY WIDTH ---"

    coordinateWidth=0 # The TriggerPhrase located to the right of this coordinate.
  
    currScrFile=$TmpBWScrFile
    currHight=`identify -format '%h' $currScrFile`
    CoordinateFound=false
    until $CoordinateFound
    do
      # Split current part of screenshot into two
      currWidth=`identify -format '%w' $currScrFile`
      midWidth=`expr $currWidth / 2`

      # Cut off the left half and search trigger phrase
      found_leftside=0; found_rightside=0
      currScrFile_leftside=$currScrFile"l"
      logger "DEBUG" "Cut off the left half of $currScrFile to $currScrFile_leftside"
      convert $currScrFile +repage -crop $midWidth"x"$currHight"+0+0" $currScrFile_leftside
      logger "DEBUG" "Search the TriggerPhrase in $currScrFile_leftside"
      if [ `tesseract -l eng $currScrFile_leftside  - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_leftside=1; 

      else # If phrase not found in left half
        # Cut off the right half and check trigger phrase here.
        currScrFile_rightside=$currScrFile"r"
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_leftside)"
        logger "DEBUG" "Cut off the right half of $currScrFile to $currScrFile_rightside"
        convert $currScrFile +repage -crop $midWidth"x"$currHight"+"$midWidth"+0" $currScrFile_rightside
        logger "DEBUG" "Search the TriggerPhrase in $currScrFile_rightside"
        if [ `tesseract -l eng $currScrFile_rightside - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_rightside=1; fi

      fi
  
      if   [ $found_leftside -eq "1" ] && [ $found_rightside -eq "0" ]; then
        currScrFile=$currScrFile_leftside
        logger "DEBUG" "The TriggerPhrase was found ($currScrFile_leftside)."
  
      elif [ $found_leftside -eq "0" ] && [ $found_rightside -eq "1" ]; then
        coordinateWidth=`expr $coordinateWidth + $midWidth`
        currScrFile=$currScrFile_rightside
        logger "DEBUG" "The TriggerPhrase was found ($currScrFile_rightside)."
        logger "DEBUG" "coordinateWidth changed to $coordinateWidth. Old value is `expr $coordinateWidth - $midWidth`"
  
      elif [ $found_leftside -eq "0" ] && [ $found_rightside -eq "0" ]; then
        # The trigger phrase was splited and cannot be found by OCR.
        # Crops the previus succesfull part of screenshot to the right of the middle. 
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_rightside)"
        currPixOffset=0; step=75
        if [ `expr $midWidth + $step` -lt $currWidth  ]; then 
          logger "DEBUG" "Iteratively crop the $currScrFile to the right of the middle with step $step pix:"
          while true
          do 
            currPixOffset=`expr $currPixOffset + $step`

            logger "DEBUG" "Cropping $currScrFile -> $currScrFile""o"""
            convert $currScrFile +repage -crop\
                    `expr $midWidth + $currPixOffset`"x"$currHight"+"`expr $midWidth - $currPixOffset`"+0"   $currScrFile"o"

            logger "DEBUG" "Search the TriggerPhrase in $currScrFile""o"""
            if [ `tesseract -l eng $currScrFile"o"  - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 1 ]; then 
              # The trigger phrase can be recognized by OCR now.
              currScrFile=$currScrFile"o"
              coordinateWidth=`expr $coordinateWidth + $midWidth - $currPixOffset`
              logger "DEBUG" "The TriggerPhrase was found."
              logger "DEBUG" "coordinateWidth changed to $coordinateWidth. Old value is `expr $coordinateWidth - $midWidth + $currPixOffset`"
              break
            fi
          done
        fi

        # Iteratively crop the right part of currScrFile utill trigger phrase will cease to be recognizable by OCR. 
        currPixOffset=0; step=10
        logger "DEBUG" "Iteratively crop the right part of $currScrFile with step $step pix:"
        while true
        do
          currPixOffset=`expr $currPixOffset + $step`
          currWidth=`identify -format '%w' $currScrFile`

          logger "DEBUG" "Cropping $currScrFile -> $currScrFile""O"""
          convert $currScrFile +repage -crop\
                  `expr $currWidth - $step`"x"$currHight"+"$step"+0"   $currScrFile"O"

          logger "DEBUG" "Search the TriggerPhrase in $currScrFile""O"""
          if [ `tesseract -l eng $currScrFile"O" - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase cant be recognize now.
            coordinateWidth=`expr $coordinateWidth + $currPixOffset - $step`
            CoordinateFound=true
            logger "DEBUG" "The TriggerPhrase can't be recognize now. Iteratively cropping has been completed."
            logger "DEBUG" "coordinateWidth changed to $coordinateWidth. Old value is `expr $coordinateWidth - $currPixOffset + $step`"
            break
          fi
          currScrFile=$currScrFile"O"
        done
  
      fi 
  
    done
    logger "INFO" "coordinateWidth is $coordinateWidth"
  

    ################################################################
    ## Trying to find coordinates of the trigger phrase BY HIGHT. ##
    ################################################################
    logger "DEBUG" "--- Trying to find coordinates of the TriggerPhrase BY HIGHT ---"

    coordinateHight=0 # The TriggerPhrase is located below this coordinate.
  
    currWidth=`identify -format '%w' $currScrFile`
    CoordinateFound=false

    until $CoordinateFound
    do
      # Split current part of screenshot into two
      currHight=`identify -format '%h' $currScrFile`
      midHight=`expr $currHight / 2`

      # Cut off the top half and search trigger phrase
      found_topside=0; found_bottomside=0
      currScrFile_topside=$currScrFile"t"
      logger "DEBUG" "Cut off the top half of $currScrFile to $currScrFile_topside"
      convert $currScrFile +repage -crop $currWidth"x"$midHight"+0+0"          $currScrFile_topside
      logger "DEBUG" "Search the TriggerPhrase in $currScrFile_topside"
      if [ `tesseract -l eng $currScrFile_topside  - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_topside=1; 

      else # If phrase not found in the top half
        # Cut off the bottom half and check trigger phrase here.
        currScrFile_bottomside=$currScrFile"b"
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_topside)"
        logger "DEBUG" "Cut off the right half of $currScrFile to $currScrFile_bottomside"
        convert $currScrFile +repage -crop $currWidth"x"$midHight"+0+"$midHight $currScrFile_bottomside
        logger "DEBUG" "Search the TriggerPhrase in $currScrFile_bottomside"
        if [ `tesseract -l eng $currScrFile_bottomside - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_bottomside=1; fi

      fi

      if   [ $found_topside -eq "1" ] && [ $found_bottomside -eq "0" ]; then
        currScrFile=$currScrFile_topside
        logger "DEBUG" "The TriggerPhrase was found ($currScrFile_topside)."
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "1" ]; then
        coordinateHight=`expr $coordinateHight + $midHight`
        currScrFile=$currScrFile_bottomside
        logger "DEBUG" "The TriggerPhrase was found ($currScrFile_bottomside)."
        logger "DEBUG" "coordinateHight changed to $coordinateHight. Old value is `expr $coordinateHight - $midHight`"
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "0" ]; then
        # The trigger phrase was splited and cannot be found by OCR.
        # Crops the previus succesfull part of screenshot to the top of the middle. 
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_bottomside)"
        currPixOffset=0; step=35
        if [ `expr $midHight + $step` -lt $currHight  ]; then 
          logger "DEBUG" "Iteratively crop the $currScrFile to the top of the middle with step $step pix:"
          while true
          do 
            currPixOffset=`expr $currPixOffset + $step`

            logger "DEBUG" "Cropping $currScrFile -> $currScrFile""o"""
            convert $currScrFile +repage -crop\
                    $currWidth"x"`expr $midHight + $currPixOffset`"+0+"`expr $midHight - $currPixOffset`  $currScrFile"o"

            logger "DEBUG" "Search the TriggerPhrase in $currScrFile""o"""
            if [ `tesseract -l eng $currScrFile"o"  - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 1 ]; then 
              # The trigger phrase can be recognized by OCR now.
              currScrFile=$currScrFile"o"
              coordinateHight=`expr $coordinateHight + $midHight - $currPixOffset`
              logger "DEBUG" "The TriggerPhrase was found."
              logger "DEBUG" "coordinateHight changed to $coordinateHight. Old value is `expr $coordinateHight - $midHight + $currPixOffset`"
              break
            fi
          done
        fi

        # Iteratively crop the top part of currScrFile utill trigger phrase will cease to be recognizable by OCR. 
        currPixOffset=0; step=8
        logger "DEBUG" "Iteratively crop the top part of $currScrFile with step $step pix:"
        while true
        do
          currPixOffset=`expr $currPixOffset + $step`
          currHight=`identify -format '%h' $currScrFile`

          logger "DEBUG" "Cropping $currScrFile -> $currScrFile""O"""
          convert $currScrFile +repage -crop\
                  $currWidth"x"`expr $currHight - $step`"+0+"$step   $currScrFile"O"

          logger "DEBUG" "Search the TriggerPhrase in $currScrFile""O"""
          if [ `tesseract -l eng $currScrFile"O" - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase cant be recognize now.
            coordinateHight=`expr $coordinateHight + $currPixOffset - $step`
            CoordinateFound=true
            logger "DEBUG" "The TriggerPhrase can't be recognize now. Iteratively cropping has been completed."
            logger "DEBUG" "coordinateHight changed to $coordinateHight. Old value is `expr $coordinateHight - $currPixOffset + $step`"
            break
          fi
          currScrFile=$currScrFile"O"
        done
  
      fi 
  
    done
    logger "INFO" "coordinateHight is $coordinateHight"
  

    if $CALIBRATION ; then cp $TmpScrFile $CalibrationFile ; fi
    for i in {1..25} 
    do
       wOffset=`xwininfo -id $winid | grep "Relative upper-left X:" | awk '{print $4}'`
       hOffset=`xwininfo -id $winid | grep "Relative upper-left Y:" | awk '{print $4}'`
    
       w_rndm=`seq -20 20 | shuf -n 1`
       h_rndm=`seq -3 3 | shuf -n 1`
       Width=`expr $wOffset + $coordinateWidth + 45 + $w_rndm`
       Hight=`expr $hOffset + $coordinateHight + 61 + $h_rndm`

       logger "DEBUG" "coordinateWidth is $coordinateWidth. coordinateHight is $coordinateHight."
       logger "DEBUG" "        wOffset is $wOffset.         hOffset is $hOffset."
       logger "DEBUG" "         w_rndm is $w_rndm.          h_rndm is $h_rndm."
       logger "INFO" "Click at position $Width"x"$Hight"

       if $CALIBRATION ; then
         convert $CalibrationFile -fill red -stroke black -draw "circle $Width,$Hight `expr $Width + 2`,`expr $Hight + 2`" $CalibrationFile
       else 
         xdotool mousemove $Width $Hight  click 1
         break
       fi
    
    done

    if $CALIBRATION ; then exit 0 ; fi

  fi
  
  
done  

