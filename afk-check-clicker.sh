#!/bin/bash

ConfigFile="./aaafk.cfg"

# for 1366x768 screen resolution make link:
# ln -s aaafk-1366x768.cfg aaafk.cfg

# for 1920x1080 screen resolution make link:
# ln -s aaafk-1920x1080.cfg aaafk.cfg

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)

#####################
## DEFAULT CONFIG: ##
#####################

script_logging_level="DEBUG"

CALIBRATION=false

LogDir="logs/"
LogFile=$LogDir"afk_clicker.log"
CalibrationFile="./calibration.png"
TmpScrFile="/tmp/test-ocr.png"
TmpBWScrFile="/tmp/test-ocr-bw.png"

resolutOffsetW=46
resolutOffsetH=61
w_rndm_max=20
h_rndm_max=3

WindowName="florr.io"
TriggerPhrase="AFK Check"
work_with_windows=0
sleeptime=20

#####################

# default values (from the default config above) are used if the config file is not used
# or some values are not set

# settings from the config file override default config

if [ -f $ConfigFile ]; then
    . $ConfigFile
fi

# settings can be also given as parameters
# they override default config and config file

for arg in "$@"; do
    if echo "$arg" | grep -F = &>/dev/null
         then eval "$arg"
         else echo "ERROR: $arg - wrong parameter"
    fi
done


mkdir -p "$LogDir"
scriptname=`basename "$0"`

logger () {
  log_priority=$1
  log_message=$2

  #check if level exists
  [[ ${levels[$log_priority]} ]] || return 1

  #check if level is enough
  (( ${levels[$log_priority]} < ${levels[$script_logging_level]} )) && return 2

  echo `date +%Y%m%d\|%H:%M:%S\|`" $scriptname| ${log_priority}| ${log_message}" >> $LogFile 
}

errAbsorb () {
 # syntax:   <command> 2> >(errAbsorb)
 while read inputLine; 
 do
   logger "ERROR" "$inputLine"
 done
}

logger "INFO" "Starting..."


if ! $CALIBRATION ; then
  # Determine window id for the screenshot capturing
  until [ -n "${winid}" ]
  do
    echo "Searching \"$WindowName\" window id..."
    sleep 1 
    winid=`xwininfo -tree -root | grep "$WindowName" | awk '{print $1}' | head -n1`
  done
  logger "INFO" "\"$WindowName\" window id is $winid"
  echo   "\"$WindowName\" window id is $winid"
fi

while true
do 
  if ! $CALIBRATION ; then
    sleep $sleeptime
    #flameshot full -r > $TmpScrFile 
    import -silent -window $winid $TmpScrFile 2> >(errAbsorb)
    screentime=`date +%Y%m%d-%H-%M-%S`
    logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."
  fi
  convert $TmpScrFile -negate -threshold 30% $TmpBWScrFile 2> >(errAbsorb)
  
  logger "DEBUG" "TriggerPhrase=\"$TriggerPhrase\""
  
  # Search the trigger phrase
  result=`tesseract -l eng $TmpBWScrFile - quiet 2> >(errAbsorb) |  grep "$TriggerPhrase" | wc -l`
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

    coordinateWidth=0 # The TriggerPhrase is located to the right of this coordinate.
  
    currScrFile=$TmpBWScrFile
    currHeight=`identify -format '%h' $currScrFile`
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
      convert $currScrFile +repage -crop $midWidth"x"$currHeight"+0+0" $currScrFile_leftside 2> >(errAbsorb)
      logger "DEBUG" "Search the TriggerPhrase in $currScrFile_leftside"
      if [ `tesseract -l eng $currScrFile_leftside  - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_leftside=1; 

      else # If phrase is not found in the left half
        # Cut off the right half and check trigger phrase here.
        currScrFile_rightside=$currScrFile"r"
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_leftside)"
        logger "DEBUG" "Cut off the right half of $currScrFile to $currScrFile_rightside"
        convert $currScrFile +repage -crop $midWidth"x"$currHeight"+"$midWidth"+0" $currScrFile_rightside 2> >(errAbsorb)
        logger "DEBUG" "Search the TriggerPhrase in $currScrFile_rightside"
        if [ `tesseract -l eng $currScrFile_rightside - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_rightside=1; fi

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
        # The trigger phrase was splitted and cannot be found by OCR.
        # Crops the previous succesful part of screenshot to the right of the middle. 
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_rightside)"
        currPixOffset=0; step=75
        if [ `expr $midWidth + $step` -lt $currWidth  ]; then
          logger "DEBUG" "Iteratively crop the $currScrFile to the right of the middle with step $step pix:"
          while true
          do 
            currPixOffset=`expr $currPixOffset + $step`
            if [ $currPixOffset -ge $midWidth ]; then
              logger "DEBUG" "currPixOffset=$currPixOffset (currPixOffset >= midWidth). Break this cropping loop (step $step pix)."
              break
            fi
  
            logger "DEBUG" "currPixOffset=$currPixOffset. Cropping $currScrFile -> $currScrFile""o"
            convert $currScrFile +repage -crop\
                    `expr $midWidth + $currPixOffset`"x"$currHeight"+"`expr $midWidth - $currPixOffset`"+0"   $currScrFile"o"\
                    2> >(errAbsorb)
  
            logger "DEBUG" "Search the TriggerPhrase in $currScrFile""o"
            if [ `tesseract -l eng $currScrFile"o"  - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -eq 1 ]; then 
              # The trigger phrase can be recognized by OCR now.
              currScrFile=$currScrFile"o"
              coordinateWidth=`expr $coordinateWidth + $midWidth - $currPixOffset`
              logger "DEBUG" "The TriggerPhrase was found."
              logger "DEBUG" "coordinateWidth changed to $coordinateWidth. Old value is `expr $coordinateWidth - $midWidth + $currPixOffset`"
              break
            fi
          done
        fi

        # Iteratively crop the right part of currScrFile until the trigger phrase is no longer recognized by OCR. 
        currPixOffset=0; step=10
        logger "DEBUG" "Iteratively crop the right part of $currScrFile with step $step pix:"
        while true
        do
          currPixOffset=`expr $currPixOffset + $step`
          currWidth=`identify -format '%w' $currScrFile`

          logger "DEBUG" "Cropping $currScrFile -> $currScrFile""O"
          convert $currScrFile +repage -crop\
                  `expr $currWidth - $step`"x"$currHeight"+"$step"+0"   $currScrFile"O"\
                  2> >(errAbsorb)

          logger "DEBUG" "Search the TriggerPhrase in $currScrFile""O"
          if [ `tesseract -l eng $currScrFile"O" - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase can't be recognized now.
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
  

    #################################################################
    ## Trying to find coordinates of the trigger phrase BY HEIGHT. ##
    #################################################################
    logger "DEBUG" "--- Trying to find coordinates of the TriggerPhrase BY HEIGHT ---"

    coordinateHeight=0 # The TriggerPhrase is located below this coordinate.
  
    currWidth=`identify -format '%w' $currScrFile`
    CoordinateFound=false

    until $CoordinateFound
    do
      # Split current part of screenshot into two
      currHeight=`identify -format '%h' $currScrFile`
      midHeight=`expr $currHeight / 2`

      # Cut off the top half and search trigger phrase
      found_topside=0; found_bottomside=0
      currScrFile_topside=$currScrFile"t"
      logger "DEBUG" "Cut off the top half of $currScrFile to $currScrFile_topside"
      convert $currScrFile +repage -crop $currWidth"x"$midHeight"+0+0"          $currScrFile_topside   2> >(errAbsorb)
      logger "DEBUG" "Search the TriggerPhrase in $currScrFile_topside"
      if [ `tesseract -l eng $currScrFile_topside  - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_topside=1; 

      else # If phrase is not found in the top half
        # Cut off the bottom half and check trigger phrase here.
        currScrFile_bottomside=$currScrFile"b"
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_topside)"
        logger "DEBUG" "Cut off the bottom half of $currScrFile to $currScrFile_bottomside"
        convert $currScrFile +repage -crop $currWidth"x"$midHeight"+0+"$midHeight $currScrFile_bottomside 2> >(errAbsorb)
        logger "DEBUG" "Search the TriggerPhrase in $currScrFile_bottomside"
        if [ `tesseract -l eng $currScrFile_bottomside - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_bottomside=1; fi

      fi

      if   [ $found_topside -eq "1" ] && [ $found_bottomside -eq "0" ]; then
        currScrFile=$currScrFile_topside
        logger "DEBUG" "The TriggerPhrase was found ($currScrFile_topside)."
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "1" ]; then
        coordinateHeight=`expr $coordinateHeight + $midHeight`
        currScrFile=$currScrFile_bottomside
        logger "DEBUG" "The TriggerPhrase was found ($currScrFile_bottomside)."
        logger "DEBUG" "coordinateHeight changed to $coordinateHeight. Old value is `expr $coordinateHeight - $midHeight`"
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "0" ]; then
        # The trigger phrase was splitted and cannot be found by OCR.
        # Crops the previous succesful part of screenshot to the top of the middle. 
        logger "DEBUG" "The TriggerPhrase not found ($currScrFile_bottomside)"
        currPixOffset=0; step=35
        if [ `expr $midHeight + $step` -lt $currHeight  ]; then
          logger "DEBUG" "Iteratively crop the $currScrFile to the top of the middle with step $step pix:"
          while true
          do 
            currPixOffset=`expr $currPixOffset + $step`
            if [ $currPixOffset -ge $midHeight ]; then
              TriggerPhrase=${TriggerPhrase:1}
              currPixOffset=0
              logger "DEBUG" "currPixOffset has too much value. It seems tesseract can no longer recognize the trigger phrase due to bug. Remove first character of the TriggerPhrase and repeat cropping by height. New value the TriggerPhrase is \"$TriggerPhrase\" now."
            fi
  
            logger "DEBUG" "currPixOffset=$currPixOffset. Cropping $currScrFile -> $currScrFile""o"
            convert $currScrFile +repage -crop\
                    $currWidth"x"`expr $midHeight + $currPixOffset`"+0+"`expr $midHeight - $currPixOffset`  $currScrFile"o"\
                    2> >(errAbsorb)
  
            logger "DEBUG" "Search the TriggerPhrase in $currScrFile""o"
            if [ `tesseract -l eng $currScrFile"o"  - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -eq 1 ]; then 
              # The trigger phrase can be recognized by OCR now.
              currScrFile=$currScrFile"o"
              coordinateHeight=`expr $coordinateHeight + $midHeight - $currPixOffset`
              logger "DEBUG" "The TriggerPhrase was found."
              logger "DEBUG" "coordinateHeight changed to $coordinateHeight. Old value is `expr $coordinateHeight - $midHeight + $currPixOffset`"
              break
            fi
          done
        fi

        # Iteratively crop the top part of currScrFile until the trigger phrase is no longer recognized by OCR. 
        currPixOffset=0; step=8
        logger "DEBUG" "Iteratively crop the top part of $currScrFile with step $step pix:"
        while true
        do
          currPixOffset=`expr $currPixOffset + $step`
          currHeight=`identify -format '%h' $currScrFile`

          logger "DEBUG" "Cropping $currScrFile -> $currScrFile""O"
          convert $currScrFile +repage -crop\
                  $currWidth"x"`expr $currHeight - $step`"+0+"$step   $currScrFile"O"\
                  2> >(errAbsorb)

          logger "DEBUG" "Search the TriggerPhrase in $currScrFile""O"
          if [ `tesseract -l eng $currScrFile"O" - quiet 2> >(errAbsorb) | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase can't be recognized now.
            coordinateHeight=`expr $coordinateHeight + $currPixOffset - $step`
            CoordinateFound=true
            logger "DEBUG" "The TriggerPhrase can't be recognize now. Iteratively cropping has been completed."
            logger "DEBUG" "coordinateHeight changed to $coordinateHeight. Old value is `expr $coordinateHeight - $currPixOffset + $step`"
            break
          fi
          currScrFile=$currScrFile"O"
        done
  
      fi 
  
    done
    logger "INFO" "coordinateHeight is $coordinateHeight"
  

    if $CALIBRATION ; then cp $TmpScrFile $CalibrationFile ; fi
    for i in {1..25} 
    do
       if $CALIBRATION ; then
         winCoordinateW=0
         winCoordinateH=0
       else
         winCoordinateW=`xwininfo -id $winid | grep "Absolute upper-left X:" | awk '{print $4}'`
         winCoordinateH=`xwininfo -id $winid | grep "Absolute upper-left Y:" | awk '{print $4}'`
       fi
    
       w_rndm=`seq -$w_rndm_max $w_rndm_max | shuf -n 1`
       h_rndm=`seq -$h_rndm_max $h_rndm_max | shuf -n 1`
       Width=`expr $winCoordinateW + $coordinateWidth + $resolutOffsetW + $w_rndm`
       Height=`expr $winCoordinateH + $coordinateHeight + $resolutOffsetH + $h_rndm`

       logger "DEBUG" "coordinateWidth is $coordinateWidth. coordinateHeight is $coordinateHeight."
       logger "DEBUG" " winCoordinateW is $winCoordinateW.  winCoordinateH is $winCoordinateH."
       logger "DEBUG" "         w_rndm is $w_rndm.          h_rndm is $h_rndm."
       logger "INFO" "Click at position $Width"x"$Height"

       if $CALIBRATION ; then
         convert $CalibrationFile -fill red -stroke black -draw "circle $Width,$Height `expr $Width + 2`,`expr $Height + 2`" $CalibrationFile 2> >(errAbsorb)
       else
         if $work_with_windows ; then
            currentwindowid=`xdotool getactivewindow` 2> >(errAbsorb)
            xdotool  windowactivate $winid  mousemove $Width $Height  click 1  mousemove restore  windowactivate $currentwindowid  2> >(errAbsorb)
         else
            xdotool mousemove $Width $Height  click 1 2> >(errAbsorb)
         fi
         break
       fi

    done

    if $CALIBRATION ; then exit 0 ; fi

  fi
  
  
done  
